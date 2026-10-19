import 'dart:async';
import 'dart:math' as math;
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../data/models/audio_file.dart';
import '../data/network/yt/stream_client_utils.dart';
import '../data/network/yt/youtube_repository.dart';
import 'equalizer_service.dart';
import 'local_stream_proxy.dart';
import 'stream_error_bus.dart';

class FritoAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final AudioPlayer _player = AudioPlayer();

  List<AudioFile> _playlist = [];
  int _currentIndex = -1;
  bool _shuffleModeEnabled = false;

  // Recuperación ante errores de stream a mitad de reproducción (URL expirada)
  bool _isRecovering = false;
  bool _stopRequested = false;
  int _recoverAttempts = 0;
  String? _lastFailedPath;
  static const int _maxRecoverAttempts = 2;

  // Intención del usuario (play/pause): para reanudar tras una recuperación.
  bool _userWantedPlaying = false;
  // Guard de carrera: ignorar eventos idle mientras se carga una fuente nueva.
  bool _isSettingSource = false;
  // Watchdog de stall: detecta "reproducción" sin avance de posición
  // (stream throttleado o muerto sin error → silencio total).
  Timer? _stallTimer;
  Duration? _lastWatchdogPos;
  int _stallTicks = 0;

  AudioPlayer get player => _player;
  List<AudioFile> get playlist => _playlist;
  int get currentIndex => _currentIndex;
  bool get shuffleModeEnabled => _shuffleModeEnabled;
  AudioFile? get currentAudio => (_currentIndex >= 0 && _currentIndex < _playlist.length) ? _playlist[_currentIndex] : null;

  FritoAudioHandler() {
    _init();
  }

  void _init() {
    // Escuchar cambios de estado en just_audio y mapear a audio_service PlaybackState
    _player.playbackEventStream.listen((PlaybackEvent event) {
      final playing = _player.playing;
      playbackState.add(playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
          MediaControl.stop,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: const {
          ProcessingState.idle: AudioProcessingState.idle,
          ProcessingState.loading: AudioProcessingState.loading,
          ProcessingState.buffering: AudioProcessingState.buffering,
          ProcessingState.ready: AudioProcessingState.ready,
          ProcessingState.completed: AudioProcessingState.completed,
        }[_player.processingState]!,
        playing: playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: _currentIndex >= 0 ? _currentIndex : null,
      ));
    });

    // Avance automático al terminar canción
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        skipToNext();
      }
    });

    // Recuperación automática si el stream muere a mitad de canción
    // (típico de URLs de YouTube que expiran o devuelven 403 al seguir
    // leyendo rangos). just_audio no expone errorStream: cuando la fuente
    // remota muere, ExoPlayer transiciona a ProcessingState.idle con la
    // fuente aún cargada. Ese idle "inesperado" dispara la recuperación.
    // Se ignora mientras se carga una fuente nueva (idle transitorio).
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.idle &&
          !_isSettingSource &&
          !_stopRequested &&
          _player.audioSource != null &&
          currentAudio != null) {
        debugPrint('[FritoAudioHandler] Stream murió (idle inesperado); intentando recuperar...');
        _recoverFromStreamError();
      }
    });

    // Watchdog de stall: si la posición no avanza y el buffer está agotado,
    // el stream está throttleado o muerto sin error (silencio total).
    _stallTimer = Timer.periodic(const Duration(seconds: 5), (_) => _checkStall());
  }

  void _checkStall() {
    if (_player.audioSource == null || currentAudio == null || _isSettingSource) return;
    final pos = _player.position;
    final buffered = _player.bufferedPosition;
    debugPrint('[Watchdog] pos=${pos.inSeconds}s buffered=${buffered.inSeconds}s '
        'state=${_player.processingState} playing=${_player.playing}');
    if (_player.playing &&
        _lastWatchdogPos != null &&
        pos == _lastWatchdogPos &&
        buffered - pos < const Duration(seconds: 5)) {
      _stallTicks++;
      if (_stallTicks >= 2) {
        _stallTicks = 0;
        debugPrint('[Watchdog] STALL detectado; recuperando stream...');
        _recoverFromStreamError();
      }
    } else {
      _stallTicks = 0;
    }
    _lastWatchdogPos = pos;
  }

  Future<void> _recoverFromStreamError() async {
    if (_isRecovering) return;
    final audio = currentAudio;
    if (audio == null || !audio.path.startsWith('yt://')) return;

    final wasPlaying = _userWantedPlaying;
    final position = _player.position;

    // Limitar intentos por pista para no entrar en bucle infinito.
    if (_lastFailedPath == audio.path) {
      _recoverAttempts++;
    } else {
      _lastFailedPath = audio.path;
      _recoverAttempts = 1;
    }
    if (_recoverAttempts > _maxRecoverAttempts) {
      debugPrint('[FritoAudioHandler] Demasiados fallos en ${audio.path}; saltando a la siguiente.');
      _lastFailedPath = null;
      _recoverAttempts = 0;
      await skipToNext();
      return;
    }

    _isRecovering = true;
    try {
      final vId = audio.path.replaceFirst('yt://', '');
      YouTubeRepository.instance.invalidateStreamUrl(vId);
      final freshUrl = await YouTubeRepository.instance.getStreamUrl(
        vId,
        title: audio.title,
        artist: audio.artist,
      );
      if (freshUrl == null || freshUrl.isEmpty) {
        debugPrint('[FritoAudioHandler] Sin URL fresca para $vId');
        StreamErrorBus.report('No se pudo recuperar la conexión del stream. Inténtalo de nuevo.');
        return;
      }

      final isHls = StreamClientUtils.isHlsUrl(freshUrl);
      final isYouTube = StreamClientUtils.isYouTubeMediaHost(Uri.parse(freshUrl).host);
      final effectiveUrl = (!isHls && isYouTube)
          ? await LocalStreamProxy.instance.getProxyUrlAsync(freshUrl)
          : freshUrl;
      final headers = isHls
          ? {'User-Agent': StreamClientUtils.safariUserAgent}
          : (isYouTube ? null : {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:140.0) Gecko/20100101 Firefox/140.0'});

      await _player.setAudioSource(
        AudioSource.uri(
          Uri.parse(effectiveUrl),
          headers: headers,
          tag: mediaItem.value,
        ),
      );
      if (position > Duration.zero) {
        await _player.seek(position);
      }
      if (wasPlaying) {
        await _player.play();
      }
      _lastFailedPath = null;
      _recoverAttempts = 0;
      debugPrint('[FritoAudioHandler] Recuperado tras error; reanudando en $position');
    } catch (e) {
      debugPrint('[FritoAudioHandler] Falló la recuperación: $e');
      StreamErrorBus.report('Error al recuperar la reproducción. Inténtalo de nuevo.');
    } finally {
      _isRecovering = false;
    }
  }

  Future<void> playAudio(AudioFile audio, {List<AudioFile>? newQueue, String? videoId}) async {
    // Nueva pista seleccionada: reiniciar el contador de recuperaciones.
    _lastFailedPath = null;
    _recoverAttempts = 0;
    _isSettingSource = true;

    if (newQueue != null && newQueue.isNotEmpty) {
      _playlist = List.from(newQueue);
      _currentIndex = _playlist.indexWhere((a) => a.path == audio.path);
      if (_currentIndex == -1) {
        _playlist.insert(0, audio);
        _currentIndex = 0;
      }
    } else {
      if (!_playlist.any((a) => a.path == audio.path)) {
        _playlist.add(audio);
      }
      _currentIndex = _playlist.indexWhere((a) => a.path == audio.path);
    }

    // Actualizar MediaItem de la notificación
    final item = MediaItem(
      id: audio.path,
      album: audio.album,
      title: audio.title,
      artist: audio.artist,
      duration: Duration(milliseconds: audio.durationMs),
      artUri: audio.albumUri != null && audio.albumUri!.isNotEmpty ? Uri.tryParse(audio.albumUri!) : null,
    );
    mediaItem.add(item);

    try {
      String playPath = audio.path;
      String? currentVideoId = videoId;
      if (playPath.startsWith('yt://')) {
        final vId = playPath.replaceFirst('yt://', '');
        currentVideoId = vId;
        final resolved = await YouTubeRepository.instance.getStreamUrl(vId, title: audio.title, artist: audio.artist);
        if (resolved != null && resolved.isNotEmpty) {
          playPath = resolved;
        } else {
          throw StateError('No se pudo obtener el audio de este tema');
        }
      }

      if (playPath.startsWith('http')) {
        final uri = Uri.parse(playPath);
        final isHls = StreamClientUtils.isHlsUrl(playPath);
        final isYouTube = StreamClientUtils.isYouTubeMediaHost(uri.host);

        String effectivePlayUrl = playPath;
        Map<String, String>? headers;

        if (isHls) {
          debugPrint('[FritoAudioHandler] Reproduciendo YouTube vía HLS nativo: $playPath');
          effectivePlayUrl = playPath;
          headers = {'User-Agent': StreamClientUtils.safariUserAgent};
        } else if (isYouTube) {
          try {
            effectivePlayUrl = await LocalStreamProxy.instance.getProxyUrlAsync(playPath);
            debugPrint('[FritoAudioHandler] Reproduciendo YouTube vía proxy local: $effectivePlayUrl');
          } catch (e) {
            throw StateError('Proxy local de stream no disponible: $e');
          }
        } else {
          headers = {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:140.0) Gecko/20100101 Firefox/140.0',
          };
        }

        try {
          await _player.setAudioSource(
            AudioSource.uri(
              Uri.parse(effectivePlayUrl),
              headers: headers,
              tag: item,
            ),
          );
        } catch (setSourceError) {
          debugPrint('[FritoAudioHandler] Error inicial en setAudioSource: $setSourceError. Probando URL fresca...');
          // Si la URL expiró o fue rechazada con 403, invalidar y reintentar con URL fresca
          final vId = currentVideoId;
          if (vId != null && vId.isNotEmpty) {
            YouTubeRepository.instance.invalidateStreamUrl(vId);
            final freshUrl = await YouTubeRepository.instance.getStreamUrl(vId, title: audio.title, artist: audio.artist);
            if (freshUrl != null && freshUrl != playPath) {
              final isYtHls = StreamClientUtils.isHlsUrl(freshUrl);
              final isYtFresh = StreamClientUtils.isYouTubeMediaHost(Uri.parse(freshUrl).host);
              final freshEffective = (!isYtHls && isYtFresh)
                  ? await LocalStreamProxy.instance.getProxyUrlAsync(freshUrl)
                  : freshUrl;
              final freshHeaders = isYtHls
                  ? {'User-Agent': StreamClientUtils.safariUserAgent}
                  : (isYtFresh ? null : {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:140.0) Gecko/20100101 Firefox/140.0'});
              await _player.setAudioSource(
                AudioSource.uri(
                  Uri.parse(freshEffective),
                  headers: freshHeaders,
                  tag: item,
                ),
              );
            } else {
              rethrow;
            }
          } else {
            rethrow;
          }
        }
      } else {
        await _player.setFilePath(playPath);
      }
      await _player.play();
      final sessionId = _player.androidAudioSessionId;
      if (sessionId != null) {
        EqualizerService.instance.init(sessionId);
      }
      _stopRequested = false;
      _userWantedPlaying = true;
    } catch (e) {
      debugPrint('[FritoAudioHandler] Error final en reproducción: $e');
      StreamErrorBus.report('No se pudo reproducir el audio. Si el contenido está '
          'restringido por edad, prueba iniciar sesión en YouTube.');
    } finally {
      _isSettingSource = false;
    }
  }

  @override
  Future<void> play() {
    _userWantedPlaying = true;
    return _player.play();
  }

  @override
  Future<void> pause() {
    _userWantedPlaying = false;
    return _player.pause();
  }

  @override
  Future<void> stop() async {
    _stallTimer?.cancel();
    _stallTimer = null;
    _stopRequested = true;
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() async {
    if (_playlist.isEmpty) return;
    if (_player.loopMode == LoopMode.one) {
      await _player.seek(Duration.zero);
      await _player.play();
      return;
    }

    if (_shuffleModeEnabled && _playlist.length > 1) {
      final random = math.Random();
      int next = random.nextInt(_playlist.length);
      while (next == _currentIndex) {
        next = random.nextInt(_playlist.length);
      }
      _currentIndex = next;
      await playAudio(_playlist[_currentIndex]);
      return;
    }

    if (_currentIndex + 1 < _playlist.length) {
      _currentIndex++;
      await playAudio(_playlist[_currentIndex]);
    } else if (_player.loopMode == LoopMode.all) {
      _currentIndex = 0;
      await playAudio(_playlist[_currentIndex]);
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (_playlist.isEmpty) return;
    if (_player.position.inSeconds > 3) {
      await _player.seek(Duration.zero);
      return;
    }

    if (_shuffleModeEnabled && _playlist.length > 1) {
      final random = math.Random();
      int prev = random.nextInt(_playlist.length);
      while (prev == _currentIndex) {
        prev = random.nextInt(_playlist.length);
      }
      _currentIndex = prev;
      await playAudio(_playlist[_currentIndex]);
      return;
    }

    if (_currentIndex - 1 >= 0) {
      _currentIndex--;
      await playAudio(_playlist[_currentIndex]);
    } else if (_player.loopMode == LoopMode.all) {
      _currentIndex = _playlist.length - 1;
      await playAudio(_playlist[_currentIndex]);
    } else {
      await _player.seek(Duration.zero);
    }
  }

  Future<void> setLoopMode(LoopMode mode) => _player.setLoopMode(mode);

  Future<void> setShuffleModeEnabled(bool enabled) async {
    _shuffleModeEnabled = enabled;
    await _player.setShuffleModeEnabled(enabled);
  }
}
