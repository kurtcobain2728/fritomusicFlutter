import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/home_shelf.dart';
import '../../data/network/innertube/innertube_models.dart';
import '../../data/repository/favorite_artists_manager.dart';
import '../../utils/image_utils.dart';
import '../components/bencho_carousel.dart';
import '../components/frito_pull_refresh.dart';

class StreamHomeScreen extends StatelessWidget {
  final List<HomeShelf> homeShelves;
  final HomePage? homePage;
  final ExplorePage? explorePage;
  final bool isLoading;
  final Function(SongItem song, List<SongItem> sectionSongs) onPlaySong;
  final Function(String browseId) onAlbumClick;
  final Function(String browseId) onArtistClick;
  final VoidCallback onSeeAllArtists;
  final VoidCallback onRefresh;
  final List<SongItem> recentlyPlayed;
  final AppColors appColors;

  const StreamHomeScreen({
    super.key,
    this.homeShelves = const [],
    this.homePage,
    this.explorePage,
    this.isLoading = false,
    required this.onPlaySong,
    required this.onAlbumClick,
    required this.onArtistClick,
    required this.onSeeAllArtists,
    required this.onRefresh,
    this.recentlyPlayed = const [],
    required this.appColors,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading && homeShelves.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF1DB954)),
      );
    }

    final favoriteArtists = FavoriteArtistsManager.instance.favoriteArtists;
    final favoriteArtistIds = favoriteArtists.map((a) => a.id).where((id) => id.isNotEmpty).toSet();

    final recommendedArtists = (homePage?.sections ?? [])
        .expand((s) => s.items)
        .whereType<ArtistItem>()
        .where((a) => !favoriteArtistIds.contains(a.id))
        .fold<List<ArtistItem>>([], (acc, a) {
          if (!acc.any((item) => item.id == a.id)) acc.add(a);
          return acc;
        });

    return FritoPullRefresh(
      isRefreshing: isLoading,
      appColors: appColors,
      onRefresh: () async => onRefresh(),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          if (homeShelves.isNotEmpty) ...[
            for (final shelf in homeShelves) ...[
              Builder(
                builder: (context) {
                  final isArtistShelf = shelf.id == 'popular_artists' ||
                      shelf.title.toLowerCase().contains('artistas para ti');
                  var displayItems = shelf.items;
                  if (isArtistShelf) {
                    final filtered = shelf.items
                        .where((it) => it is! ArtistItem || !favoriteArtistIds.contains(it.id))
                        .toList();
                    if (filtered.isNotEmpty) displayItems = filtered;
                  }

                  if (displayItems.isEmpty) return const SizedBox.shrink();

                  final shelfSongs = displayItems.whereType<SongItem>().toList();

                  // "Artistas para ti" con el carrusel 3D orbital tipo tornamesa
                  if (isArtistShelf) {
                    final shelfArtists = displayItems.whereType<ArtistItem>().toList();
                    if (shelfArtists.isNotEmpty) {
                      return BenchoArtistCarousel(
                        artists: shelfArtists,
                        onArtistClick: onArtistClick,
                        onSeeAllArtists: onSeeAllArtists,
                        appColors: appColors,
                        title: shelf.title,
                      );
                    }
                  }

                  // "Vuelve a escuchar" y "Recomendados para ti" con el carrusel 3D orbital tipo tornamesa
                  if (!isArtistShelf && shelfSongs.isNotEmpty) {
                    return BenchoCarousel(
                      songs: shelfSongs,
                      onPlaySong: onPlaySong,
                      appColors: appColors,
                      title: shelf.title,
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                shelf.title,
                                style: TextStyle(
                                  color: appColors.textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (isArtistShelf)
                              GestureDetector(
                                onTap: onSeeAllArtists,
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  child: Text(
                                    'Ver todo',
                                    style: TextStyle(
                                      color: Color(0xFF1DB954),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: 200,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: displayItems.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            final item = displayItems[index];
                            if (item is SongItem) {
                              return SongCard(
                                song: item,
                                appColors: appColors,
                                onClick: () => onPlaySong(item, shelfSongs),
                              );
                            } else if (item is AlbumItem) {
                              return AlbumCard(
                                album: item,
                                appColors: appColors,
                                onClick: () => onAlbumClick(item.browseId),
                              );
                            } else if (item is ArtistItem) {
                              return ArtistCard(
                                artist: item,
                                appColors: appColors,
                                onClick: () {
                                  if (item.id.isNotEmpty) onArtistClick(item.id);
                                },
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  );
                },
              ),
            ],
            if (isLoading)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Color(0xFF1DB954),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Cargando recomendaciones y artistas...',
                      style: TextStyle(
                        fontSize: 13,
                        color: appColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
          ] else ...[
            // Fallback
            if (recentlyPlayed.isNotEmpty) ...[
              BenchoCarousel(
                songs: recentlyPlayed.take(20).toList(),
                onPlaySong: onPlaySong,
                appColors: appColors,
                title: 'Vuelve a escuchar',
              ),
            ],
            if (recommendedArtists.isNotEmpty) ...[
              BenchoArtistCarousel(
                artists: recommendedArtists,
                onArtistClick: onArtistClick,
                onSeeAllArtists: onSeeAllArtists,
                appColors: appColors,
                title: 'Artistas para ti',
              ),
            ],
            if (homePage?.sections != null) ...[
              for (final section in homePage!.sections) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    section.title,
                    style: TextStyle(
                      color: appColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(
                  height: 200,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: section.items.length > 10 ? 10 : section.items.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final item = section.items[index];
                      final sectionSongs = section.items.whereType<SongItem>().take(10).toList();
                      if (item is SongItem) {
                        return SongCard(
                          song: item,
                          appColors: appColors,
                          onClick: () => onPlaySong(item, sectionSongs),
                        );
                      } else if (item is AlbumItem) {
                        return AlbumCard(
                          album: item,
                          appColors: appColors,
                          onClick: () => onAlbumClick(item.browseId),
                        );
                      } else if (item is ArtistItem) {
                        return ArtistCard(
                          artist: item,
                          appColors: appColors,
                          onClick: () {
                            if (item.id.isNotEmpty) onArtistClick(item.id);
                          },
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ],
            if (explorePage?.newReleaseAlbums != null && explorePage!.newReleaseAlbums.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'Nuevos Lanzamientos',
                  style: TextStyle(
                    color: appColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(
                height: 200,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: explorePage!.newReleaseAlbums.length > 10 ? 10 : explorePage!.newReleaseAlbums.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final album = explorePage!.newReleaseAlbums[index];
                    return AlbumCard(
                      album: album,
                      appColors: appColors,
                      onClick: () => onAlbumClick(album.browseId),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
          ],
        ],
      ),
    );
  }
}

class SongCard extends StatelessWidget {
  final SongItem song;
  final VoidCallback onClick;
  final AppColors appColors;

  const SongCard({
    super.key,
    required this.song,
    required this.onClick,
    required this.appColors,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onClick,
      child: SizedBox(
        width: 140,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 140,
                height: 140,
                color: Colors.grey.shade900,
                child: Builder(
                  builder: (_) {
                    final rawThumb = (song.thumbnail != null && song.thumbnail!.isNotEmpty)
                        ? song.thumbnail!
                        : (song.id.isNotEmpty ? 'https://i.ytimg.com/vi/${song.id}/hqdefault.jpg' : '');
                    if (rawThumb.isNotEmpty) {
                      return CachedNetworkImage(
                        imageUrl: rawThumb.resize(width: 320),
                        fit: BoxFit.cover,
                        fadeInDuration: Duration.zero,
                        errorWidget: (_, __, ___) => Icon(
                          Icons.music_note,
                          color: appColors.textSecondary,
                          size: 48,
                        ),
                      );
                    }
                    return Icon(
                      Icons.music_note,
                      color: appColors.textSecondary,
                      size: 48,
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: appColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              song.artists.map((a) => a.name).join(', '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: appColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ArtistCard extends StatelessWidget {
  final ArtistItem artist;
  final VoidCallback onClick;
  final AppColors appColors;

  const ArtistCard({
    super.key,
    required this.artist,
    required this.onClick,
    required this.appColors,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onClick,
      child: SizedBox(
        width: 120,
        child: Column(
          children: [
            ClipOval(
              child: Container(
                width: 120,
                height: 120,
                color: Colors.grey.shade900,
                child: artist.thumbnail != null && artist.thumbnail!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: artist.thumbnail!.resize(width: 240),
                        fit: BoxFit.cover,
                        fadeInDuration: Duration.zero,
                        errorWidget: (_, __, ___) => Icon(
                          Icons.person,
                          color: appColors.textSecondary,
                          size: 48,
                        ),
                      )
                    : Icon(
                        Icons.person,
                        color: appColors.textSecondary,
                        size: 48,
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              artist.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: appColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AlbumCard extends StatelessWidget {
  final AlbumItem album;
  final VoidCallback onClick;
  final AppColors appColors;

  const AlbumCard({
    super.key,
    required this.album,
    required this.onClick,
    required this.appColors,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onClick,
      child: SizedBox(
        width: 140,
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 140,
                height: 140,
                color: Colors.grey.shade900,
                child: album.thumbnail != null && album.thumbnail!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: album.thumbnail!.resize(width: 320),
                        fit: BoxFit.cover,
                        fadeInDuration: Duration.zero,
                        errorWidget: (_, __, ___) => Icon(
                          Icons.album,
                          color: appColors.textSecondary,
                          size: 48,
                        ),
                      )
                    : Icon(
                        Icons.album,
                        color: appColors.textSecondary,
                        size: 48,
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              album.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: appColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (album.artists != null && album.artists!.isNotEmpty)
              Text(
                album.artists!.first.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: appColors.textSecondary,
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
