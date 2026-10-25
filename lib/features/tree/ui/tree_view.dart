import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:familytree/features/tree/domain/family_node.dart';
import 'package:familytree/features/tree/domain/tree_layout.dart';
import 'package:familytree/features/tree/domain/tree_layout_engine.dart';
import 'package:familytree/features/tree/ui/tree_painter.dart';

/// Canvas cây gia phả: zoom/pan, bấm thẻ, nút "về gốc".
/// Khối H sẽ thêm collapsedIds, tìm kiếm và chỉ vẽ phần nhìn thấy.
class TreeView extends StatefulWidget {
  const TreeView({
    super.key,
    required this.forest,
    required this.onPersonTap,
  });

  final FamilyForest forest;
  final void Function(String personId) onPersonTap;

  @override
  State<TreeView> createState() => _TreeViewState();
}

class _TreeViewState extends State<TreeView> {
  static const double _initialScale = 0.8;
  static const double _minScale = 0.15;
  static const double _maxScale = 2.5;
  static const double _topMargin = 24;

  late TreeLayout _layout;
  TransformationController? _controller;
  Size _viewport = Size.zero;

  @override
  void initState() {
    super.initState();
    _layout = TreeLayoutEngine.compute(widget.forest);
  }

  @override
  void didUpdateWidget(TreeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.forest, widget.forest)) {
      _layout = TreeLayoutEngine.compute(widget.forest);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
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
      if (card.rect.contains(position)) {
        widget.onPersonTap(card.personId);
        return;
      }
    }
  }

  void _goHome() {
    _controller?.value = _homeMatrix(_viewport);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _viewport = constraints.biggest;
        _controller ??= TransformationController(_homeMatrix(_viewport));

        return Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                transformationController: _controller,
                constrained: false,
                minScale: _minScale,
                maxScale: _maxScale,
                boundaryMargin: const EdgeInsets.all(double.infinity),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (details) => _handleTap(details.localPosition),
                  child: RepaintBoundary(
                    child: CustomPaint(
                      size: _layout.size,
                      painter: TreePainter(_layout),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton.small(
                heroTag: 'tree_go_home',
                tooltip: 'Về gốc',
                onPressed: _goHome,
                child: const Icon(Icons.account_tree_outlined),
              ),
            ),
          ],
        );
      },
    );
  }
}