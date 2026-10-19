import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class AlbumDownloadQualityBottomSheet extends StatefulWidget {
  final String albumTitle;
  final String artist;
  final int songCount;
  final ValueChanged<String> onConfirm;
  final AppColors appColors;

  const AlbumDownloadQualityBottomSheet({
    super.key,
    required this.albumTitle,
    required this.artist,
    required this.songCount,
    required this.onConfirm,
    required this.appColors,
  });

  static Future<void> show({
    required BuildContext context,
    required String albumTitle,
    required String artist,
    required int songCount,
    required ValueChanged<String> onConfirm,
    required AppColors appColors,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: appColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => AlbumDownloadQualityBottomSheet(
        albumTitle: albumTitle,
        artist: artist,
        songCount: songCount,
        onConfirm: onConfirm,
        appColors: appColors,
      ),
    );
  }

  @override
  State<AlbumDownloadQualityBottomSheet> createState() => _AlbumDownloadQualityBottomSheetState();
}

class _AlbumDownloadQualityBottomSheetState extends State<AlbumDownloadQualityBottomSheet> {
  String _selectedQuality = '320kbps';

  @override
  Widget build(BuildContext context) {
    final colors = widget.appColors;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Descargar Álbum Completo',
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${widget.artist} - ${widget.albumTitle} (${widget.songCount} canciones)',
            style: TextStyle(color: colors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          ListTile(
            title: Text('Alta Calidad (320 kbps)', style: TextStyle(color: colors.textPrimary)),
            leading: Radio<String>(
              value: '320kbps',
              groupValue: _selectedQuality,
              activeColor: colors.accent,
              onChanged: (v) => setState(() => _selectedQuality = v!),
            ),
            onTap: () => setState(() => _selectedQuality = '320kbps'),
          ),
          ListTile(
            title: Text('Calidad Media (160 kbps)', style: TextStyle(color: colors.textPrimary)),
            leading: Radio<String>(
              value: '160kbps',
              groupValue: _selectedQuality,
              activeColor: colors.accent,
              onChanged: (v) => setState(() => _selectedQuality = v!),
            ),
            onTap: () => setState(() => _selectedQuality = '160kbps'),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colors.accent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.pop(context);
                widget.onConfirm(_selectedQuality);
              },
              child: Text(
                'Descargar Álbum',
                style: TextStyle(
                  color: AppColors.textColorForBackground(colors.accent),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
