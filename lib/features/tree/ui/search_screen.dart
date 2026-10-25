import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:familytree/features/person/domain/person.dart';
import 'package:familytree/features/tree/data/family_forest_provider.dart';
import 'package:familytree/features/tree/data/focus_request_provider.dart';
import 'package:familytree/features/tree/data/tree_repository.dart';
import 'package:familytree/features/tree/domain/tree_search.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _textController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _clear() {
    _textController.clear();
    setState(() => _query = '');
  }

  void _select(Person person) {
    final forest = ref.read(familyForestProvider).value;
    if (forest != null) {
      ref.read(focusRequestProvider.notifier).focusOn(person.id, forest);
    }
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(treeDataProvider).value;
    final results =
        data == null ? const <Person>[] : searchPeople(data.people, _query);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _textController,
          autofocus: true,
          textInputAction: TextInputAction.search,
          style: const TextStyle(fontSize: 20),
          decoration: const InputDecoration(
            hintText: 'Gõ tên người cần tìm',
            border: InputBorder.none,
          ),
          onChanged: (value) => setState(() => _query = value),
        ),
        actions: [
          if (_query.isNotEmpty)
            TextButton(
              onPressed: _clear,
              child: const Text(
                'Xóa',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
      body: _buildBody(context, data != null, results),
    );
  }

  Widget _buildBody(BuildContext context, bool hasData, List<Person> results) {
    if (!hasData) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_query.trim().isEmpty) {
      return const _Message(
        'Gõ họ tên hoặc tên khác của người cần tìm.\nKhông cần gõ dấu.',
      );
    }
    if (results.isEmpty) {
      return _Message('Không tìm thấy ai với "${_query.trim()}".');
    }
    return ListView.separated(
      itemCount: results.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final person = results[index];
        return _ResultTile(person: person, onTap: () => _select(person));
      },
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.person, required this.onTap});

  final Person person;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = _accentOf(person.gender);
    final Object? generation = person.generation;
    final other = person.otherName?.trim() ?? '';

    final lines = <String>[
      [
        if (generation != null) 'Đời thứ $generation',
        _lifeSpan(person),
      ].join(' · '),
      if (other.isNotEmpty) 'Tên khác: $other',
    ];

    return ListTile(
      minVerticalPadding: 12,
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: accent.withValues(alpha: 0.15),
        child: Text(
          _initialOf(person.fullName),
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: accent,
          ),
        ),
      ),
      title: Text(
        person.fullName,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        lines.join('\n'),
        style: const TextStyle(fontSize: 16),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
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

String _lifeSpan(Person person) {
  final int? birth = person.birthYear ?? person.birthDate?.year;
  if (!person.isAlive) {
    final int? death = person.deathYear ?? person.deathDate?.year;
    return '${birth ?? '?'} – ${death ?? '?'}';
  }
  return birth == null ? '?' : '$birth –';
}