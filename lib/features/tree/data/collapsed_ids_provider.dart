import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tập id người chính đang thu gọn. Mặc định rỗng (mở hết).
/// Độc lập với treeDataProvider nên "Làm mới" không làm mất trạng thái này.
class CollapsedIdsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => <String>{};

  void toggle(String id) {
    final next = {...state};
    if (!next.remove(id)) {
      next.add(id);
    }
    state = next;
  }

  void collapseAll(Set<String> ids) {
    state = {...ids};
  }

  void expandAll() {
    state = <String>{};
  }
}

final collapsedIdsProvider =
    NotifierProvider<CollapsedIdsNotifier, Set<String>>(
  CollapsedIdsNotifier.new,
);