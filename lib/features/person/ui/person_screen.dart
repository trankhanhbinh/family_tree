import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:familytree/features/person/domain/person.dart';
import 'package:familytree/features/tree/data/tree_repository.dart';

/// Màn hình tạm: chỉ hiện họ tên. Khối G sẽ làm chi tiết.
class PersonScreen extends ConsumerWidget {
  const PersonScreen({super.key, required this.personId});

  final String personId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(treeDataProvider).value;
    final Person? person =
        data?.people.where((p) => p.id == personId).firstOrNull;

    return Scaffold(
      appBar: AppBar(title: Text(person?.fullName ?? 'Chi tiết')),
      body: Center(
        child: Text(
          person?.fullName ?? 'Không tìm thấy người này',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
    );
  }
}