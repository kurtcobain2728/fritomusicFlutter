import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../data/repository/youtube_login_manager.dart';
import '../screens/youtube_login_screen.dart';

class YouTubeLogoutModal extends StatefulWidget {
  final String? accountName;
  final String? accountEmail;
  final String? accountAvatar;
  final VoidCallback? onConfirmLogout;
  final VoidCallback? onLogout;
  final VoidCallback? onDismiss;
  final VoidCallback? onAccountsChanged;
  final AppColors appColors;

  const YouTubeLogoutModal({
    super.key,
    this.accountName,
    this.accountEmail,
    this.accountAvatar,
    this.onConfirmLogout,
    this.onLogout,
    this.onDismiss,
    this.onAccountsChanged,
    required this.appColors,
  });

  static Future<void> show({
    required BuildContext context,
    String? accountName,
    String? accountEmail,
    String? accountAvatar,
    VoidCallback? onConfirmLogout,
    VoidCallback? onAccountsChanged,
    required AppColors appColors,
  }) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (modalContext) => YouTubeLogoutModal(
        accountName: accountName,
        accountEmail: accountEmail,
        accountAvatar: accountAvatar,
        onConfirmLogout: onConfirmLogout,
        onAccountsChanged: onAccountsChanged,
        appColors: appColors,
      ),
    );
  }

  @override
  State<YouTubeLogoutModal> createState() => _YouTubeLogoutModalState();
}

class _YouTubeLogoutModalState extends State<YouTubeLogoutModal> {
  void _openYouTubeLogin(BuildContext context, AppColors colors) {
    Navigator.of(context).pop();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => YouTubeLoginScreen(
          appColors: colors,
          onBack: () => Navigator.pop(context),
          onLoginSuccess: () {
            Navigator.pop(context);
            widget.onAccountsChanged?.call();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.appColors;
    final ytMgr = YouTubeLoginManager.instance;
    final isYtLoggedIn = ytMgr.isLoggedIn;

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).padding.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: colors.isDark ? const Color(0xFF1E1E24) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(
            color: colors.isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.08),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 30,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 38,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Título del Modal
          Text(
            'Cuenta de YouTube',
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Gestiona tu sesión de YouTube en FritoMusic',
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 13,
            ),
          ),

          const SizedBox(height: 20),

          // --- TARJETA YOUTUBE MUSIC ---
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.isDark ? const Color(0x66141418) : const Color(0xC8F6F6F8),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isYtLoggedIn
                    ? const Color(0xFFFF0000).withOpacity(0.3)
                    : (colors.isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04)),
              ),
            ),
            child: Row(
              children: [
                // Avatar o Icono YT
                ClipOval(
                  child: Container(
                    width: 46,
                    height: 46,
                    color: const Color(0xFFFF0000).withOpacity(0.12),
                    child: isYtLoggedIn && ytMgr.accountAvatar.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: ytMgr.accountAvatar,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => const Icon(
                              Icons.play_circle_fill_rounded,
                              color: Color(0xFFFF0000),
                              size: 26,
                            ),
                          )
                        : const Icon(
                            Icons.play_circle_fill_rounded,
                            color: Color(0xFFFF0000),
                            size: 26,
                          ),
                  ),
                ),
                const SizedBox(width: 14),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'YT',
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (isYtLoggedIn)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircleAvatar(radius: 3, backgroundColor: Color(0xFF10B981)),
                                  SizedBox(width: 4),
                                  Text(
                                    'YT Iniciado',
                                    style: TextStyle(
                                      color: Color(0xFF10B981),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isYtLoggedIn
                            ? (ytMgr.accountName.isNotEmpty ? ytMgr.accountName : 'Cuenta Conectada')
                            : 'No conectado',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Botón Acción
                if (isYtLoggedIn)
                  IconButton(
                    icon: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 20),
                    tooltip: 'Cerrar sesión de YT',
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      ytMgr.logout();
                      widget.onConfirmLogout?.call();
                      widget.onLogout?.call();
                      widget.onAccountsChanged?.call();
                      setState(() {});
                    },
                  )
                else
                  GestureDetector(
                    onTap: () => _openYouTubeLogin(context, colors),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF0000).withOpacity(0.14),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFFF0000).withOpacity(0.4)),
                      ),
                      child: const Text(
                        'Iniciar con YT',
                        style: TextStyle(
                          color: Color(0xFFFF0000),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),



          const SizedBox(height: 20),

          // Botón Cerrar (Glass translúcido)
          SizedBox(
            width: double.infinity,
            height: 48,
            child: TextButton(
              style: TextButton.styleFrom(
                foregroundColor: colors.textPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                backgroundColor: colors.isDark
                    ? Colors.white.withOpacity(0.06)
                    : Colors.black.withOpacity(0.04),
              ),
              onPressed: () {
                HapticFeedback.lightImpact();
                if (widget.onDismiss != null) widget.onDismiss!();
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
              },
              child: Text(
                'Cerrar',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
