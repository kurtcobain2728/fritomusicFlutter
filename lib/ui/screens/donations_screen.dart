import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';

class DonationsScreen extends StatelessWidget {
  final VoidCallback onBack;
  final AppColors appColors;

  const DonationsScreen({
    super.key,
    required this.onBack,
    required this.appColors,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: appColors.isDark ? const Color(0x33FFFFFF) : const Color(0x10000000),
              shape: BoxShape.circle,
              border: Border.all(
                color: appColors.isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
              ),
            ),
            child: Icon(Icons.arrow_back_ios_new_rounded, color: appColors.textPrimary, size: 16),
          ),
          onPressed: () {
            HapticFeedback.lightImpact();
            onBack();
          },
        ),
        title: Text(
          'Donaciones',
          style: TextStyle(
            color: appColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 20,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          // Hero Support Header Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: appColors.isDark ? const Color(0x6618181C) : const Color(0xC8F6F6F8),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: appColors.isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF4757).withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.favorite_rounded, color: Color(0xFFFF4757), size: 34),
                ),
                const SizedBox(height: 16),
                Text(
                  '¡Apoya Frito Music!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: appColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Este proyecto es libre y de código abierto. Si disfrutas de la app y deseas apoyar el desarrollo continuo, cualquier aporte ayuda enormemente.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: appColors.textSecondary,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Binance Card
          _buildDonationCard(
            context: context,
            title: 'Binance (USDT)',
            minAmount: 'Mínimo: \$0.01 USD',
            networkBadge: 'BEP20 (BSC)',
            description: 'Envía USDT a través de la red Binance Smart Chain (BEP20). Asegúrate de seleccionar la red BEP20 al transferir.',
            address: '0x71C...BinanceBEP20Address',
            icon: Icons.currency_bitcoin_rounded,
            iconColor: const Color(0xFFF3BA2F),
          ),

          const SizedBox(height: 12),

          // Bitget Pay Card
          _buildDonationCard(
            context: context,
            title: 'Bitget Pay',
            minAmount: 'Mínimo: \$0.01 USD',
            networkBadge: 'ID Directo',
            description: 'Transfiere sin comisiones buscando nuestro ID de usuario directamente dentro de la aplicación de Bitget.',
            address: 'BitgetID_10829381',
            icon: Icons.account_balance_wallet_rounded,
            iconColor: const Color(0xFF00F0FF),
          ),

          const SizedBox(height: 12),

          // PayPal Card
          _buildDonationCard(
            context: context,
            title: 'PayPal',
            minAmount: 'Próximamente',
            networkBadge: 'En desarrollo',
            description: 'La opción de PayPal estará disponible en una próxima actualización. ¡Gracias por tu paciencia!',
            address: null,
            icon: Icons.credit_card_rounded,
            iconColor: const Color(0xFF0079C1),
          ),

          const SizedBox(height: 24),
          Text(
            '¡Gracias de corazón por tu apoyo! ❤️',
            textAlign: TextAlign.center,
            style: TextStyle(color: appColors.textSecondary.withOpacity(0.8), fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildDonationCard({
    required BuildContext context,
    required String title,
    required String minAmount,
    required String networkBadge,
    required String description,
    required String? address,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: appColors.isDark ? const Color(0x6618181C) : const Color(0xC8F6F6F8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: appColors.isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: appColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      minAmount,
                      style: const TextStyle(color: Color(0xFF1DB954), fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: appColors.isDark ? const Color(0x33FFFFFF) : const Color(0x0F000000),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  networkBadge,
                  style: TextStyle(
                    color: appColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: TextStyle(color: appColors.textSecondary, fontSize: 13, height: 1.4),
          ),
          if (address != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: appColors.isDark ? const Color(0x33FFFFFF) : const Color(0x0F000000),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: appColors.textPrimary,
                        fontSize: 12,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Clipboard.setData(ClipboardData(text: address));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Dirección copiada al portapapeles'),
                        backgroundColor: Color(0xFF1DB954),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1DB954),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1DB954).withOpacity(0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.copy_rounded, color: Colors.white, size: 16),
                        SizedBox(width: 6),
                        Text('Copiar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
