import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:familytree/features/person/domain/person.dart';
import 'package:familytree/features/person/domain/person_relations.dart';
import 'package:familytree/features/proposals/ui/proposal_placeholder_screen.dart';
import 'package:familytree/features/tree/data/tree_repository.dart';
import 'package:familytree/features/tree/domain/marriage.dart';
import 'package:familytree/features/tree/domain/parent_child.dart';

/// Danh sách quan hệ trực tiếp của một người, mỗi mục có nút sửa/gỡ (khối 4C-2).
class RelationsScreen extends ConsumerWidget {
  const RelationsScreen({super.key, required this.personId});

  final String personId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(treeDataProvider);
    final data = async.value;
    final person = data?.people.where((p) => p.id == personId).firstOrNull;

    if (data == null || person == null) {
      String? message;
      if (async.hasError) {
        message = 'Không tải được dữ liệu.';
      } else if (data != null) {
        message = 'Không tìm thấy người này.';
      }
      return ProposalPlaceholderScreen(
        title: 'Sửa quan hệ gia đình',
        message: message,
      );
    }

    final relations = PersonRelations.of(
      personId,
      people: data.people,
      parentChildren: data.parentChildren,
      marriages: data.marriages,
    );

    String? linkId(String parentId, String childId) {
      return data.parentChildren
          .where((pc) => pc.parentId == parentId && pc.childId == childId)
          .firstOrNull
          ?.id;
    }

    final items = <Widget>[
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          'Sửa quan quan hệ của ${person.fullName}. '
          'Mọi thay đổi được gửi cho quản trị viên duyệt, chưa áp dụng ngay.',
          style: const TextStyle(fontSize: 16, height: 1.4),
        ),
      ),
    ];

    if (relations.isEmpty) {
      items.add(
        const Text(
          'Người này chưa có quan hệ nào để sửa.',
          style: TextStyle(fontSize: 18),
        ),
      );
    }

    if (relations.parents.isNotEmpty) {
      items.add(const _SectionTitle('Cha mẹ'));
      for (final e in relations.parents) {
        final id = linkId(e.person.id, personId);
        items.add(
          _RelationCard(
            title: e.person.fullName,
            subtitle: _parentLabel(e.person.gender, e.relation),
            actions: [
              _RelationAction(
                'Đổi loại quan hệ',
                () => context.push('/person/$personId/relations/type/$personId'),
              ),
              if (id != null)
                _RelationAction(
                  'Gỡ quan hệ',
                  () => context.push('/person/$personId/relations/remove/$id'),
                  destructive: true,
                ),
            ],
          ),
        );
      }
    }

    if (relations.spouses.isNotEmpty) {
      items.add(const _SectionTitle('Vợ/chồng'));
      for (final e in relations.spouses) {
        final marriageId = e.marriage.id;
        items.add(
          _RelationCard(
            title: e.person.fullName,
            subtitle: _marriageText(e.marriage),
            actions: [
              _RelationAction(
                'Sửa hôn nhân',
                () => context.push('/person/$personId/marriage/$marriageId'),
              ),
              _RelationAction(
                'Gỡ hôn nhân',
                () => context.push(
                  '/person/$personId/marriage/$marriageId/remove',
                ),
                destructive: true,
              ),
            ],
          ),
        );
      }
    }

    if (relations.children.isNotEmpty) {
      items.add(const _SectionTitle('Con'));
      for (final e in relations.children) {
        final id = linkId(personId, e.person.id);
        final childId = e.person.id;
        items.add(
          _RelationCard(
            title: e.person.fullName,
            subtitle: _childLabel(e.relation),
            actions: [
              _RelationAction(
                'Đổi loại quan hệ',
                () => context.push('/person/$personId/relations/type/$childId'),
              ),
              if (id != null)
                _RelationAction(
                  'Gỡ quan hệ',
                  () => context.push('/person/$personId/relations/remove/$id'),
                  destructive: true,
                ),
            ],
          ),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Sửa quan hệ gia đình')),
      body: ListView(padding: const EdgeInsets.all(16), children: items),
    );
  }
}

String _parentLabel(Gender gender, RelationType relation) {
  final base = switch (gender) {
    Gender.male => 'Cha',
    Gender.female => 'Mẹ',
    Gender.other => 'Cha/mẹ',
  };
  return switch (relation) {
    RelationType.biological => '$base ruột',
    RelationType.adopted => '$base nuôi',
    RelationType.step => '$base kế',
  };
}

String _childLabel(RelationType relation) {
  return switch (relation) {
    RelationType.biological => 'Con ruột',
    RelationType.adopted => 'Con nuôi',
    RelationType.step => 'Con riêng',
  };
}

String _marriageText(Marriage marriage) {
  final label = switch (marriage.status) {
    MarriageStatus.married => 'Đang kết hôn',
    MarriageStatus.divorced => 'Đã ly hôn',
    MarriageStatus.widowed => 'Đã góa',
  };
  final start = marriage.startDate;
  final end = marriage.endDate;
  if (start == null && end == null) {
    return label;
  }
  final startText = start == null ? '?' : '${start.year}';
  final endText = end == null ? '' : ' ${end.year}';
  return '$label · $startText –$endText';
}

class _RelationAction {
  const _RelationAction(this.label, this.onPressed, {this.destructive = false});

  final String label;
  final VoidCallback onPressed;
  final bool destructive;
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _RelationCard extends StatelessWidget {
  const _RelationCard({
    required this.title,
    required this.subtitle,
    required this.actions,
  });

  final String title;
  final String subtitle;
  final List<_RelationAction> actions;

  @override
  Widget build(BuildContext context) {
    final errorColor = Theme.of(context).colorScheme.error;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 12),
            for (final action in actions)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton(
                    style: action.destructive
                        ? OutlinedButton.styleFrom(
                            foregroundColor: errorColor,
                            side: BorderSide(color: errorColor),
                          )
                        : null,
                    onPressed: action.onPressed,
                    child: Text(
                      action.label,
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}