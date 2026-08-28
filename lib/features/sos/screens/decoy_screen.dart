import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Decoy screen — fake incoming call from "Mom" to disguise the SOS trigger.
/// Matches the JSX DecoyScreen component exactly.
class DecoyScreen extends StatelessWidget {
  final VoidCallback onBack;

  const DecoyScreen({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: onBack,
      child: Scaffold(
        backgroundColor: const Color(0xFF0B0B10),
        body: SafeArea(
          child: Column(
            children: [
              // — Top hint bar —
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'double-tap to exit preview',
                      style: AppTextStyles.mono(
                        fontSize: 10,
                        color: const Color(0xFF555555),
                      ),
                    ),
                    GestureDetector(
                      onTap: onBack,
                      child: const Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: Color(0xFF666666),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // — Caller info —
              Container(
                width: 92,
                height: 92,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF2A2A32),
                ),
                alignment: Alignment.center,
                child: Text(
                  'M',
                  style: AppTextStyles.display(
                    fontSize: 30,
                    color: const Color(0xFF999999),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Mom',
                style: AppTextStyles.body(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFEDEDED),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'mobile · calling…',
                style: AppTextStyles.body(
                  fontSize: 12.5,
                  color: const Color(0xFF888888),
                ),
              ),

              const Spacer(),

              // — Decline / Accept buttons —
              Padding(
                padding: const EdgeInsets.only(bottom: 56),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    // Decline
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 58,
                          height: 58,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFE5484D),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.call_end_rounded,
                            size: 22,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Decline',
                          style: AppTextStyles.body(
                            fontSize: 10,
                            color: const Color(0xFF888888),
                          ),
                        ),
                      ],
                    ),
                    // Accept
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 58,
                          height: 58,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF30C85E),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.call_rounded,
                            size: 22,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Accept',
                          style: AppTextStyles.body(
                            fontSize: 10,
                            color: const Color(0xFF888888),
                          ),
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
