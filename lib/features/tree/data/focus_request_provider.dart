import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:familytree/features/tree/data/collapsed_ids_provider.dart';
import 'package:familytree/features/tree/domain/collapse_utils.dart';
import 'package:familytree/features/tree/domain/family_node.dart';

/// Yêu cầu "cuộn cây tới người này". [token] tăng dần để hai yêu cầu
/// liên tiếp cho cùng một người vẫn được coi là khác nhau.
class FocusRequest {
  const FocusRequest({required this.personId, required this.token});

  final String personId;
  final int token;
}

class FocusRequestNotifier extends Notifier<FocusRequest?> {
  int _token = 0;

  @override
  FocusRequest? build() => null;

  /// Mở rộng các tổ tiên đang thu gọn rồi phát yêu cầu cuộn tới [personId].
  void focusOn(String personId, FamilyForest forest) {
    final blockers = collapseBlockersOf(forest)[personId] ?? const <String>[];
    ref.read(collapsedIdsProvider.notifier).expand(blockers);
    _token++;
    state = FocusRequest(personId: personId, token: _token);
  }

  /// TreeView gọi sau khi đã nhận yêu cầu.
  void clear() {
    state = null;
  }
}

final focusRequestProvider =
    NotifierProvider<FocusRequestNotifier, FocusRequest?>(
  FocusRequestNotifier.new,
);