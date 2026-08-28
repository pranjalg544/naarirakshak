import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Floating SOS button with pulsing coral ring — always visible on main screens.
class FloatingSosButton extends StatefulWidget {
  final VoidCallback onPressed;

  const FloatingSosButton({super.key, required this.onPressed});

  @override
  State<FloatingSosButton> createState() => _FloatingSosButtonState();
}

class _FloatingSosButtonState extends State<FloatingSosButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    _scaleAnimation = Tween<double>(
      begin: 0.75,
      end: 1.9,
    ).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeOut));
    _opacityAnimation = Tween<double>(
      begin: 0.55,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 66,
      height: 66,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Pulsing ring
          AnimatedBuilder(
            animation: _pulseController,
            builder: (_, _) => Transform.scale(
              scale: _scaleAnimation.value,
              child: Opacity(
                opacity: _opacityAnimation.value,
                child: Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.coral, width: 1.5),
                  ),
                ),
              ),
            ),
          ),
          // Button
          GestureDetector(
            onTap: widget.onPressed,
            child: Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.coral,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.coral.withValues(alpha: 0.4),
                    blurRadius: 18,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.warning_rounded,
                color: AppColors.bgDeep,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
