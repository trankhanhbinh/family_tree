import 'package:flutter/material.dart';

import 'package:familytree/features/clan/ui/clan_title_banner.dart';

class EmptyTreeView extends StatelessWidget {
  const EmptyTreeView({
    super.key,
    required this.isAdmin,
    required this.onAddFirst,
  });

  final bool isAdmin;
  final VoidCallback onAddFirst;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        const ClanTitleBanner(),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Gia phả chưa có ai',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  if (isAdmin)
                    SizedBox(
                      height: 56,
                      child: FilledButton.icon(
                        onPressed: onAddFirst,
                        icon: const Icon(Icons.person_add_alt_1, size: 28),
                        label: const Text(
                          'Thêm người đầu tiên',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    )
                  else
                    Text(
                      'Quản trị viên sẽ thêm dữ liệu sớm.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
