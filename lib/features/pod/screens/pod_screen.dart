import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/beacon_ring.dart';

/// Pod screen — shows current safety pod status, members, and check-in button.
/// Matches the JSX PodScreen component.
class PodScreen extends StatelessWidget {
  final VoidCallback onReachedSafely;

  const PodScreen({super.key, required this.onReachedSafely});

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
              // — Header —
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your safety pod',
                      style: AppTextStyles.display(
                        fontSize: 19,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Matched by route · 4 of 5 checked in',
                      style: AppTextStyles.body(
                        fontSize: 12,
                        color: AppColors.faint,
                      ),
                    ),
                  ],
                ),
              ),

              // — Central beacon with ETA —
              Center(
                child: Column(
                  children: [
                    const BeaconRing(
                      size: 130,
                      color: AppColors.amber,
                      ringCount: 2,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'ETA 14:32',
                      style: AppTextStyles.mono(
                        fontSize: 12,
                        color: AppColors.amber,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Live location shared with pod',
                      style: AppTextStyles.body(
                        fontSize: 11,
                        color: AppColors.faint,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // — Pod members list —
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: const [
                      _PodMemberTile(
                        initials: 'RS',
                        status: _MemberStatus.reached,
                      ),
                      _PodMemberTile(
                        initials: 'MK',
                        status: _MemberStatus.reached,
                      ),
                      _PodMemberTile(
                        initials: 'PJ',
                        status: _MemberStatus.reached,
                      ),
                      _PodMemberTile(
                        initials: 'TN',
                        status: _MemberStatus.live,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // — "Reached safely" CTA —
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: onReachedSafely,
                        icon: const Icon(Icons.check_rounded, size: 15),
                        label: Text(
                          "I've reached safely",
                          style: AppTextStyles.body(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.bgDeep,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.green,
                          foregroundColor: AppColors.bgDeep,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Missed check-ins auto-alert your pod and emergency contacts.',
                      style: AppTextStyles.body(
                        fontSize: 10.5,
                        color: AppColors.faint,
                      ),
                      textAlign: TextAlign.center,
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

enum _MemberStatus { reached, live }

class _PodMemberTile extends StatelessWidget {
  final String initials;
  final _MemberStatus status;

  const _PodMemberTile({required this.initials, required this.status});

  @override
  Widget build(BuildContext context) {
    final isReached = status == _MemberStatus.reached;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surface2,
              border: Border.all(
                color: isReached ? AppColors.green : AppColors.amber,
                width: 1.5,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: AppTextStyles.body(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Name and status text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Companion $initials',
                  style: AppTextStyles.body(
                    fontSize: 13,
                    color: AppColors.text,
                  ),
                ),
                Text(
                  isReached
                      ? 'Reached safely · 8:52 PM'
                      : 'En route · sharing location',
                  style: AppTextStyles.body(
                    fontSize: 10.5,
                    color: AppColors.faint,
                  ),
                ),
              ],
            ),
          ),
          // Status indicator
          if (isReached)
            const Icon(Icons.check_rounded, size: 15, color: AppColors.green)
          else
            Text(
              'live',
              style: AppTextStyles.mono(fontSize: 10, color: AppColors.amber),
            ),
        ],
      ),
    );
  }
}
