import 'innertube_models.dart';

class InnerTubeParser {
  static String? _extractText(dynamic obj) {
    if (obj == null) return null;
    if (obj is String) return obj;
    if (obj is Map) {
      if (obj.containsKey('simpleText')) return obj['simpleText']?.toString();
      if (obj.containsKey('runs') && obj['runs'] is List) {
        return (obj['runs'] as List).map((r) => r['text'] ?? '').join('');
      }
      if (obj.containsKey('text')) return _extractText(obj['text']);
      if (obj.containsKey('musicResponsiveListItemFlexColumnRenderer')) {
        return _extractText(obj['musicResponsiveListItemFlexColumnRenderer']);
      }
    }
    if (obj is List) {
      return obj.map((e) => _extractText(e) ?? '').join('');
    }
    return obj.toString();
  }

  static String _extractThumbnail(dynamic obj) {
    if (obj == null) return '';
    if (obj is String) {
      String url = obj.trim();
      if (url.startsWith('//')) url = 'https:$url';
      return url;
    }

    if (obj is List) {
      if (obj.isEmpty) return '';
      final last = obj.last;
      return _extractThumbnail(last);
    }

    if (obj is Map) {
      if (obj.containsKey('url') && obj['url'] is String) {
        String url = obj['url'].toString().trim();
        if (url.startsWith('//')) url = 'https:$url';
        return url;
      }
      if (obj.containsKey('thumbnails') && obj['thumbnails'] != null) {
        return _extractThumbnail(obj['thumbnails']);
      }
      if (obj.containsKey('thumbnail') && obj['thumbnail'] != null) {
        return _extractThumbnail(obj['thumbnail']);
      }
      if (obj.containsKey('musicThumbnailRenderer') && obj['musicThumbnailRenderer'] != null) {
        return _extractThumbnail(obj['musicThumbnailRenderer']);
      }
      if (obj.containsKey('croppedSquareThumbnailRenderer') && obj['croppedSquareThumbnailRenderer'] != null) {
        return _extractThumbnail(obj['croppedSquareThumbnailRenderer']);
      }
      if (obj.containsKey('thumbnailRenderer') && obj['thumbnailRenderer'] != null) {
        return _extractThumbnail(obj['thumbnailRenderer']);
      }
      if (obj.containsKey('musicItemThumbnailOverlayRenderer') && obj['musicItemThumbnailOverlayRenderer'] != null) {
        return _extractThumbnail(obj['musicItemThumbnailOverlayRenderer']);
      }
      if (obj.containsKey('accountPhoto') && obj['accountPhoto'] != null) {
        return _extractThumbnail(obj['accountPhoto']);
      }
    }
    return '';
  }

  static int? _extractDuration(String? text) {
    if (text == null) return null;
    final parts = text.split(':');
    if (parts.length == 2) {
      final m = int.tryParse(parts[0]) ?? 0;
      final s = int.tryParse(parts[1]) ?? 0;
      return m * 60 + s;
    } else if (parts.length == 3) {
      final h = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts[1]) ?? 0;
      final s = int.tryParse(parts[2]) ?? 0;
      return h * 3600 + m * 60 + s;
    }
    return null;
  }

  static YTItem? _parseResponsiveListItem(Map item) {
    try {
      final renderer = item['musicResponsiveListItemRenderer'] ?? item;
      final flexColumns = renderer['flexColumns'] as List?;
      if (flexColumns == null || flexColumns.isEmpty) return null;

      final col0 = flexColumns[0]['musicResponsiveListItemFlexColumnRenderer'] ?? flexColumns[0];
      final title = _extractText(col0?['text']) ?? _extractText(col0) ?? '';

      final nav = renderer['navigationEndpoint'] ??
          renderer['playNavigationEndpoint'] ??
          renderer['doubleTapCommand'] ??
          (col0?['text']?['runs'] is List && (col0['text']['runs'] as List).isNotEmpty
              ? col0['text']['runs'][0]['navigationEndpoint']
              : null);

      final browseEndpoint = nav?['browseEndpoint'];
      final browseId = browseEndpoint?['browseId']?.toString();
      final pageType = browseEndpoint?['browseEndpointContextSupportedConfigs']
          ?['browseEndpointContextMusicConfig']?['pageType']?.toString();

      final thumb = _extractThumbnail(renderer['thumbnail']);
      final thumbnail = thumb.isNotEmpty ? thumb : _extractThumbnail(renderer['thumbnailRenderer']);

      // 1. Es Artista si pageType es MUSIC_PAGE_TYPE_ARTIST o browseId empieza con 'UC'
      if (pageType == 'MUSIC_PAGE_TYPE_ARTIST' ||
          pageType == 'MUSIC_PAGE_TYPE_LIBRARY_ARTIST' ||
          (browseId != null && browseId.startsWith('UC'))) {
        return ArtistItem(
          id: browseId ?? '',
          title: title.isNotEmpty ? title : 'Artista',
          thumbnail: thumbnail,
        );
      }

      // 2. Es Playlist si pageType es MUSIC_PAGE_TYPE_PLAYLIST o browseId empieza con prefijos de playlist
      if (pageType == 'MUSIC_PAGE_TYPE_PLAYLIST' ||
          pageType == 'MUSIC_PAGE_TYPE_USER_PLAYLIST' ||
          (browseId != null &&
              (browseId.startsWith('VL') ||
                  browseId.startsWith('PL') ||
                  browseId.startsWith('RD') ||
                  browseId.startsWith('FL') ||
                  browseId.startsWith('LL') ||
                  browseId.startsWith('OLAK') ||
                  browseId.startsWith('FEmusic_')))) {
        String? authorName;
        String? songCount;
        if (flexColumns.length > 1) {
          final col1 = flexColumns[1]['musicResponsiveListItemFlexColumnRenderer'] ?? flexColumns[1];
          final runs = col1?['text']?['runs'] as List? ?? [];
          if (runs.isNotEmpty) {
            authorName = runs.first['text']?.toString();
            songCount = runs.last['text']?.toString();
          }
        }
        final cleanId = browseId != null && browseId.startsWith('VL')
            ? browseId.substring(2)
            : (browseId ?? '');
        return PlaylistItem(
          id: cleanId,
          title: title.isNotEmpty ? title : 'Playlist',
          thumbnail: thumbnail,
          author: authorName != null ? Artist(name: authorName) : null,
          songCountText: songCount,
        );
      }

      // 3. Es Álbum si pageType es MUSIC_PAGE_TYPE_ALBUM o browseId empieza con 'MPREb_'
      if (pageType == 'MUSIC_PAGE_TYPE_ALBUM' || (browseId != null && browseId.startsWith('MPREb_'))) {
        return AlbumItem(
          browseId: browseId ?? '',
          playlistId: '',
          title: title.isNotEmpty ? title : 'Álbum',
          thumbnail: thumbnail,
        );
      }

      // 4. De lo contrario, buscar videoId para SongItem
      String? videoId = nav?['watchEndpoint']?['videoId'];
      if (videoId == null && renderer['playlistItemData'] != null) {
        videoId = renderer['playlistItemData']['videoId'];
      }
      if (videoId == null && renderer['overlay'] != null) {
        videoId = renderer['overlay']?['musicItemThumbnailOverlayRenderer']
            ?['content']?['musicPlayButtonRenderer']
            ?['playNavigationEndpoint']?['watchEndpoint']?['videoId'];
      }
      if (videoId == null) {
        final runs = col0?['text']?['runs'] as List?;
        if (runs != null && runs.isNotEmpty) {
          videoId = runs[0]?['navigationEndpoint']?['watchEndpoint']?['videoId'];
        }
      }

      if (videoId == null || videoId.isEmpty) return null;

      // Artistas, Álbum y Duración en col1
      final artists = <Artist>[];
      Album? album;
      int? duration;

      if (flexColumns.length > 1) {
        final col1 = flexColumns[1]['musicResponsiveListItemFlexColumnRenderer'] ?? flexColumns[1];
        final runs = col1?['text']?['runs'] as List? ?? [];
        for (final run in runs) {
          final text = run['text']?.toString() ?? '';
          final bId = run['navigationEndpoint']?['browseEndpoint']?['browseId'];
          final pType = run['navigationEndpoint']?['browseEndpoint']?['browseEndpointContextSupportedConfigs']
              ?['browseEndpointContextMusicConfig']?['pageType'];

          if (pType == 'MUSIC_PAGE_TYPE_ARTIST') {
            artists.add(Artist(name: text, id: bId));
          } else if (pType == 'MUSIC_PAGE_TYPE_ALBUM') {
            album = Album(name: text, id: bId ?? '');
          } else if (text.contains(':')) {
            duration = _extractDuration(text);
          } else if (text != ' • ' && text != ' & ' && artists.isEmpty) {
            artists.add(Artist(name: text, id: bId));
          }
        }
      }

      // Duración en fixedColumns (estándar en listas y álbumes de YouTube Music)
      if (duration == null) {
        final fixedCols = renderer['fixedColumns'] as List? ?? [];
        for (final col in fixedCols) {
          final fixedRenderer = col['musicResponsiveListItemFixedColumnRenderer'] ??
              col['musicResponsiveListItemFlexColumnRenderer'] ??
              col;
          final runs = fixedRenderer?['text']?['runs'] as List? ?? [];
          for (final run in runs) {
            final text = run['text']?.toString() ?? '';
            if (text.contains(':')) {
              final d = _extractDuration(text);
              if (d != null && d > 0) {
                duration = d;
                break;
              }
            }
          }
          if (duration != null) break;
        }
      }

      // Buscar duración en columnas adicionales (col2, col3, etc.) si aún es null
      if (duration == null && flexColumns.length > 2) {
        for (int i = 2; i < flexColumns.length; i++) {
          final col = flexColumns[i]['musicResponsiveListItemFlexColumnRenderer'] ?? flexColumns[i];
          final runs = col?['text']?['runs'] as List? ?? [];
          for (final run in runs) {
            final text = run['text']?.toString() ?? '';
            if (text.contains(':')) {
              final d = _extractDuration(text);
              if (d != null && d > 0) {
                duration = d;
                break;
              }
            }
          }
          if (duration != null) break;
        }
      }

      // Fallback thumbnail de YouTube si está vacío
      final finalThumbnail = thumbnail.isNotEmpty
          ? thumbnail
          : 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg';

      final musicVideoType = renderer['musicVideoType']?.toString() ??
          nav?['watchEndpoint']?['watchEndpointMusicSupportedConfigs']
              ?['watchEndpointMusicConfig']?['musicVideoType']?.toString();

      return SongItem(
        id: videoId,
        title: title,
        artists: artists.isNotEmpty ? artists : [const Artist(name: 'Desconocido')],
        album: album,
        duration: duration,
        musicVideoType: musicVideoType,
        thumbnail: finalThumbnail,
      );
    } catch (e) {
      return null;
    }
  }

  static YTItem? _parseTwoRowItem(Map item) {
    try {
      final renderer = item['musicTwoRowItemRenderer'] ?? item;
      final title = _extractText(renderer['title']) ?? '';
      final thumb1 = _extractThumbnail(renderer['thumbnailRenderer']);
      final thumbnail = thumb1.isNotEmpty ? thumb1 : _extractThumbnail(renderer['thumbnail']);
      final nav = renderer['navigationEndpoint'] ??
          (renderer['title']?['runs'] is List && (renderer['title']['runs'] as List).isNotEmpty
              ? renderer['title']['runs'][0]['navigationEndpoint']
              : null);
      final browseId = nav?['browseEndpoint']?['browseId']?.toString();
      final pageType = nav?['browseEndpoint']?['browseEndpointContextSupportedConfigs']
          ?['browseEndpointContextMusicConfig']?['pageType']?.toString();

      final thumbOverlay = renderer['thumbnailOverlay']?['musicItemThumbnailOverlayRenderer']?['content']?['musicPlayButtonRenderer']?['playNavigationEndpoint'];
      final playlistNavId = thumbOverlay?['watchPlaylistEndpoint']?['playlistId']?.toString() ??
          renderer['playNavigationEndpoint']?['watchPlaylistEndpoint']?['playlistId']?.toString() ??
          nav?['watchPlaylistEndpoint']?['playlistId']?.toString();

      String? authorName;
      String? songCount;
      final subtitleRuns = renderer['subtitle']?['runs'] as List?;
      if (subtitleRuns != null && subtitleRuns.isNotEmpty) {
        authorName = subtitleRuns.first['text']?.toString();
        songCount = subtitleRuns.last['text']?.toString();
      }

      if (browseId != null) {
        if (pageType == 'MUSIC_PAGE_TYPE_ARTIST' || browseId.startsWith('UC')) {
          return ArtistItem(
            id: browseId,
            title: title,
            thumbnail: thumbnail,
          );
        } else if (pageType == 'MUSIC_PAGE_TYPE_ALBUM' || browseId.startsWith('MPREb_')) {
          return AlbumItem(
            browseId: browseId,
            playlistId: '',
            title: title,
            thumbnail: thumbnail,
          );
        } else if (pageType == 'MUSIC_PAGE_TYPE_PLAYLIST' ||
            pageType == 'MUSIC_PAGE_TYPE_USER_PLAYLIST' ||
            browseId.startsWith('VL') ||
            browseId.startsWith('PL') ||
            browseId.startsWith('RD') ||
            browseId.startsWith('FL') ||
            browseId.startsWith('LL') ||
            browseId.startsWith('OLAK') ||
            browseId.startsWith('FEmusic_')) {
          final cleanId = browseId.startsWith('VL') ? browseId.substring(2) : browseId;
          return PlaylistItem(
            id: cleanId,
            title: title.isNotEmpty ? title : 'Playlist',
            thumbnail: thumbnail,
            author: authorName != null ? Artist(name: authorName) : null,
            songCountText: songCount,
          );
        }
      }

      if (playlistNavId != null && playlistNavId.isNotEmpty) {
        final cleanId = playlistNavId.startsWith('VL') ? playlistNavId.substring(2) : playlistNavId;
        return PlaylistItem(
          id: cleanId,
          title: title.isNotEmpty ? title : 'Playlist',
          thumbnail: thumbnail,
          author: authorName != null ? Artist(name: authorName) : null,
          songCountText: songCount,
        );
      }

      // Check if song
      final watchNav = thumbOverlay?['watchEndpoint'] ?? nav?['watchEndpoint'] ?? renderer['playNavigationEndpoint']?['watchEndpoint'];
      if (watchNav != null && watchNav['videoId'] != null) {
        final videoId = watchNav['videoId'].toString();
        final finalThumbnail = thumbnail.isNotEmpty ? thumbnail : 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg';
        return SongItem(
          id: videoId,
          title: title,
          artists: authorName != null ? [Artist(name: authorName)] : [const Artist(name: '')],
          thumbnail: finalThumbnail,
        );
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  static List<YTItem> parseSearchResults(dynamic data) {
    final results = <YTItem>[];
    if (data == null || data is! Map) return results;

    try {
      void traverse(dynamic node) {
        if (node is Map) {
          if (node.containsKey('musicResponsiveListItemRenderer')) {
            final item = _parseResponsiveListItem(node);
            if (item != null) results.add(item);
          } else if (node.containsKey('musicTwoRowItemRenderer')) {
            final item = _parseTwoRowItem(node);
            if (item != null) results.add(item);
          } else {
            for (final v in node.values) {
              traverse(v);
            }
          }
        } else if (node is List) {
          for (final item in node) {
            traverse(item);
          }
        }
      }

      traverse(data);
    } catch (_) {}
    return results;
  }

  static List<String> parseSearchSuggestions(dynamic data) {
    final list = <String>[];
    if (data == null || data is! Map) return list;

    try {
      void traverse(dynamic node) {
        if (node is Map) {
          if (node.containsKey('searchSuggestionRenderer')) {
            final text = _extractText(node['searchSuggestionRenderer']['suggestion']);
            if (text != null && text.isNotEmpty) list.add(text);
          } else {
            for (final v in node.values) {
              traverse(v);
            }
          }
        } else if (node is List) {
          for (final item in node) {
            traverse(item);
          }
        }
      }

      traverse(data);
    } catch (_) {}
    return list;
  }

  static List<Map<String, dynamic>> parseHomeShelves(dynamic data) {
    final shelves = <Map<String, dynamic>>[];
    if (data == null || data is! Map) return shelves;

    try {
      void traverse(dynamic node) {
        if (node is Map) {
          if (node.containsKey('musicCarouselShelfRenderer')) {
            final shelf = node['musicCarouselShelfRenderer'];
            final title = _extractText(shelf['header']?['musicCarouselShelfBasicHeaderRenderer']?['title']) ?? '';
            final contents = shelf['contents'] as List? ?? [];
            final items = <YTItem>[];

            for (final c in contents) {
              if (c['musicTwoRowItemRenderer'] != null) {
                final item = _parseTwoRowItem(c);
                if (item != null) items.add(item);
              } else if (c['musicResponsiveListItemRenderer'] != null) {
                final song = _parseResponsiveListItem(c);
                if (song != null) items.add(song);
              }
            }

            if (items.isNotEmpty) {
              shelves.add({
                'title': title.isNotEmpty ? title : 'Recomendaciones',
                'items': items,
              });
            }
          } else if (node.containsKey('musicShelfRenderer')) {
            final shelf = node['musicShelfRenderer'];
            final title = _extractText(shelf['title']) ?? '';
            final contents = shelf['contents'] as List? ?? [];
            final items = <YTItem>[];

            for (final c in contents) {
              if (c['musicResponsiveListItemRenderer'] != null) {
                final song = _parseResponsiveListItem(c);
                if (song != null) items.add(song);
              } else if (c['musicTwoRowItemRenderer'] != null) {
                final item = _parseTwoRowItem(c);
                if (item != null) items.add(item);
              }
            }

            if (items.isNotEmpty) {
              shelves.add({
                'title': title.isNotEmpty ? title : 'Selección para ti',
                'items': items,
              });
            }
          } else if (node.containsKey('gridRenderer')) {
            final grid = node['gridRenderer'];
            final contents = grid['items'] as List? ?? [];
            final items = <YTItem>[];

            for (final c in contents) {
              if (c['musicTwoRowItemRenderer'] != null) {
                final item = _parseTwoRowItem(c);
                if (item != null) items.add(item);
              } else if (c['musicResponsiveListItemRenderer'] != null) {
                final song = _parseResponsiveListItem(c);
                if (song != null) items.add(song);
              }
            }

            if (items.isNotEmpty) {
              shelves.add({
                'title': 'Destacados',
                'items': items,
              });
            }
          } else {
            for (final v in node.values) {
              traverse(v);
            }
          }
        } else if (node is List) {
          for (final item in node) {
            traverse(item);
          }
        }
      }

      traverse(data);
    } catch (_) {}
    return shelves;
  }

  static ArtistPageData? parseArtistPage(dynamic data, String artistId) {
    if (data == null || data is! Map) return null;

    try {
      String title = '';
      String thumbnail = '';
      String? channelId;
      String? subscriberCountText;
      final topSongs = <SongItem>[];
      final albums = <AlbumItem>[];
      final singles = <AlbumItem>[];
      final related = <ArtistItem>[];

      void traverse(dynamic node) {
        if (node is Map) {
          if (node.containsKey('musicResponsiveListItemRenderer')) {
            final song = _parseResponsiveListItem(node);
            if (song is SongItem) topSongs.add(song);
          } else if (node.containsKey('musicTwoRowItemRenderer')) {
            final item = _parseTwoRowItem(node);
            if (item is AlbumItem) {
              albums.add(item);
            } else if (item is ArtistItem) {
              related.add(item);
            }
          } else if (node.containsKey('musicImmersiveHeaderRenderer')) {
            final header = node['musicImmersiveHeaderRenderer'];
            title = _extractText(header['title']) ?? '';
            thumbnail = _extractThumbnail(header['thumbnail']);
            final subBtn = header['subscriptionButton']?['subscribeButtonRenderer'];
            if (subBtn != null && subBtn is Map) {
              channelId = subBtn['channelId']?.toString();
              subscriberCountText = _extractText(subBtn['subscriberCountText']) ??
                  _extractText(subBtn['subscriberCountWithSubscribeText']);
            }
          } else if (node.containsKey('musicVisualHeaderRenderer')) {
            final header = node['musicVisualHeaderRenderer'];
            title = _extractText(header['title']) ?? '';
            thumbnail = _extractThumbnail(header['thumbnail']);
            final subBtn = header['subscriptionButton']?['subscribeButtonRenderer'];
            if (subBtn != null && subBtn is Map) {
              channelId = subBtn['channelId']?.toString();
              subscriberCountText = _extractText(subBtn['subscriberCountText']) ??
                  _extractText(subBtn['subscriberCountWithSubscribeText']);
            }
          } else {
            for (final v in node.values) {
              traverse(v);
            }
          }
        } else if (node is List) {
          for (final item in node) {
            traverse(item);
          }
        }
      }

      traverse(data);

      final effectiveChannelId = channelId ?? (artistId.startsWith('UC') ? artistId : 'UC$artistId');

      return ArtistPageData(
        artist: ArtistItem(
          id: artistId,
          title: title.isNotEmpty ? title : 'Artista',
          thumbnail: thumbnail,
          channelId: effectiveChannelId,
          subscriberCountText: subscriberCountText,
        ),
        topSongs: topSongs,
        albums: albums,
        singles: singles,
        relatedArtists: related,
      );
    } catch (_) {
      return null;
    }
  }

  static AlbumPageData? parseAlbumPage(dynamic data, String browseId) {
    if (data == null || data is! Map) return null;

    try {
      String title = '';
      String thumbnail = '';
      final songs = <SongItem>[];

      void traverse(dynamic node) {
        if (node is Map) {
          if (node.containsKey('musicResponsiveListItemRenderer')) {
            final song = _parseResponsiveListItem(node);
            if (song is SongItem) songs.add(song);
          } else if (node.containsKey('musicResponsiveHeaderRenderer')) {
            final header = node['musicResponsiveHeaderRenderer'];
            title = _extractText(header['title']) ?? '';
            thumbnail = _extractThumbnail(header['thumbnail']);
          } else {
            for (final v in node.values) {
              traverse(v);
            }
          }
        } else if (node is List) {
          for (final item in node) {
            traverse(item);
          }
        }
      }

      traverse(data);

      return AlbumPageData(
        album: AlbumItem(
          browseId: browseId,
          playlistId: '',
          title: title.isNotEmpty ? title : 'Álbum',
          thumbnail: thumbnail,
        ),
        songs: songs,
      );
    } catch (_) {
      return null;
    }
  }

  static PlaylistPageData? parsePlaylistPage(dynamic data, String playlistId) {
    if (data == null || data is! Map) return null;

    try {
      String title = '';
      String thumbnail = '';
      final songs = <SongItem>[];

      void traverse(dynamic node) {
        if (node is Map) {
          if (node.containsKey('musicResponsiveListItemRenderer')) {
            final song = _parseResponsiveListItem(node);
            if (song is SongItem) songs.add(song);
          } else if (node.containsKey('musicResponsiveHeaderRenderer')) {
            final header = node['musicResponsiveHeaderRenderer'];
            title = _extractText(header['title']) ?? '';
            thumbnail = _extractThumbnail(header['thumbnail']);
          } else if (node.containsKey('musicEditablePlaylistDetailHeaderRenderer')) {
            final header = node['musicEditablePlaylistDetailHeaderRenderer']['header']?['musicResponsiveHeaderRenderer'];
            if (header != null) {
              title = _extractText(header['title']) ?? '';
              thumbnail = _extractThumbnail(header['thumbnail']);
            }
          } else {
            for (final v in node.values) {
              traverse(v);
            }
          }
        } else if (node is List) {
          for (final item in node) {
            traverse(item);
          }
        }
      }

      traverse(data);

      return PlaylistPageData(
        playlist: PlaylistItem(
          id: playlistId,
          title: title.isNotEmpty ? title : 'Playlist',
          thumbnail: thumbnail,
        ),
        songs: songs,
      );
    } catch (_) {
      return null;
    }
  }

  static bool _isLikedSongsEntry(PlaylistItem item) {
    if (item.id == 'LM' || item.id == 'FEmusic_liked_songs' || item.id.startsWith('RDCLAK5uy')) {
      return true;
    }
    final lowerTitle = item.title.toLowerCase();
    final lowerCount = (item.songCountText ?? '').toLowerCase();
    final isAuto = lowerCount.contains('autogenerada') || lowerCount.contains('auto-generated');
    final isLikedTitle = lowerTitle == 'tus me gusta' ||
        lowerTitle == 'música que te gustó' ||
        lowerTitle == 'liked music' ||
        lowerTitle == 'your likes' ||
        lowerTitle.contains('que te gustó');
    return (isLikedTitle && isAuto) || (isLikedTitle && item.id.startsWith('RD'));
  }

  static List<PlaylistItem> parseUserPlaylists(dynamic data) {
    final list = <PlaylistItem>[];
    if (data == null || data is! Map) return list;

    try {
      // 1. Acceso directo idéntico a Kotlin YouTube.library():
      // contents.singleColumnBrowseResultsRenderer.tabs[0].tabRenderer.content.sectionListRenderer.contents
      final tabs = data['contents']?['singleColumnBrowseResultsRenderer']?['tabs'] as List?;
      if (tabs != null && tabs.isNotEmpty) {
        for (final tab in tabs) {
          final sectionContents = tab['tabRenderer']?['content']?['sectionListRenderer']?['contents'] as List?;
          if (sectionContents != null) {
            for (final section in sectionContents) {
              final gridItems = section['gridRenderer']?['items'] as List?;
              if (gridItems != null) {
                for (final item in gridItems) {
                  if (item is Map) {
                    final p = _parseTwoRowItem(item);
                    if (p is PlaylistItem && !_isLikedSongsEntry(p)) {
                      if (!list.any((x) => x.id == p.id)) list.add(p);
                    }
                  }
                }
              }
              final shelfItems = section['musicShelfRenderer']?['contents'] as List?;
              if (shelfItems != null) {
                for (final item in shelfItems) {
                  if (item is Map) {
                    final p = _parseResponsiveListItem(item) ?? _parseTwoRowItem(item);
                    if (p is PlaylistItem && !_isLikedSongsEntry(p)) {
                      if (!list.any((x) => x.id == p.id)) list.add(p);
                    }
                  }
                }
              }
            }
          }
        }
      }

      // 2. Traversal recursivo exhaustivo como fallback para cualquier otra estructura
      void traverse(dynamic node) {
        if (node is Map) {
          if (node.containsKey('musicTwoRowItemRenderer')) {
            final item = _parseTwoRowItem(node);
            if (item is PlaylistItem && !_isLikedSongsEntry(item)) {
              if (!list.any((p) => p.id == item.id)) list.add(item);
            }
          } else if (node.containsKey('musicResponsiveListItemRenderer')) {
            final item = _parseResponsiveListItem(node);
            if (item is PlaylistItem && !_isLikedSongsEntry(item)) {
              if (!list.any((p) => p.id == item.id)) list.add(item);
            }
          } else {
            for (final v in node.values) {
              traverse(v);
            }
          }
        } else if (node is List) {
          for (final item in node) {
            traverse(item);
          }
        }
      }

      traverse(data);
    } catch (_) {}
    return list;
  }

  /// Parsea una lista de artistas de la biblioteca o suscripciones
  static List<ArtistItem> parseArtists(dynamic data) {
    final list = <ArtistItem>[];
    if (data == null || data is! Map) return list;

    try {
      void traverse(dynamic node) {
        if (node is Map) {
          if (node.containsKey('musicTwoRowItemRenderer')) {
            final item = _parseTwoRowItem(node);
            if (item is ArtistItem && item.id.isNotEmpty && !list.any((x) => x.id == item.id)) {
              list.add(item);
            }
          } else if (node.containsKey('musicResponsiveListItemRenderer')) {
            final item = _parseResponsiveListItem(node);
            if (item is ArtistItem && item.id.isNotEmpty && !list.any((x) => x.id == item.id)) {
              list.add(item);
            }
          } else {
            for (final v in node.values) {
              traverse(v);
            }
          }
        } else if (node is List) {
          for (final item in node) {
            traverse(item);
          }
        }
      }

      traverse(data);
    } catch (_) {}
    return list;
  }

  static Map<String, String>? parseAccountInfo(dynamic data) {
    if (data == null || data is! Map) return null;
    try {
      String name = '';
      String email = '';
      String handle = '';
      String avatar = '';

      void traverse(dynamic node) {
        if (node is Map) {
          if (node.containsKey('activeAccountHeaderRenderer')) {
            final renderer = node['activeAccountHeaderRenderer'];
            name = _extractText(renderer['accountName']) ?? '';
            email = _extractText(renderer['email']) ?? '';
            handle = _extractText(renderer['channelHandle']) ?? '';
            avatar = _extractThumbnail(renderer['accountPhoto']);
          } else {
            for (final v in node.values) {
              traverse(v);
            }
          }
        } else if (node is List) {
          for (final item in node) {
            traverse(item);
          }
        }
      }

      traverse(data);
      if (name.isNotEmpty || email.isNotEmpty || avatar.isNotEmpty) {
        return {
          'name': name,
          'email': email,
          'handle': handle,
          'avatar': avatar,
        };
      }
    } catch (_) {}
    return null;
  }

  static List<SongItem> parseNextSongs(dynamic data) {
    final songs = <SongItem>[];
    if (data == null || data is! Map) return songs;

    try {
      void traverse(dynamic node) {
        if (node is Map) {
          if (node.containsKey('playlistPanelVideoRenderer')) {
            final renderer = node['playlistPanelVideoRenderer'];
            final title = _extractText(renderer['title']) ?? '';
            final videoId = renderer['videoId']?.toString();
            final thumbnail = _extractThumbnail(renderer['thumbnail']);
            final artistText = _extractText(renderer['shortBylineText']) ?? 'Artista';

            if (videoId != null && videoId.isNotEmpty) {
              int? duration;
              final lenText = _extractText(renderer['lengthText']);
              if (lenText != null && lenText.contains(':')) {
                duration = _extractDuration(lenText);
              }
              songs.add(SongItem(
                id: videoId,
                title: title,
                artists: [Artist(name: artistText)],
                duration: duration,
                thumbnail: thumbnail,
              ));
            }
          } else {
            for (final v in node.values) {
              traverse(v);
            }
          }
        } else if (node is List) {
          for (final item in node) {
            traverse(item);
          }
        }
      }

      traverse(data);
    } catch (_) {}
    return songs;
  }

  static List<SongItem> parseMusicHistory(dynamic data) {
    final songs = <SongItem>[];
    if (data == null || data is! Map) return songs;

    try {
      void traverse(dynamic node) {
        if (node is Map) {
          if (node.containsKey('musicResponsiveListItemRenderer')) {
            final song = _parseResponsiveListItem(node);
            if (song is SongItem && !songs.any((s) => s.id == song.id)) {
              songs.add(song);
            }
          } else {
            for (final v in node.values) {
              traverse(v);
            }
          }
        } else if (node is List) {
          for (final item in node) {
            traverse(item);
          }
        }
      }

      traverse(data);
    } catch (_) {}
    return songs;
  }
}
