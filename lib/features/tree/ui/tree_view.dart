import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:familytree/features/tree/data/focus_request_provider.dart';
import 'package:familytree/features/tree/domain/collapse_utils.dart';
import 'package:familytree/features/tree/domain/family_node.dart';
import 'package:familytree/features/tree/domain/tree_layout.dart';
import 'package:familytree/features/tree/domain/tree_layout_engine.dart';
import 'package:familytree/features/tree/ui/tree_painter.dart';

/// Canvas cây gia phả: zoom/pan, bấm thẻ, thu gọn/mở rộng nhánh,
/// cuộn tới người được tìm, nút "về gốc".
/// Khối H3 sẽ chỉ vẽ phần nhìn thấy.
class TreeView extends StatefulWidget {
  const TreeView({
    super.key,
    required this.forest,
    required this.collapsedIds,
    required this.focusRequest,
    required this.onPersonTap,
    required this.onToggleCollapse,
    required this.onCollapseAll,
    required this.onExpandAll,
    required this.onFocusHandled,
  });

  final FamilyForest forest;

  /// Các người chính đang thu gọn (nguồn sự thật nằm ở provider).
  final Set<String> collapsedIds;

  /// Yêu cầu cuộn tới một người (null nếu không có).
  final FocusRequest? focusRequest;

  final void Function(String personId) onPersonTap;
  final void Function(String personId) onToggleCollapse;

  /// Nhận tập id cần thu gọn (người chính hàng >= 1 có con).
  final void Function(Set<String> ids) onCollapseAll;
  final VoidCallback onExpandAll;

  /// Báo đã nhận yêu cầu cuộn để provider xóa nó.
  final VoidCallback onFocusHandled;

  @override
  State<TreeView> createState() => _TreeViewState();
}

class _TreeViewState extends State<TreeView> with TickerProviderStateMixin {
  static const double _initialScale = 0.8;
  static const double _minScale = 0.15;
  static const double _maxScale = 2.5;
  static const double _topMargin = 24;

  /// Khi cuộn tới người được tìm, zoom không nhỏ hơn mức này.
  static const double _focusMinScale = 0.8;

  late TreeLayout _layout;
  late Set<String> _collapsible;
  TransformationController? _controller;
  Size _viewport = Size.zero;

  // Neo khung nhìn: thẻ vừa bấm phải đứng yên trên màn hình sau khi layout đổi.
  String? _anchorId;
  Rect? _anchorRect;

  // "Thu gọn tất cả"/"Mở rộng tất cả": sau khi layout đổi thì về gốc.
  bool _goHomePending = false;

  // Cuộn tới người được tìm + nhấp nháy.
  late final AnimationController _moveController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );
  late final AnimationController _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );
  Matrix4Tween? _moveTween;
  int? _handledToken;
  String? _highlightId;

  @override
  void initState() {
    super.initState();
    _collapsible = collapsibleNonRootIds(widget.forest);
    _layout = _compute();
    _moveController.addListener(_onMoveTick);
    _scheduleFocusCheck();
  }

  @override
  void didUpdateWidget(TreeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final forestChanged = !identical(oldWidget.forest, widget.forest);
    final collapsedChanged =
        !identical(oldWidget.collapsedIds, widget.collapsedIds);
    if (forestChanged || collapsedChanged) {
      if (forestChanged) {
        _collapsible = collapsibleNonRootIds(widget.forest);
      }
      _layout = _compute();
      _applyViewportPolicy();
    }
    if (!identical(oldWidget.focusRequest, widget.focusRequest)) {
      _scheduleFocusCheck();
    }
  }

  @override
  void dispose() {
    _moveController.dispose();
    _pulseController.dispose();
    _controller?.dispose();
    super.dispose();
  }

  TreeLayout _compute() => TreeLayoutEngine.compute(
        widget.forest,
        collapsedIds: widget.collapsedIds,
      );

  bool get _allCollapsed =>
      _collapsible.isNotEmpty && widget.collapsedIds.containsAll(_collapsible);

  // ---------- Cuộn tới người được tìm ----------

  void _scheduleFocusCheck() {
    final request = widget.focusRequest;
    if (request == null || request.token == _handledToken) {
      return;
    }
    // Chờ khung hình xong để chắc chắn layout mới và controller đã có.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusOn(widget.focusRequest);
      }
    });
  }

  void _focusOn(FocusRequest? request) {
    final controller = _controller;
    if (request == null ||
        controller == null ||
        request.token == _handledToken) {
      return;
    }
    _handledToken = request.token;
    widget.onFocusHandled();

    final card = _layout.cardById[request.personId];
    if (card == null) {
      return;
    }

    final current = controller.value;
    final scale = math.min(
      math.max(current.getMaxScaleOnAxis(), _focusMinScale),
      _maxScale,
    );
    final center = card.rect.center;
    final target = Matrix4(
      scale, 0, 0, 0,
      0, scale, 0, 0,
      0, 0, 1, 0,
      _viewport.width / 2 - center.dx * scale,
      _viewport.height / 2 - center.dy * scale,
      0, 1,
    );

    _moveTween = Matrix4Tween(begin: current, end: target);
    _moveController.forward(from: 0);

    final id = request.personId;
    setState(() => _highlightId = id);
    _pulseController.forward(from: 0).whenComplete(() {
      if (mounted && _highlightId == id) {
        setState(() => _highlightId = null);
      }
    });
  }

  void _onMoveTick() {
    final tween = _moveTween;
    final controller = _controller;
    if (tween == null || controller == null) {
      return;
    }
    controller.value =
        tween.transform(Curves.easeInOut.transform(_moveController.value));
  }

  // ---------- Khung nhìn ----------

  /// Giữ nguyên zoom; bù tịnh tiến để thẻ neo đứng yên trên màn hình.
  void _applyViewportPolicy() {
    final controller = _controller;
    if (controller == null) {
      _anchorId = null;
      _anchorRect = null;
      _goHomePending = false;
      return;
    }

    if (_goHomePending) {
      _goHomePending = false;
      _anchorId = null;
      _anchorRect = null;
      controller.value = _homeMatrix(_viewport);
      return;
    }

    final id = _anchorId;
    final oldRect = _anchorRect;
    _anchorId = null;
    _anchorRect = null;
    if (id == null || oldRect == null) {
      return;
    }
    final newCard = _layout.cardById[id];
    if (newCard == null) {
      return;
    }
    final m = controller.value.clone();
    final scale = m.getMaxScaleOnAxis();
    // Điểm canvas p hiện ở màn hình tại scale*p + t. Muốn thẻ đứng yên:
    // t_mới = t_cũ + scale * (rect_cũ - rect_mới).
    m.storage[12] += (oldRect.left - newCard.rect.left) * scale;
    m.storage[13] += (oldRect.top - newCard.rect.top) * scale;
    controller.value = m;
  }

  /// Khung nhìn ban đầu: gốc ở giữa phía trên, tỷ lệ 0.8.
  Matrix4 _homeMatrix(Size viewport) {
    final rootCards = _layout.cards.where((c) => c.row == 0).toList();
    if (rootCards.isEmpty) {
      return Matrix4.identity();
    }
    var left = double.infinity;
    var right = -double.infinity;
    var top = double.infinity;
    for (final card in rootCards) {
      left = math.min(left, card.rect.left);
      right = math.max(right, card.rect.right);
      top = math.min(top, card.rect.top);
    }
    final centerX = (left + right) / 2;
    final tx = viewport.width / 2 - centerX * _initialScale;
    final ty = _topMargin - top * _initialScale;
    // Ma trận cột-chính: scale + translate.
    return Matrix4(
      _initialScale, 0, 0, 0,
      0, _initialScale, 0, 0,
      0, 0, 1, 0,
      tx, ty, 0, 1,
    );
  }

  void _handleTap(Offset position) {
    // position đã ở hệ toạ độ canvas (GestureDetector nằm trong con của InteractiveViewer).
    for (final card in _layout.cards.reversed) {
      if (!card.rect.contains(position)) {
        continue;
      }
      final footer = card.footerRect;
      if (footer != null && footer.contains(position)) {
        // Chạm dải thu gọn được ưu tiên hơn chạm thẻ.
        _anchorId = card.personId;
        _anchorRect = card.rect;
        widget.onToggleCollapse(card.personId);
      } else {
        widget.onPersonTap(card.personId);
      }
      return;
    }
  }

  void _goHome() {
    _moveController.stop();
    _controller?.value = _homeMatrix(_viewport);
  }

  void _toggleAll() {
    _moveController.stop();
    _goHomePending = true;
    _anchorId = null;
    _anchorRect = null;
    if (_allCollapsed) {
      widget.onExpandAll();
    } else {
      widget.onCollapseAll(_collapsible);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _viewport = constraints.biggest;
        _controller ??= TransformationController(_homeMatrix(_viewport));
        final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

        return Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                transformationController: _controller,
                constrained: false,
                minScale: _minScale,
                maxScale: _maxScale,
                boundaryMargin: const EdgeInsets.all(double.infinity),
                // Người dùng chạm vào cây thì dừng cuộn tự động.
                onInteractionStart: (_) => _moveController.stop(),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (details) => _handleTap(details.localPosition),
                  child: RepaintBoundary(
                    child: CustomPaint(
                      size: _layout.size,
                      painter: TreePainter(
                        _layout,
                        highlightId: _highlightId,
                        pulse: _pulseController,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 16,
              bottom: 16 + bottomInset,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (_collapsible.isNotEmpty) ...[
                    FloatingActionButton.extended(
                      heroTag: 'tree_toggle_all',
                      onPressed: _toggleAll,
                      icon: Icon(
                        _allCollapsed ? Icons.unfold_more : Icons.unfold_less,
                        size: 28,
                      ),
                      label: Text(
                        _allCollapsed ? 'Mở rộng tất cả' : 'Thu gọn tất cả',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  FloatingActionButton.extended(
                    heroTag: 'tree_go_home',
                    onPressed: _goHome,
                    icon: const Icon(Icons.account_tree_outlined, size: 28),
                    label: const Text(
                      'Về gốc',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}