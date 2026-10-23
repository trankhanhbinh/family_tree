import 'package:familytree/features/tree/data/tree_repository.dart';
import 'package:familytree/features/tree/domain/family_node.dart';
import 'package:familytree/features/tree/domain/family_tree_builder.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final familyForestProvider = FutureProvider<FamilyForest>(
  (ref) async {
    final data = await ref.watch(treeDataProvider.future);
    final forest = FamilyTreeBuilder.fromTreeData(data);
    if (kDebugMode) {
      for (final w in forest.warnings) {
        debugPrint('[FamilyTree] $w');
      }
    }
    return forest;
  },
  retry: (retryCount, error) => null,
);