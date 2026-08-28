import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Emergency contacts management screen.
/// Matches the JSX ContactsScreen component.
class ContactsScreen extends StatelessWidget {
  const ContactsScreen({super.key});

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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Emergency contacts',
                      style: AppTextStyles.display(
                        fontSize: 19,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Icon(Icons.person_add_rounded,
                        size: 17, color: AppColors.amber),
                  ],
                ),
              ),

              // — Contacts list —
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
                      _ContactRow(
                        initials: 'MA',
                        name: 'Mother',
                        relation: 'Primary · always alerted',
                      ),
                      _ContactRow(
                        initials: 'RK',
                        name: 'Rohan (brother)',
                        relation: 'Secondary',
                      ),
                      _ContactRow(
                        initials: 'SN',
                        name: 'Neha (flatmate)',
                        relation: 'Secondary',
                      ),
                    ],
                  ),
                ),
              ),

              // — Add contact button —
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: GestureDetector(
                  onTap: () {},
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.border,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add_rounded,
                            size: 14, color: AppColors.muted),
                        const SizedBox(width: 8),
                        Text(
                          'Add contact',
                          style: AppTextStyles.body(
                            fontSize: 12.5,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
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

class _ContactRow extends StatelessWidget {
  final String initials;
  final String name;
  final String relation;

  const _ContactRow({
    required this.initials,
    required this.name,
    required this.relation,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 1),
        ),
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
            ),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: AppTextStyles.body(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.amber,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Name + relation
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppTextStyles.body(
                    fontSize: 13,
                    color: AppColors.text,
                  ),
                ),
                Text(
                  relation,
                  style: AppTextStyles.body(
                    fontSize: 10.5,
                    color: AppColors.faint,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded,
              size: 14, color: AppColors.faint),
        ],
      ),
    );
  }
}
