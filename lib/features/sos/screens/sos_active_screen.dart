import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/beacon_ring.dart';

/// SOS Active screen — shown after SOS is triggered.
/// Shows alert status checklist and emergency actions.
/// Matches the JSX SOSActive component.
class SosActiveScreen extends StatelessWidget {
  final VoidCallback onResolve;

  const SosActiveScreen({super.key, required this.onResolve});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFCE7E7), AppColors.bg],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 40),

              // — Coral beacon —
              const BeaconRing(size: 92, color: AppColors.coral),
              const SizedBox(height: 14),

              // — Alert sent header —
              Text(
                'Alert sent',
                style: AppTextStyles.display(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Live for 02:14',
                style: AppTextStyles.mono(
                  fontSize: 11,
                  color: AppColors.coral,
                ),
              ),
              const SizedBox(height: 24),

              // — Status checklist —
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: const [
                      _StatusRow(label: 'Pod notified', done: true),
                      _StatusRow(
                          label: 'Emergency contacts notified', done: true),
                      _StatusRow(
                          label: 'Live location sharing', done: true),
                      _StatusRow(
                          label: 'Control room (112) pinged', done: false),
                    ],
                  ),
                ),
              ),

              const Spacer(),

              // — Action buttons —
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.phone_in_talk_rounded, size: 15),
                        label: Text(
                          'Call 112 now',
                          style: AppTextStyles.body(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.bgDeep,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.coral,
                          foregroundColor: AppColors.bgDeep,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: onResolve,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        child: Text(
                          "I'm safe — cancel alert",
                          style: AppTextStyles.body(
                            fontSize: 13.5,
                            color: AppColors.muted,
                          ),
                        ),
                      ),
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

class _StatusRow extends StatelessWidget {
  final String label;
  final bool done;

  const _StatusRow({required this.label, required this.done});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTextStyles.body(
              fontSize: 12.5,
              color: AppColors.text,
            ),
          ),
          if (done)
            const Icon(Icons.check_rounded, size: 15, color: AppColors.green)
          else
            Text(
              'pending',
              style: AppTextStyles.mono(
                fontSize: 10,
                color: AppColors.faint,
              ),
            ),
        ],
      ),
    );
  }
}
