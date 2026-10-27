import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:familytree/features/person/domain/person_relations.dart';
import 'package:familytree/features/person/domain/relation_changes.dart';
import 'package:familytree/features/proposals/ui/proposal_placeholder_screen.dart';
import 'package:familytree/features/proposals/ui/removal_proposal_screen.dart';
import 'package:familytree/features/tree/data/tree_repository.dart';

String? _loadMessage(AsyncValue<Object?> async, bool hasData) {
  if (async.hasError) {
    return 'Không tải được dữ liệu.';
  }
  return hasData ? 'Không tìm thấy mục này.' : null;
}

/// Gỡ MỘT dòng cha-con.
class RemoveParentChildScreen extends ConsumerWidget {
  const RemoveParentChildScreen({super.key, required this.linkId});

  final String linkId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const title = 'Gỡ quan hệ cha mẹ - con';
    final async = ref.watch(treeDataProvider);
    final data = async.value;
    final link = data?.parentChildren.where((pc) => pc.id == linkId).firstOrNull;

    if (data == null || link == null) {
      return ProposalPlaceholderScreen(
        title: title,
        message: _loadMessage(async, data != null),
      );
    }

    final byId = {for (final p in data.people) p.id: p};
    final parent = byId[link.parentId];
    final child = byId[link.childId];
    if (parent == null || child == null) {
      return const ProposalPlaceholderScreen(
        title: title,
        message: 'Không tìm thấy người trong quan hệ này.',
      );
    }

    final otherParents = data.parentChildren
        .where((pc) => pc.childId == link.childId && pc.id != link.id)
        .length;

    return RemovalProposalScreen(
      title: title,
      headline: '${parent.fullName} là cha/mẹ của ${child.fullName}',
      lines: [
        'Chỉ gỡ quan hệ này. Cả hai người vẫn còn trong gia phả.',
        if (otherParents == 0)
          '${child.fullName} sẽ không còn cha mẹ nào và hiện như một gốc '
              'riêng trên cây.',
      ],
      drafts: planRemoveParentChild(link),
      confirmMessage: 'Gỡ quan hệ cha/mẹ - con giữa ${parent.fullName} '
          'và ${child.fullName}?',
      noteIndex: 0,
      submitLabel: 'Gửi đề xuất gỡ',
    );
  }
}

/// Gỡ MỘT hôn nhân (không xóa người nào).
class RemoveMarriageScreen extends ConsumerWidget {
  const RemoveMarriageScreen({super.key, required this.marriageId});

  final String marriageId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const title = 'Gỡ hôn nhân';
    final async = ref.watch(treeDataProvider);
    final data = async.value;
    final marriage =
        data?.marriages.where((m) => m.id == marriageId).firstOrNull;

    if (data == null || marriage == null) {
      return ProposalPlaceholderScreen(
        title: title,
        message: _loadMessage(async, data != null),
      );
    }

    final byId = {for (final p in data.people) p.id: p};
    final name1 = byId[marriage.person1Id]?.fullName ?? '?';
    final name2 = byId[marriage.person2Id]?.fullName ?? '?';

    return RemovalProposalScreen(
      title: title,
      headline: 'Hôn nhân giữa $name1 và $name2',
      lines: const [
        'Chỉ gỡ quan hệ hôn nhân. Cả hai người vẫn còn trong gia phả.',
        'Con cái (nếu có) không bị ảnh hưởng.',
      ],
      drafts: planRemoveMarriage(marriage),
      confirmMessage: 'Gỡ hôn nhân giữa $name1 và $name2?',
      noteIndex: 0,
      submitLabel: 'Gửi đề xuất gỡ',
    );
  }
}

/// Đề xuất xóa một người (gói: gỡ quan hệ rồi xóa người).
class DeletePersonScreen extends ConsumerWidget {
  const DeletePersonScreen({super.key, required this.personId});

  final String personId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const title = 'Đề xuất xóa người';
    final async = ref.watch(treeDataProvider);
    final data = async.value;
    final person = data?.people.where((p) => p.id == personId).firstOrNull;

    if (data == null || person == null) {
      return ProposalPlaceholderScreen(
        title: title,
        message: _loadMessage(async, data != null),
      );
    }

    final relations = PersonRelations.of(
      personId,
      people: data.people,
      parentChildren: data.parentChildren,
      marriages: data.marriages,
    );

    if (personHasChildren(personId, data.parentChildren)) {
      return _BlockedDeleteScreen(
        personName: person.fullName,
        childNames: [for (final c in relations.children) c.person.fullName],
      );
    }

    final drafts = planDeletePerson(
      person: person,
      parentChildren: data.parentChildren,
      marriages: data.marriages,
    );

    return RemovalProposalScreen(
      title: title,
      headline: 'Xóa "${person.fullName}" khỏi gia phả',
      lines: [
        'Người này sẽ bị xóa khỏi gia phả sau khi quản trị viên duyệt.',
        if (relations.parents.isNotEmpty)
          'Gỡ quan hệ với cha/mẹ: '
              '${relations.parents.map((e) => e.person.fullName).join(', ')}.',
        if (relations.spouses.isNotEmpty)
          'Gỡ hôn nhân với: '
              '${relations.spouses.map((e) => e.person.fullName).join(', ')}.',
        'Chỉ nên dùng khi thêm nhầm hoặc bị trùng người.',
      ],
      drafts: drafts,
      confirmMessage: 'Gửi đề xuất xóa "${person.fullName}" khỏi gia phả?',
      // Lý do gắn vào dòng cuối của gói (dòng xóa người).
      noteIndex: drafts.length - 1,
      submitLabel: 'Gửi đề xuất xóa',
    );
  }
}

class _BlockedDeleteScreen extends StatelessWidget {
  const _BlockedDeleteScreen({
    required this.personName,
    required this.childNames,
  });

  final String personName;
  final List<String> childNames;

  @override
  Widget build(BuildContext context) {
    final shown = childNames.take(5).join(', ');
    final more = childNames.length > 5 ? ' và ${childNames.length - 5} người khác' : '';
    return Scaffold(
      appBar: AppBar(title: const Text('Đề xuất xóa người')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.block,
              size: 56,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Chưa thể đề xuất xóa $personName',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Người này còn con: $shown$more.\n'
              'Hãy xử lý (xóa hoặc gỡ quan hệ) các con trước.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, height: 1.4),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Quay lại', style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}