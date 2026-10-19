import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../data/models/audio_file.dart';
import '../data/models/lyrics_models.dart';
import '../data/models/playlist.dart';
import '../data/repository/favorites_repository.dart';
import '../data/repository/lyrics_repository.dart';
import '../data/repository/playlist_repository.dart';
import '../services/audio_handler.dart';
import '../utils/lyrics_translator.dart';

class PlayerProvider extends ChangeNotifier {
  final FritoAudioHandler audioHandler;
  final FavoritesRepository favoritesRepository;
  final PlaylistRepository playlistRepository;
  final LyricsRepository _lyricsRepo = LyricsRepository.instance;

  AudioFile? _currentAudio;
  String? _currentVideoId;
  bool _isPlaying = false;
  int _positionMs = 0;
  int _durationMs = 0;
  double _progress = 0.0;
  bool _shuffleModeEnabled = false;
  LoopMode _loopMode = LoopMode.off;

  LyricsUiState _lyricsState = const LyricsUiIdle();
  bool _isLyricsTranslated = false;
  LyricsData? _originalLyrics;
  LyricsData? _translatedLyrics;

  StreamSubscription? _posSub;
  StreamSubscription? _durSub;
  StreamSubscription? _stateSub;
  StreamSubscription? _mediaItemSub;

  AudioFile? get currentAudio => _currentAudio;
  String? get currentVideoId => _currentVideoId;
  bool get isPlaying => _isPlaying;
  int get positionMs => _positionMs;
  int get durationMs => _durationMs;
  double get progress => _progress;
  bool get shuffleModeEnabled => _shuffleModeEnabled;
  LoopMode get loopMode => _loopMode;
  LyricsUiState get lyricsState => _lyricsState;
  bool get isLyricsTranslated => _isLyricsTranslated;

  Set<String> get favorites => favoritesRepository.favorites;
  List<Playlist> get playlists => playlistRepository.playlists;

  final ValueNotifier<int> positionNotifier = ValueNotifier<int>(0);
  final ValueNotifier<double> progressNotifier = ValueNotifier<double>(0.0);

  PlayerProvider({
    required this.audioHandler,
    required this.favoritesRepository,
    required this.playlistRepository,
  }) {
    _initListeners();
  }

  void _initListeners() {
    _stateSub = audioHandler.player.playerStateStream.listen((state) {
      _isPlaying = state.playing;
      notifyListeners();
    });

    _posSub = audioHandler.player.positionStream.listen((pos) {
      _positionMs = pos.inMilliseconds;
      if (_durationMs > 0) {
        _progress = (_positionMs / _durationMs).clamp(0.0, 1.0);
      }
      positionNotifier.value = _positionMs;
      progressNotifier.value = _progress;
      // No llamamos a notifyListeners() aquí para evitar reconstruir listas de canciones cada 100ms
    });

    _durSub = audioHandler.player.durationStream.listen((dur) {
      if (dur != null) {
        _durationMs = dur.inMilliseconds;
        if (_durationMs > 0) {
          _progress = (_positionMs / _durationMs).clamp(0.0, 1.0);
        }
        progressNotifier.value = _progress;
        notifyListeners();
      }
    });

    _mediaItemSub = audioHandler.mediaItem.listen((item) {
      if (item == null) return;
      _onMediaItemChanged(item);
    });

    favoritesRepository.addListener(notifyListeners);
    playlistRepository.addListener(notifyListeners);
  }

  void _onMediaItemChanged(MediaItem item) {
    final current = _currentAudio;
    final isDifferentSong = current == null || current.path != item.id;

    if (isDifferentSong) {
      final handlerAudio = audioHandler.currentAudio;
      final AudioFile newAudio;
      if (handlerAudio != null && (handlerAudio.path == item.id || handlerAudio.id == item.id.hashCode)) {
        newAudio = handlerAudio;
      } else {
        newAudio = AudioFile(
          id: item.id.hashCode,
          title: item.title,
          artist: item.artist ?? '',
          path: item.id,
          durationMs: item.duration?.inMilliseconds ?? 0,
          sizeBytes: 0,
          albumUri: item.artUri?.toString(),
          album: item.album ?? '',
          dateAdded: DateTime.now().millisecondsSinceEpoch,
        );
      }
      _applyAudioChange(newAudio, item.duration);
    } else {
      if (item.duration != null && item.duration!.inMilliseconds > 0 && _durationMs == 0) {
        _durationMs = item.duration!.inMilliseconds;
        if (_durationMs > 0) {
          _progress = (_positionMs / _durationMs).clamp(0.0, 1.0);
        }
        progressNotifier.value = _progress;
        notifyListeners();
      }
    }
  }

  void _applyAudioChange(AudioFile newAudio, Duration? mediaItemDuration) {
    _currentAudio = newAudio;
    if (newAudio.path.startsWith('yt://')) {
      _currentVideoId = newAudio.path.replaceFirst('yt://', '');
    } else if (_currentVideoId != null && !newAudio.path.startsWith('http')) {
      _currentVideoId = null;
    }

    _durationMs = (mediaItemDuration != null && mediaItemDuration.inMilliseconds > 0)
        ? mediaItemDuration.inMilliseconds
        : newAudio.durationMs;
    _positionMs = 0;
    _progress = 0.0;
    positionNotifier.value = 0;
    progressNotifier.value = 0.0;

    notifyListeners();
    loadLyricsForCurrentAudio();
  }

  void _syncWithAudioHandler() {
    final handlerAudio = audioHandler.currentAudio;
    if (handlerAudio != null && handlerAudio.path != _currentAudio?.path) {
      _applyAudioChange(handlerAudio, null);
    }
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _durSub?.cancel();
    _stateSub?.cancel();
    _mediaItemSub?.cancel();
    positionNotifier.dispose();
    progressNotifier.dispose();
    favoritesRepository.removeListener(notifyListeners);
    playlistRepository.removeListener(notifyListeners);
    super.dispose();
  }

  Future<void> playAudio(AudioFile audio, {List<AudioFile>? newQueue, String? videoId}) async {
    _currentAudio = audio;
    _currentVideoId = videoId ?? (audio.path.startsWith('yt://') ? audio.path.replaceFirst('yt://', '') : null);
    _durationMs = audio.durationMs;
    _positionMs = 0;
    _progress = 0.0;
    positionNotifier.value = 0;
    progressNotifier.value = 0.0;
    _isPlaying = true;
    notifyListeners();

    loadLyricsForCurrentAudio();
    try {
      await audioHandler.playAudio(audio, newQueue: newQueue, videoId: videoId);
    } catch (e) {
      debugPrint('PlayerProvider playAudio error: $e');
      _isPlaying = false;
      notifyListeners();
    }
  }

  Future<void> pause() => audioHandler.pause();
  Future<void> resume() => audioHandler.play();
  Future<void> playPause() async {
    if (_isPlaying) {
      await pause();
    } else {
      await resume();
    }
  }

  Future<void> stopAndClear() async {
    await audioHandler.stop();
    _currentAudio = null;
    _currentVideoId = null;
    _isPlaying = false;
    _positionMs = 0;
    _durationMs = 0;
    _progress = 0.0;
    _lyricsState = const LyricsUiIdle();
    notifyListeners();
  }

  Future<void> seekTo(int positionMs) async {
    await audioHandler.seek(Duration(milliseconds: positionMs));
  }

  Future<void> skipToNext() async {
    await audioHandler.skipToNext();
    _syncWithAudioHandler();
  }

  Future<void> skipToPrevious() async {
    await audioHandler.skipToPrevious();
    _syncWithAudioHandler();
  }

  Future<void> toggleShuffle() async {
    _shuffleModeEnabled = !_shuffleModeEnabled;
    await audioHandler.setShuffleModeEnabled(_shuffleModeEnabled);
    notifyListeners();
  }

  Future<void> toggleRepeatMode() async {
    if (_loopMode == LoopMode.off) {
      _loopMode = LoopMode.all;
    } else if (_loopMode == LoopMode.all) {
      _loopMode = LoopMode.one;
    } else {
      _loopMode = LoopMode.off;
    }
    await audioHandler.setLoopMode(_loopMode);
    notifyListeners();
  }

  bool isFavorite(String path) => favoritesRepository.isFavorite(path);
  Future<void> toggleFavorite(String path) => favoritesRepository.toggleFavorite(path);

  bool get isCurrentFavorite => _currentAudio != null && isFavorite(_currentAudio!.path);

  Future<void> toggleCurrentFavorite() async {
    final audio = _currentAudio;
    if (audio != null) {
      await toggleFavorite(audio.path);
    }
  }

  Future<Playlist> createPlaylist(String name) => playlistRepository.createPlaylist(name);

  Future<void> addToPlaylist(String playlistId, String path) =>
      playlistRepository.addToPlaylist(playlistId, path);

  Future<void> addCurrentAudioToPlaylist(String playlistId) async {
    final audio = _currentAudio;
    if (audio != null) {
      await addToPlaylist(playlistId, audio.path);
    }
  }

  Future<void> loadLyricsForCurrentAudio() async {
    final audio = _currentAudio;
    if (audio == null) {
      _lyricsState = const LyricsUiIdle();
      notifyListeners();
      return;
    }

    _lyricsState = const LyricsUiLoading();
    _isLyricsTranslated = false;
    _originalLyrics = null;
    _translatedLyrics = null;
    notifyListeners();

    final lyrics = await _lyricsRepo.getLyrics(
      title: audio.title,
      artist: audio.artist,
      durationSeconds: audio.durationMs ~/ 1000,
    );

    // Si durante la petición cambió de canción, descartar resultado obsoleto
    if (_currentAudio?.path != audio.path) {
      return;
    }

    if (lyrics != null && (lyrics.lines.isNotEmpty || (lyrics.plainLyrics != null && lyrics.plainLyrics!.isNotEmpty))) {
      var processedLyrics = lyrics;
      if (processedLyrics.lines.isEmpty && processedLyrics.plainLyrics != null && processedLyrics.plainLyrics!.trim().isNotEmpty) {
        final split = processedLyrics.plainLyrics!
            .split('\n')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        final structuredLines = List.generate(
          split.length,
          (i) => LyricLine(timestampMs: -1, text: split[i]),
        );
        processedLyrics = LyricsData(
          title: processedLyrics.title,
          artist: processedLyrics.artist,
          lines: structuredLines,
          plainLyrics: processedLyrics.plainLyrics,
          isSynced: false,
          source: processedLyrics.source,
        );
      }
      _originalLyrics = processedLyrics;
      _lyricsState = LyricsUiSuccess(processedLyrics);
    } else {
      _lyricsState = const LyricsUiEmpty();
    }
    notifyListeners();
  }

  Future<void> toggleLyricsTranslation() async {
    if (_originalLyrics == null) return;

    if (_isLyricsTranslated) {
      _isLyricsTranslated = false;
      _lyricsState = LyricsUiSuccess(_originalLyrics!);
      notifyListeners();
      return;
    }

    if (_translatedLyrics != null) {
      _isLyricsTranslated = true;
      _lyricsState = LyricsUiSuccess(_translatedLyrics!);
      notifyListeners();
      return;
    }

    // Traducir líneas manteniendo el texto original intacto (modo bilingüe)
    final lines = _originalLyrics!.lines;
    if (lines.isNotEmpty) {
      final texts = lines.map((l) => l.text).toList();
      final translatedTexts = await LyricsTranslator.translate(texts);
      final newLines = List.generate(lines.length, (i) {
        return LyricLine(
          timestampMs: lines[i].timestampMs,
          text: lines[i].text,
          translatedText: translatedTexts[i],
        );
      });

      _translatedLyrics = LyricsData(
        title: _originalLyrics!.title,
        artist: _originalLyrics!.artist,
        lines: newLines,
        plainLyrics: _originalLyrics!.plainLyrics,
        isSynced: _originalLyrics!.isSynced,
        source: _originalLyrics!.source,
      );

      _isLyricsTranslated = true;
      _lyricsState = LyricsUiSuccess(_translatedLyrics!);
      notifyListeners();
    }
  }

  Future<void> playAudios(List<AudioFile> audios, int index) async {
    if (index >= 0 && index < audios.length) {
      await playAudio(audios[index], newQueue: audios);
    }
  }
}


