import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/beacon_ring.dart';

/// Onboarding screen — first screen seen by the user.
/// Matches the JSX Onboarding component: beacon, title, tagline, feature icons, CTA.
class OnboardingScreen extends StatelessWidget {
  final VoidCallback onGetStarted;

  const OnboardingScreen({super.key, required this.onGetStarted});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.2,
            colors: [AppColors.surface2, AppColors.bg],
            stops: const [0.0, 0.7],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                const Spacer(flex: 2),

                // — Beacon ring animation —
                const BeaconRing(size: 104, color: AppColors.amber),
                const SizedBox(height: 20),

                // — Title —
                Text(
                  'NaariRakshak',
                  style: AppTextStyles.display(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 6),

                // — Tagline —
                Text(
                  'Never alone. Never silent.\nNever undetected.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.display(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.amber,
                    fontStyle: FontStyle.italic,
                  ),
                ),

                const Spacer(flex: 3),

                // — Three feature icons —
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _FeatureIcon(icon: Icons.people_rounded, label: 'Pods'),
                    const SizedBox(width: 40),
                    _FeatureIcon(
                      icon: Icons.cell_tower_rounded,
                      label: 'Silent SOS',
                    ),
                    const SizedBox(width: 40),
                    _FeatureIcon(icon: Icons.mic_rounded, label: 'AI Detect'),
                  ],
                ),
                const SizedBox(height: 28),

                // — Get started CTA —
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onGetStarted,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.amber,
                      foregroundColor: AppColors.bgDeep,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      elevation: 0,
                    ),
                    child: Text(
                      'Get started',
                      style: AppTextStyles.body(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.bgDeep,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // — Subtitle —
                Text(
                  'Three layers of protection for every commute.',
                  style: AppTextStyles.body(
                    fontSize: 11,
                    color: AppColors.faint,
                  ),
                  textAlign: TextAlign.center,
                ),

                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureIcon extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeatureIcon({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: AppColors.amber),
        const SizedBox(height: 6),
        Text(
          label,
          style: AppTextStyles.body(fontSize: 10, color: AppColors.muted),
        ),
      ],
    );
  }
}
