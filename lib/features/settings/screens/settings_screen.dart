import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Settings & Privacy screen.
/// Matches the JSX SettingsScreen component.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
                child: Text(
                  'Safety settings',
                  style: AppTextStyles.display(
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              // — Toggle rows —
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
                      _ToggleRow(
                        icon: Icons.mic_rounded,
                        title: 'Passive audio detection',
                        subtitle:
                            'On-device only, opt-in, active during commutes',
                        initialValue: true,
                      ),
                      _ToggleRow(
                        icon: Icons.people_rounded,
                        title: 'Auto pod matching',
                        subtitle:
                            'Match with others on similar routes and timing',
                        initialValue: true,
                      ),
                      _ToggleRow(
                        icon: Icons.location_on_rounded,
                        title: 'Precise location sharing',
                        subtitle: 'Share exact GPS instead of general area',
                        initialValue: true,
                      ),
                      _ToggleRow(
                        icon: Icons.volume_up_rounded,
                        title: 'Decoy call on SOS',
                        subtitle:
                            'Show a fake incoming call when alert triggers',
                        initialValue: true,
                      ),
                    ],
                  ),
                ),
              ),

              // — Privacy note —
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                child: Text(
                  'Audio is processed on your device. Nothing is uploaded unless an SOS is triggered.',
                  style: AppTextStyles.body(
                    fontSize: 10.5,
                    color: AppColors.faint,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToggleRow extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool initialValue;

  const _ToggleRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.initialValue,
  });

  @override
  State<_ToggleRow> createState() => _ToggleRowState();
}

class _ToggleRowState extends State<_ToggleRow> {
  late bool _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(widget.icon, size: 16, color: AppColors.amber),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: AppTextStyles.body(
                    fontSize: 13,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.subtitle,
                  style: AppTextStyles.body(
                    fontSize: 10.5,
                    color: AppColors.faint,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Custom toggle switch matching wireframe
          GestureDetector(
            onTap: () => setState(() => _value = !_value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 38,
              height: 22,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: _value ? AppColors.amber : AppColors.surface2,
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 150),
                alignment: _value
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  width: 18,
                  height: 18,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
