import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class DownloadQualityBottomSheet extends StatefulWidget {
  final String title;
  final String artist;
  final ValueChanged<String> onConfirm;
  final AppColors appColors;

  const DownloadQualityBottomSheet({
    super.key,
    required this.title,
    required this.artist,
    required this.onConfirm,
    required this.appColors,
  });

  static Future<void> show({
    required BuildContext context,
    required String title,
    required String artist,
    required ValueChanged<String> onConfirm,
    required AppColors appColors,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: appColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DownloadQualityBottomSheet(
        title: title,
        artist: artist,
        onConfirm: onConfirm,
        appColors: appColors,
      ),
    );
  }

  @override
  State<DownloadQualityBottomSheet> createState() => _DownloadQualityBottomSheetState();
}

class _DownloadQualityBottomSheetState extends State<DownloadQualityBottomSheet> {
  String _selectedQuality = '320kbps';

  final List<Map<String, String>> qualities = [
    {'id': '320kbps', 'title': 'Alta Calidad (320 kbps)', 'desc': 'Máxima fidelidad de audio comprimido'},
    {'id': '160kbps', 'title': 'Calidad Media (160 kbps)', 'desc': 'Equilibrio entre espacio y sonido'},
    {'id': '128kbps', 'title': 'Estándar (128 kbps)', 'desc': 'Descarga rápida y menor consumo'},
    {'id': 'lossless', 'title': 'FLAC Lossless', 'desc': 'Audio sin pérdidas de estudio'},
  ];

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
            'Calidad de Descarga',
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${widget.artist} - ${widget.title}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: colors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          ...qualities.map((q) {
            final isSelected = _selectedQuality == q['id'];
            return InkWell(
              onTap: () => setState(() => _selectedQuality = q['id']!),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                child: Row(
                  children: [
                    Radio<String>(
                      value: q['id']!,
                      groupValue: _selectedQuality,
                      activeColor: colors.accent,
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedQuality = val);
                      },
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            q['title']!,
                            style: TextStyle(
                              color: isSelected ? colors.accent : colors.textPrimary,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            q['desc']!,
                            style: TextStyle(color: colors.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
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
                'Iniciar Descarga',
                style: TextStyle(
                  color: AppColors.textColorForBackground(colors.accent),
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
