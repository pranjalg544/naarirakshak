import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Animated pulsing beacon — concentric rings that scale up and fade out.
/// Mirrors the JSX `BeaconRing` component exactly.
class BeaconRing extends StatefulWidget {
  final double size;
  final Color color;
  final int ringCount;
  final bool active;

  const BeaconRing({
    super.key,
    this.size = 90,
    this.color = AppColors.amber,
    this.ringCount = 3,
    this.active = true,
  });

  @override
  State<BeaconRing> createState() => _BeaconRingState();
}

class _BeaconRingState extends State<BeaconRing> with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _scaleAnimations;
  late List<Animation<double>> _opacityAnimations;

  @override
  void initState() {
    super.initState();
    _initAnimations();
  }

  void _initAnimations() {
    const duration = Duration(milliseconds: 2600);
    _controllers = List.generate(widget.ringCount, (i) {
      final controller = AnimationController(vsync: this, duration: duration);
      if (widget.active) {
        controller.repeat();
      }
      return controller;
    });

    _scaleAnimations = _controllers.map((c) {
      return Tween<double>(
        begin: 0.75,
        end: 1.9,
      ).animate(CurvedAnimation(parent: c, curve: Curves.easeOut));
    }).toList();

    _opacityAnimations = _controllers.map((c) {
      return Tween<double>(
        begin: 0.55,
        end: 0.0,
      ).animate(CurvedAnimation(parent: c, curve: Curves.easeOut));
    }).toList();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Pulsing rings
          if (widget.active)
            ...List.generate(widget.ringCount, (i) {
              return AnimatedBuilder(
                animation: _controllers[i],
                builder: (_, _) {
                  return Transform.scale(
                    scale: _scaleAnimations[i].value,
                    child: Opacity(
                      opacity: _opacityAnimations[i].value,
                      child: Container(
                        width: widget.size,
                        height: widget.size,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: widget.color, width: 1.5),
                        ),
                      ),
                    ),
                  );
                },
              );
            }),
          // Center dot
          Container(
            width: widget.size * 0.36,
            height: widget.size * 0.36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color,
              boxShadow: [
                BoxShadow(
                  color: widget.color.withValues(alpha: 0.6),
                  blurRadius: 16,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
