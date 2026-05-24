import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../providers/hardware_provider.dart';
import '../../services/hardware/hardware_service.dart';

class HardwareScreen extends ConsumerWidget {
  const HardwareScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(hardwareStatusProvider);
    final current = ref.watch(hardwareServiceProvider).currentStatus;

    final status = statusAsync.valueOrNull ?? current;

    return Scaffold(
      backgroundColor: AppColors.warmCream,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _HardwareHeader()),
            SliverToBoxAdapter(
              child: _ConnectionBadge(isConnected: status.isConnected),
            ),
            SliverToBoxAdapter(
              child: _ChairIllustration(isConnected: status.isConnected),
            ),
            SliverToBoxAdapter(
              child: _StatusCards(status: status),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}

class _HardwareHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Hardware Status', style: AppTextStyles.headlineLarge),
              const SizedBox(height: 4),
              Text(
                'View the connection and performance\nof your IncreMat sensor.',
                style: AppTextStyles.bodySmall,
              ),
            ],
          ),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.cardSurface,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: AppColors.espresso.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Center(
              child: Text('?', style: TextStyle(color: AppColors.subtleText, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectionBadge extends StatelessWidget {
  final bool isConnected;
  const _ConnectionBadge({required this.isConnected});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.espresso.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: isConnected ? AppColors.sageGreen : AppColors.subtleText,
              shape: BoxShape.circle,
              boxShadow: isConnected
                  ? [
                      BoxShadow(
                        color: AppColors.sageGreen.withValues(alpha: 0.4),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Text('Status: ', style: AppTextStyles.titleMedium),
          Text(
            isConnected ? 'Connected' : 'Disconnected',
            style: AppTextStyles.titleMedium.copyWith(
              color: isConnected ? AppColors.sageGreen : AppColors.subtleText,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChairIllustration extends StatelessWidget {
  final bool isConnected;
  const _ChairIllustration({required this.isConnected});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      height: 280,
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Vase decoration (right side)
          Positioned(
            right: 24,
            bottom: 24,
            child: _Vase(),
          ),
          // Chair drawing
          _ChairDrawing(isConnected: isConnected),
        ],
      ),
    );
  }
}

class _ChairDrawing extends StatelessWidget {
  final bool isConnected;
  const _ChairDrawing({required this.isConnected});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(160, 220),
      painter: _ChairPainter(isConnected: isConnected),
    );
  }
}

class _ChairPainter extends CustomPainter {
  final bool isConnected;
  _ChairPainter({required this.isConnected});

  @override
  void paint(Canvas canvas, Size size) {
    final woodPaint = Paint()
      ..color = const Color(0xFFD4C8A8)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final matPaint = Paint()
      ..color = isConnected
          ? AppColors.sageGreen.withValues(alpha: 0.8)
          : AppColors.subtleText.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    // Back rest
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.15, 0, size.width * 0.7, size.height * 0.36),
        const Radius.circular(10),
      ),
      woodPaint,
    );

    // Seat
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.05, size.height * 0.4, size.width * 0.9, size.height * 0.12),
        const Radius.circular(6),
      ),
      woodPaint,
    );

    // Mat on seat
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.12,
          size.height * 0.41,
          size.width * 0.76,
          size.height * 0.10,
        ),
        const Radius.circular(4),
      ),
      matPaint,
    );

    // Mat indicator dot
    final dotPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.46),
      3,
      dotPaint,
    );

    // Left front leg
    canvas.drawLine(
      Offset(size.width * 0.15, size.height * 0.52),
      Offset(size.width * 0.12, size.height * 0.88),
      woodPaint,
    );
    // Right front leg
    canvas.drawLine(
      Offset(size.width * 0.85, size.height * 0.52),
      Offset(size.width * 0.88, size.height * 0.88),
      woodPaint,
    );
    // Left back leg
    canvas.drawLine(
      Offset(size.width * 0.22, size.height * 0.52),
      Offset(size.width * 0.20, size.height * 0.88),
      woodPaint,
    );
    // Right back leg
    canvas.drawLine(
      Offset(size.width * 0.78, size.height * 0.52),
      Offset(size.width * 0.80, size.height * 0.88),
      woodPaint,
    );

    // Arm rests
    canvas.drawLine(
      Offset(size.width * 0.15, size.height * 0.36),
      Offset(size.width * 0.15, size.height * 0.52),
      woodPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.85, size.height * 0.36),
      Offset(size.width * 0.85, size.height * 0.52),
      woodPaint,
    );
  }

  @override
  bool shouldRepaint(_ChairPainter old) => old.isConnected != isConnected;
}

class _Vase extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.eco_outlined, size: 32, color: AppColors.lightSage),
        Container(
          width: 20,
          height: 30,
          decoration: BoxDecoration(
            color: AppColors.lightSage.withValues(alpha: 0.6),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(4),
              bottom: Radius.circular(10),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusCards extends StatelessWidget {
  final HardwareStatus status;
  const _StatusCards({required this.status});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: _InfoCard(
              icon: Icons.battery_charging_full_outlined,
              label: 'Battery: ${status.batteryPercent}%',
              iconColor: _batteryColor(status.batteryPercent),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _InfoCard(
              icon: Icons.signal_cellular_alt_outlined,
              label: 'Signal: ${status.signalLabel}',
              iconColor: AppColors.sageGreen,
            ),
          ),
        ],
      ),
    );
  }

  Color _batteryColor(int pct) {
    if (pct > 50) return AppColors.sageGreen;
    if (pct > 20) return AppColors.terracotta;
    return Colors.red;
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconColor;

  const _InfoCard({
    required this.icon,
    required this.label,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.espresso.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, style: AppTextStyles.titleMedium.copyWith(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
