import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Full-screen countdown overlay shown when distress audio is detected.
///
/// Gives the user 5 seconds to cancel before auto-triggering the SOS pipeline.
class AutoSosOverlay extends StatefulWidget {
  /// Detection confidence that triggered this overlay (0.0–1.0).
  final double confidence;

  /// Called when the user cancels ("I'm safe").
  final VoidCallback onCancel;

  /// Called when the countdown reaches zero.
  final VoidCallback onTriggered;

  const AutoSosOverlay({
    super.key,
    required this.confidence,
    required this.onCancel,
    required this.onTriggered,
  });

  @override
  State<AutoSosOverlay> createState() => _AutoSosOverlayState();
}

class _AutoSosOverlayState extends State<AutoSosOverlay>
    with TickerProviderStateMixin {
  int _countdown = 5;
  Timer? _timer;
  late final AnimationController _pulseCtrl;
  late final AnimationController _glowCtrl;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _countdown--);
      if (_countdown <= 0) {
        _timer?.cancel();
        widget.onTriggered();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2A0A0A), Color(0xFF1A0505)],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),

            // ── Pulsing warning icon ──────────────────────────────────
            AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (_, child) => Transform.scale(
                scale: 1.0 + _pulseCtrl.value * 0.15,
                child: Opacity(
                  opacity: 0.7 + _pulseCtrl.value * 0.3,
                  child: child,
                ),
              ),
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.coral.withValues(alpha: 0.15),
                  border: Border.all(color: AppColors.coral, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.coral.withValues(alpha: 0.25),
                      blurRadius: 32,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  size: 40,
                  color: AppColors.coral,
                ),
              ),
            ),

            const SizedBox(height: 28),

            // ── Title ─────────────────────────────────────────────────
            Text(
              'DISTRESS DETECTED',
              style: AppTextStyles.mono(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.coral,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Confidence: ${(widget.confidence * 100).toStringAsFixed(0)}%',
              style: AppTextStyles.mono(
                fontSize: 11,
                color: const Color(0xFF999999),
              ),
            ),

            const SizedBox(height: 42),

            // ── Big countdown number ──────────────────────────────────
            AnimatedBuilder(
              animation: _glowCtrl,
              builder: (_, _) => Text(
                '$_countdown',
                style: AppTextStyles.display(
                  fontSize: 80,
                  fontWeight: FontWeight.w700,
                  color: Color.lerp(
                    AppColors.coral,
                    const Color(0xFFFF8888),
                    _glowCtrl.value,
                  )!,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'SOS triggers in $_countdown second${_countdown == 1 ? '' : 's'}',
              style: AppTextStyles.body(
                fontSize: 13,
                color: const Color(0xFFAAAAAA),
              ),
            ),

            const Spacer(flex: 2),

            // ── Progress bar ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _countdown / 5,
                  minHeight: 4,
                  backgroundColor: const Color(0xFF333333),
                  color: AppColors.coral,
                ),
              ),
            ),

            const SizedBox(height: 32),

            // ── Cancel button ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: widget.onCancel,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: Text(
                    "Cancel — I'm safe",
                    style: AppTextStyles.body(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0x44FFFFFF)),
                    shape: const StadiumBorder(),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 18),

            Text(
              'Audio processed on-device only',
              style: AppTextStyles.mono(
                fontSize: 9,
                color: const Color(0xFF666666),
              ),
            ),

            const Spacer(),
          ],
        ),
      ),
    );
  }
}
