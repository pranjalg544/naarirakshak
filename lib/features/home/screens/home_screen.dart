import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Home / Commute Dashboard — matches the JSX HomeScreen component.
class HomeScreen extends StatelessWidget {
  final VoidCallback onStartCommute;

  const HomeScreen({super.key, required this.onStartCommute});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // — Greeting —
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Good evening,',
                      style: AppTextStyles.body(
                        fontSize: 12.5,
                        color: AppColors.faint,
                      ),
                    ),
                    Text(
                      'Aditi',
                      style: AppTextStyles.display(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              // — Route card —
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.surface2, AppColors.surface],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Ready for your commute',
                            style: AppTextStyles.body(
                              fontSize: 12.5,
                              color: AppColors.muted,
                            ),
                          ),
                          const Icon(Icons.verified_user_rounded,
                              size: 16, color: AppColors.amber),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Icon(Icons.location_on_rounded,
                              size: 13, color: AppColors.amber),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Kalkaji → Cyber Hub, Gurugram',
                              style: AppTextStyles.body(
                                fontSize: 13.5,
                                color: AppColors.text,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.access_time_rounded,
                              size: 12, color: AppColors.faint),
                          const SizedBox(width: 8),
                          Text(
                            'Est. 38 min · Auto + Metro',
                            style: AppTextStyles.mono(
                              fontSize: 11.5,
                              color: AppColors.faint,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: onStartCommute,
                          icon: const Icon(Icons.navigation_rounded, size: 14),
                          label: Text(
                            'Start commute',
                            style: AppTextStyles.body(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.bgDeep,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.amber,
                            foregroundColor: AppColors.bgDeep,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // — Stats row —
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _StatLine(value: '47', label: 'safe arrivals'),
                    _StatLine(value: '312 km', label: 'protected this month'),
                    _StatLine(value: '6', label: 'pod companions'),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // — Three layers chips —
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'YOUR THREE LAYERS',
                      style: AppTextStyles.body(
                        fontSize: 11.5,
                        color: AppColors.faint,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: const [
                        _LayerChip(
                          label: 'Pod matching',
                          icon: Icons.people_rounded,
                          active: true,
                        ),
                        _LayerChip(
                          label: 'Silent SOS armed',
                          icon: Icons.cell_tower_rounded,
                          active: true,
                        ),
                        _LayerChip(
                          label: 'Audio detection',
                          icon: Icons.mic_rounded,
                          active: true,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatLine extends StatelessWidget {
  final String value;
  final String label;

  const _StatLine({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: AppTextStyles.mono(
            fontSize: 19,
            fontWeight: FontWeight.w500,
            color: AppColors.text,
          ),
        ),
        Text(
          label,
          style: AppTextStyles.body(fontSize: 10.5, color: AppColors.faint),
        ),
      ],
    );
  }
}

class _LayerChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;

  const _LayerChip({
    required this.label,
    required this.icon,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: active ? AppColors.amber.withValues(alpha: 0.1) : AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: active ? AppColors.amber : AppColors.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: active ? AppColors.amber : AppColors.faint,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.body(
              fontSize: 10.5,
              color: active ? AppColors.amber : AppColors.faint,
            ),
          ),
        ],
      ),
    );
  }
}
