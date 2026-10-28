import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:familytree/core/utils/date_format.dart';
import 'package:familytree/features/person/domain/branch_path.dart';
import 'package:familytree/features/person/domain/person.dart';
import 'package:familytree/features/person/domain/person_relations.dart';
import 'package:familytree/features/photos/ui/person_photos_section.dart';
import 'package:familytree/features/photos/ui/photo_avatar.dart';
import 'package:familytree/features/tree/data/tree_repository.dart';
import 'package:familytree/features/tree/domain/marriage.dart';
import 'package:familytree/features/tree/domain/parent_child.dart';
import 'package:familytree/features/tree/data/family_forest_provider.dart';
import 'package:familytree/features/tree/data/focus_request_provider.dart';

/// Màn hình chi tiết người (thông tin, ảnh, gia đình, các nút đề xuất).
class PersonScreen extends ConsumerWidget {
  const PersonScreen({super.key, required this.personId});

  final String personId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(treeDataProvider);
    final data = async.value;

    if (data == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chi tiết')),
        body: Center(
          child: async.hasError
              ? const Text('Không tải được dữ liệu.')
              : const CircularProgressIndicator(),
        ),
      );
    }

    final person = data.people.where((p) => p.id == personId).firstOrNull;
    if (person == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chi tiết')),
        body: const Center(child: Text('Không tìm thấy người này.')),
      );
    }

    final relations = PersonRelations.of(
      person.id,
      people: data.people,
      parentChildren: data.parentChildren,
      marriages: data.marriages,
    );
    final branchPath = branchPathOf(person.branchId, data.branches);

    final sections = <Widget>[
      _Header(person: person),
      const SizedBox(height: 16),
      SizedBox(
        height: 56,
        child: FilledButton.icon(
          onPressed: () {
            final forest = ref.read(familyForestProvider).value;
            if (forest != null) {
              ref.read(focusRequestProvider.notifier).focusOn(person.id, forest);
            }
            context.go('/home');
          },
          icon: const Icon(Icons.account_tree_outlined, size: 28),
          label: const Text(
            'Xem trên cây',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ),
      ),
      const SizedBox(height: 12),
      SizedBox(
        height: 56,
        child: OutlinedButton.icon(
          onPressed: () => context.push('/person/${person.id}/edit'),
          icon: const Icon(Icons.edit_outlined, size: 28),
          label: const Text(
            'Đề xuất sửa thông tin',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ),
      ),
      const SizedBox(height: 16),
      _SectionCard(
        title: 'Thông tin',
        children: _infoRows(person, branchPath),
      ),
      if (!person.isAlive) _memorialSection(person),
      PersonPhotosSection(personId: person.id),
      ..._familySection(context, relations),
      _SectionCard(
        title: 'Thêm / sửa người thân',
        children: [
          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton.icon(
              onPressed: () => context.push('/person/${person.id}/add-child'),
              icon: const Icon(Icons.child_care, size: 28),
              label: const Text(
                'Thêm con',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton.icon(
              onPressed: () => context.push('/person/${person.id}/add-spouse'),
              icon: const Icon(Icons.favorite_border, size: 28),
              label: const Text(
                'Thêm vợ/chồng',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton.icon(
              onPressed: () => context.push('/person/${person.id}/relations'),
              icon: const Icon(Icons.edit_note, size: 28),
              label: const Text(
                'Sửa quan hệ gia đình',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
      ..._notesSection(person),
            const SizedBox(height: 8),
      SizedBox(
        height: 56,
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
            side: BorderSide(color: Theme.of(context).colorScheme.error),
          ),
          onPressed: () => context.push('/person/${person.id}/delete'),
          icon: const Icon(Icons.delete_outline, size: 28),
          label: const Text(
            'Đề xuất xóa người này',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ),
      ),
      const SizedBox(height: 24),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(person.fullName)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: sections,
      ),
    );
  }

  // ---------- Thông tin ----------

  List<Widget> _infoRows(Person person, String? branchPath) {
    final rows = <Widget>[];
    void add(String label, String? value) {
      if (value != null && value.trim().isNotEmpty) {
        rows.add(_InfoRow(label: label, value: value));
      }
    }

    add('Tên khác', person.otherName);
    add('Giới tính', _genderLabel(person.gender));
    add('Chi/nhánh', branchPath);
    add('Ngày sinh', _dateOrYear(person.birthDate, person.birthYear));
    add('Nơi sinh', person.birthPlace);
    add('Tình trạng', person.isAlive ? 'Còn sống' : 'Đã mất');
    if (!person.isAlive) {
      add('Ngày mất', _dateOrYear(person.deathDate, person.deathYear));
      add('Nơi an táng', person.burialPlace);
    }
    return rows;
  }

  // ---------- Ngày giỗ ----------

  Widget _memorialSection(Person person) {
    final Object? day = person.memorialLunarDay;
    final Object? month = person.memorialLunarMonth;
    final leap = person.memorialIsLeap == true;

    String text = 'Chưa cập nhật';
    if (day != null && month != null) {
      text = leap ? '$day/$month (nhuận) âm lịch' : '$day/$month âm lịch';
    }
    return _SectionCard(
      title: 'Ngày giỗ',
      children: [_InfoRow(label: 'Ngày giỗ', value: text)],
    );
  }

  // ---------- Gia đình ----------

  List<Widget> _familySection(BuildContext context, PersonRelations relations) {
    final items = <Widget>[];

    if (relations.parents.isNotEmpty) {
      items.add(const _SubHeader('Cha mẹ'));
      for (final e in relations.parents) {
        items.add(
          _PersonTile(
            person: e.person,
            subtitle: _parentText(e),
            onTap: () => context.push('/person/${e.person.id}'),
          ),
        );
      }
    }
    if (relations.spouses.isNotEmpty) {
      items.add(const _SubHeader('Vợ/chồng'));
      for (final e in relations.spouses) {
        items.add(
          _PersonTile(
            person: e.person,
            subtitle: _marriageText(e.marriage),
            onTap: () => context.push('/person/${e.person.id}'),
          ),
        );
      }
    }
    if (relations.children.isNotEmpty) {
      items.add(const _SubHeader('Con'));
      for (final e in relations.children) {
        items.add(
          _PersonTile(
            person: e.person,
            subtitle: _childText(e),
            onTap: () => context.push('/person/${e.person.id}'),
          ),
        );
      }
    }

    if (items.isEmpty) {
      return const [];
    }
    return [_SectionCard(title: 'Gia đình', children: items)];
  }

  // ---------- Ghi chú ----------

  List<Widget> _notesSection(Person person) {
    final notes = person.notes;
    if (notes == null || notes.trim().isEmpty) {
      return const [];
    }
    return [
      _SectionCard(title: 'Ghi chú', children: [Text(notes)]),
    ];
  }
}

// ---------- Hàm định dạng ----------

String _genderLabel(Gender gender) {
  switch (gender) {
    case Gender.male:
      return 'Nam';
    case Gender.female:
      return 'Nữ';
    case Gender.other:
      return 'Khác';
  }
}

String? _dateOrYear(DateTime? date, int? year) {
  if (date != null) {
    return formatDate(date);
  }
  if (year != null) {
    return '$year';
  }
  return null;
}

String _lifeSpan(Person person) {
  final int? birth = person.birthYear ?? person.birthDate?.year;
  if (!person.isAlive) {
    final int? death = person.deathYear ?? person.deathDate?.year;
    return '${birth ?? '?'} – ${death ?? '?'}';
  }
  return birth == null ? '?' : '$birth –';
}

String _parentText(ParentEntry entry) {
  var label = switch (entry.person.gender) {
    Gender.male => 'Cha',
    Gender.female => 'Mẹ',
    Gender.other => 'Cha/mẹ',
  };
  if (entry.relation == RelationType.adopted) {
    label = '$label (nuôi)';
  } else if (entry.relation == RelationType.step) {
    label = '$label (kế)';
  }
  return '$label · ${_lifeSpan(entry.person)}';
}

String _childText(ChildEntry entry) {
  String label;
  if (entry.relation == RelationType.adopted) {
    label = 'Con nuôi';
  } else if (entry.relation == RelationType.step) {
    label = 'Con riêng';
  } else {
    label = switch (entry.person.gender) {
      Gender.male => 'Con trai',
      Gender.female => 'Con gái',
      Gender.other => 'Con',
    };
  }
  return '$label · ${_lifeSpan(entry.person)}';
}

String _marriageText(Marriage marriage) {
  final label = switch (marriage.status) {
    MarriageStatus.married => 'Đang kết hôn',
    MarriageStatus.divorced => 'Đã ly hôn',
    MarriageStatus.widowed => 'Đã góa',
  };
  final DateTime? start = marriage.startDate;
  final DateTime? end = marriage.endDate;
  if (start == null && end == null) {
    return label;
  }
  final startText = start == null ? '?' : '${start.year}';
  final endText = end == null ? '' : ' ${end.year}';
  return '$label · $startText –$endText';
}

Color _accentOf(Gender gender) {
  if (gender == Gender.male) {
    return const Color(0xFF1E6BB8);
  }
  if (gender == Gender.female) {
    return const Color(0xFFC2185B);
  }
  return const Color(0xFF757575);
}

String _initialOf(String fullName) {
  final parts = fullName.trim().split(RegExp(r'\s+'));
  final last = parts.isEmpty ? '' : parts.last;
  if (last.isEmpty) {
    return '?';
  }
  return String.fromCharCode(last.runes.first).toUpperCase();
}

// ---------- Widget con ----------

class _Header extends StatelessWidget {
  const _Header({required this.person});

  final Person person;

  @override
  Widget build(BuildContext context) {
    final accent = _accentOf(person.gender);
    final Object? generation = person.generation;
    final theme = Theme.of(context);

    return Column(
      children: [
        PhotoAvatar(
          personId: person.id,
          radius: 44,
          accent: accent,
          initial: _initialOf(person.fullName),
          fontSize: 36,
        ),
        const SizedBox(height: 12),
        Text(
          person.fullName,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall,
        ),
        if (generation != null) ...[
          const SizedBox(height: 4),
          Text(
            'Đời thứ $generation',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

class _SubHeader extends StatelessWidget {
  const _SubHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 2),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}

class _PersonTile extends StatelessWidget {
  const _PersonTile({
    required this.person,
    required this.subtitle,
    required this.onTap,
  });

  final Person person;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = _accentOf(person.gender);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: PhotoAvatar(
        personId: person.id,
        radius: 18,
        accent: accent,
        initial: _initialOf(person.fullName),
      ),
      title: Text(person.fullName),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
