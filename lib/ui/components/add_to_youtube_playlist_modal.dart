import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../data/network/innertube/innertube_models.dart';

class AddToYouTubePlaylistModal extends StatelessWidget {
  final List<PlaylistItem> playlists;
  final ValueChanged<PlaylistItem> onSelectPlaylist;
  final VoidCallback onCreateNew;
  final AppColors appColors;

  const AddToYouTubePlaylistModal({
    super.key,
    required this.playlists,
    required this.onSelectPlaylist,
    required this.onCreateNew,
    required this.appColors,
  });

  static Future<void> show({
    required BuildContext context,
    required List<PlaylistItem> playlists,
    required ValueChanged<PlaylistItem> onSelectPlaylist,
    required VoidCallback onCreateNew,
    required AppColors appColors,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: appColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => AddToYouTubePlaylistModal(
        playlists: playlists,
        onSelectPlaylist: onSelectPlaylist,
        onCreateNew: onCreateNew,
        appColors: appColors,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Añadir a lista de reproducción',
                style: TextStyle(
                  color: appColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: Icon(Icons.add, color: appColors.accent),
                onPressed: () {
                  Navigator.pop(context);
                  onCreateNew();
                },
                tooltip: 'Nueva lista',
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (playlists.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'No tienes listas disponibles',
                  style: TextStyle(color: appColors.textSecondary),
                ),
              ),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: playlists.length,
                itemBuilder: (context, index) {
                  final p = playlists[index];
                  return ListTile(
                    leading: Icon(Icons.playlist_play, color: appColors.accent),
                    title: Text(p.title, style: TextStyle(color: appColors.textPrimary)),
                    subtitle: p.songCountText != null
                        ? Text(p.songCountText!, style: TextStyle(color: appColors.textSecondary, fontSize: 12))
                        : null,
                    onTap: () {
                      Navigator.pop(context);
                      onSelectPlaylist(p);
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
