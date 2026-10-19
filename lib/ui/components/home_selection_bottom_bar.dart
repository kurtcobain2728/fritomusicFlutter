import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class HomeSelectionBottomBar extends StatelessWidget {
  final int selectedCount;
  final VoidCallback onCancel;
  final VoidCallback onHideSelected;
  final VoidCallback onDeleteSelected;
  final AppColors appColors;

  const HomeSelectionBottomBar({
    super.key,
    required this.selectedCount,
    required this.onCancel,
    required this.onHideSelected,
    required this.onDeleteSelected,
    required this.appColors,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      bottom: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: appColors.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
          border: Border(
            top: BorderSide(
              color: appColors.textSecondary.withOpacity(0.12),
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.close, color: appColors.textPrimary, size: 22),
              onPressed: onCancel,
              tooltip: 'Cancelar',
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              padding: EdgeInsets.zero,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                '$selectedCount sel.',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: appColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              icon: Icon(Icons.visibility_off_outlined, color: appColors.textPrimary, size: 18),
              label: Text('Ocultar', style: TextStyle(color: appColors.textPrimary, fontSize: 13)),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: onHideSelected,
            ),
            const SizedBox(width: 6),
            TextButton.icon(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
              label: const Text('Eliminar', style: TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w600)),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: onDeleteSelected,
            ),
          ],
        ),
      ),
    );
  }
}
