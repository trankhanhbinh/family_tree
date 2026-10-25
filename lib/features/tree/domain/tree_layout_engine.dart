import 'dart:math' as math;
import 'dart:ui';

import 'package:familytree/features/tree/domain/family_node.dart';
import 'package:familytree/features/tree/domain/parent_child.dart';
import 'package:familytree/features/tree/domain/tree_layout.dart';

/// Tính tọa độ cho cây. Dart thuần (chỉ dùng kiểu hình học của dart:ui).
class TreeLayoutEngine {
  TreeLayoutEngine._();

  /// [collapsedIds]: id các người chính đang thu gọn (ẩn toàn bộ con cháu).
  static TreeLayout compute(
    FamilyForest forest, {
    TreeLayoutConfig config = const TreeLayoutConfig(),
    Set<String> collapsedIds = const {},
  }) {
    return _Computer(config, collapsedIds).run(forest);
  }
}

class _Computer {
  _Computer(this.cfg, this.collapsed);

  final TreeLayoutConfig cfg;
  final Set<String> collapsed;

  final List<CardLayout> cards = [];
  final List<LayoutLink> links = [];
  final Map<String, double> _widths = {};
  final Map<String, double> _centerX = {};
  final Map<String, int> _descendantCounts = {};
  int _maxRow = 0;

  TreeLayout run(FamilyForest forest) {
    final rootGap = cfg.siblingGap * 2;
    var x = cfg.padding;
    for (final root in forest.roots) {
      _place(root, x, 0);
      x += _width(root) + rootGap;
    }
    final contentWidth =
        forest.roots.isEmpty ? 0.0 : x - rootGap - cfg.padding;
    final contentHeight = forest.roots.isEmpty
        ? 0.0
        : (_maxRow + 1) * cfg.cardHeight + _maxRow * cfg.levelGap;
    return TreeLayout(
      cards: cards,
      links: links,
      size: Size(
        contentWidth + cfg.padding * 2,
        contentHeight + cfg.padding * 2,
      ),
    );
  }

  // ---- Đếm con cháu (toàn cây, không phụ thuộc thu gọn) --------------------

  int _descendants(FamilyNode n) {
    final cached = _descendantCounts[n.person.id];
    if (cached != null) {
      return cached;
    }
    var total = 0;
    for (final u in n.unions) {
      for (final c in u.children) {
        total += 1 + _descendants(c);
      }
    }
    _descendantCounts[n.person.id] = total;
    return total;
  }

  // ---- Bước 1: độ rộng cụm -------------------------------------------------

  List<UnionGroup> _spouseUnions(FamilyNode n) =>
      n.unions.where((u) => u.spouse != null).toList();

  List<UnionGroup> _childUnions(FamilyNode n) {
    if (collapsed.contains(n.person.id)) return const [];
    return n.unions.where((u) => u.children.isNotEmpty).toList();
  }

  double _rowWidth(FamilyNode n) {
    final s = _spouseUnions(n).length;
    return (s + 1) * cfg.cardWidth + s * cfg.spouseGap;
  }

  double _childrenWidth(FamilyNode n) {
    var total = 0.0;
    var count = 0;
    for (final u in _childUnions(n)) {
      for (final c in u.children) {
        total += _width(c);
        count++;
      }
    }
    return count == 0 ? 0.0 : total + (count - 1) * cfg.siblingGap;
  }

  double _width(FamilyNode n) {
    final cached = _widths[n.person.id];
    if (cached != null) return cached;
    final w = math.max(_rowWidth(n), _childrenWidth(n));
    _widths[n.person.id] = w;
    return w;
  }

  // ---- Bước 2 + 3: đặt vị trí và sinh đường nối --------------------------------

  void _place(FamilyNode n, double x, int row) {
    if (row > _maxRow) _maxRow = row;

    final sw = _width(n);
    final rw = _rowWidth(n);
    final rowX = x + (sw - rw) / 2;
    final y = cfg.padding + row * (cfg.cardHeight + cfg.levelGap);
    final yBottom = y + cfg.cardHeight;
    final childTop = yBottom + cfg.levelGap;

    final spouseUnions = _spouseUnions(n);
    final childUnions = _childUnions(n);

    // Thẻ người chính (có dải thu gọn nếu có con).
    cards.add(CardLayout(
      person: n.person,
      ownerId: n.person.id,
      isSpouse: false,
      row: row,
      rect: Rect.fromLTWH(rowX, y, cfg.cardWidth, cfg.cardHeight),
      hasChildren: n.hasChildren,
      isCollapsed: n.hasChildren && collapsed.contains(n.person.id),
      descendantCount: _descendants(n),
      footerRect: n.hasChildren
          ? Rect.fromLTWH(
              rowX,
              y + cfg.cardHeight - cfg.footerHeight,
              cfg.cardWidth,
              cfg.footerHeight,
            )
          : null,
    ));
    final primaryCx = rowX + cfg.cardWidth / 2;
    _centerX[n.person.id] = primaryCx;

    // Thẻ các vợ/chồng, xếp nối tiếp theo thứ tự hôn nhân.
    final spouseCx = <UnionGroup, double>{};
    for (var i = 0; i < spouseUnions.length; i++) {
      final u = spouseUnions[i];
      final sx = rowX + (i + 1) * (cfg.cardWidth + cfg.spouseGap);
      cards.add(CardLayout(
        person: u.spouse!,
        ownerId: n.person.id,
        isSpouse: true,
        row: row,
        rect: Rect.fromLTWH(sx, y, cfg.cardWidth, cfg.cardHeight),
      ));
      spouseCx[u] = sx + cfg.cardWidth / 2;
    }

    // Đặt các con (căn giữa trong vùng của nút).
    final cw = _childrenWidth(n);
    var cursor = x + (sw - cw) / 2;
    for (final u in childUnions) {
      for (final c in u.children) {
        _place(c, cursor, row + 1);
        cursor += _width(c) + cfg.siblingGap;
      }
    }

    // Đường hôn nhân: chữ U dưới hai thẻ.
    for (var i = 0; i < spouseUnions.length; i++) {
      final u = spouseUnions[i];
      final yl = yBottom + cfg.marriageLineOffset + i * cfg.marriageLineStep;
      links.add(LayoutLink(
        kind: LinkKind.marriage,
        ownerId: n.person.id,
        marriage: u.marriage,
        points: [
          Offset(primaryCx, yBottom),
          Offset(primaryCx, yl),
          Offset(spouseCx[u]!, yl),
          Offset(spouseCx[u]!, yBottom),
        ],
      ));
    }

    // Đường xuống con: điểm thả -> trục ngang -> đỉnh thẻ con.
    for (var gi = 0; gi < childUnions.length; gi++) {
      final u = childUnions[gi];
      final si = spouseUnions.indexOf(u);
      final Offset drop = si >= 0
          ? Offset(
              (primaryCx + spouseCx[u]!) / 2,
              yBottom + cfg.marriageLineOffset + si * cfg.marriageLineStep,
            )
          : Offset(primaryCx, yBottom);
      var busY = childTop -
          cfg.busClearance -
          (childUnions.length - 1 - gi) * cfg.busStep;
      busY = math.min(math.max(busY, drop.dy + 4), childTop - 4);
      for (final c in u.children) {
        final cx = _centerX[c.person.id]!;
        links.add(LayoutLink(
          kind: LinkKind.child,
          ownerId: n.person.id,
          childId: c.person.id,
          relation: u.childRelations[c.person.id] ?? RelationType.biological,
          points: [
            drop,
            Offset(drop.dx, busY),
            Offset(cx, busY),
            Offset(cx, childTop),
          ],
        ));
      }
    }
  }
}