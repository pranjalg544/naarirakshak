import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

import 'dart:math' as math;

/// Silent SOS trigger screen — hold-to-activate circular progress button.
/// Matches the JSX SOSTrigger component.
class SosTriggerScreen extends StatefulWidget {
  final VoidCallback onActivate;
  final VoidCallback onDecoy;
  final VoidCallback onCancel;

  const SosTriggerScreen({
    super.key,
    required this.onActivate,
    required this.onDecoy,
    required this.onCancel,
  });

  @override
  State<SosTriggerScreen> createState() => _SosTriggerScreenState();
}

class _SosTriggerScreenState extends State<SosTriggerScreen> {
  double _progress = 0.0;
  Timer? _timer;
  static const _holdMs = 1400;

  void _startHold() {
    final startTime = DateTime.now().millisecondsSinceEpoch;
    _timer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      final elapsed = DateTime.now().millisecondsSinceEpoch - startTime;
      final p = (elapsed / _holdMs).clamp(0.0, 1.0);
      setState(() => _progress = p);
      if (p >= 1.0) {
        _timer?.cancel();
        widget.onActivate();
      }
    });
  }

  void _stopHold() {
    _timer?.cancel();
    setState(() => _progress = 0.0);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // — Top bar —
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: widget.onCancel,
                    child: const Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: AppColors.muted,
                    ),
                  ),
                  Text(
                    'Silent SOS',
                    style: AppTextStyles.body(
                      fontSize: 12,
                      color: AppColors.faint,
                    ),
                  ),
                  const SizedBox(width: 22),
                ],
              ),
            ),

            // — Central button —
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 190,
                      height: 190,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Progress ring
                          CustomPaint(
                            size: const Size(190, 190),
                            painter: _ProgressRingPainter(
                              progress: _progress,
                              bgColor: AppColors.surface2,
                              fgColor: AppColors.coral,
                            ),
                          ),
                          // Hold button
                          GestureDetector(
                            onLongPressStart: (_) => _startHold(),
                            onLongPressEnd: (_) => _stopHold(),
                            onTapDown: (_) => _startHold(),
                            onTapUp: (_) => _stopHold(),
                            onTapCancel: _stopHold,
                            child: Container(
                              width: 132,
                              height: 132,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.coral,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.coral.withValues(
                                      alpha: 0.33,
                                    ),
                                    blurRadius: 30,
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.warning_rounded,
                                size: 34,
                                color: AppColors.bgDeep,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'Press and hold for 3 seconds',
                      style: AppTextStyles.body(
                        fontSize: 13,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Shares live location, audio and alerts your\npod, contacts and control room',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body(
                        fontSize: 11,
                        color: AppColors.faint,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // — Other triggers —
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'OTHER TRIGGERS',
                    style: AppTextStyles.body(
                      fontSize: 10.5,
                      color: AppColors.faint,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _TriggerOption(label: 'Power button pattern', onTap: () {}),
                  _TriggerOption(label: 'Shake gesture', onTap: () {}),
                  _TriggerOption(
                    label: 'Preview decoy screen',
                    onTap: widget.onDecoy,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter for the circular progress ring.
class _ProgressRingPainter extends CustomPainter {
  final double progress;
  final Color bgColor;
  final Color fgColor;

  _ProgressRingPainter({
    required this.progress,
    required this.bgColor,
    required this.fgColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const radius = 86.0;
    const strokeWidth = 6.0;

    // Background ring
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = bgColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    // Progress arc
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        Paint()
          ..color = fgColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_ProgressRingPainter old) => old.progress != progress;
}

class _TriggerOption extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _TriggerOption({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border, width: 1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: AppTextStyles.body(fontSize: 12.5, color: AppColors.muted),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 14,
              color: AppColors.faint,
            ),
          ],
        ),
      ),
    );
  }
}
