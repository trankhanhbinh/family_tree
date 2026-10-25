import 'dart:ui';

import 'package:familytree/features/person/domain/person.dart';
import 'package:familytree/features/tree/domain/marriage.dart';
import 'package:familytree/features/tree/domain/parent_child.dart';

/// Các hằng số bố cục (đơn vị logic pixel). Chỉnh ở đây sau khi xem trên emulator.
class TreeLayoutConfig {
  const TreeLayoutConfig({
    this.cardWidth = 160,
    this.cardHeight = 120,
    this.footerHeight = 40,
    this.spouseGap = 16,
    this.siblingGap = 28,
    this.levelGap = 72,
    this.marriageLineOffset = 14,
    this.marriageLineStep = 10,
    this.busClearance = 14,
    this.busStep = 8,
    this.padding = 40,
  });

  final double cardWidth;
  final double cardHeight;

  /// Chiều cao dải "Ẩn con cháu" / "Xem thêm N người" ở đáy thẻ người chính có con.
  final double footerHeight;

  /// Khoảng cách ngang giữa hai thẻ vợ/chồng.
  final double spouseGap;

  /// Khoảng cách ngang giữa hai nhánh anh em.
  final double siblingGap;

  /// Khoảng cách dọc giữa hai hàng thẻ.
  final double levelGap;

  /// Đường hôn nhân đầu tiên cách đáy thẻ bao nhiêu; các đường sau thấp hơn một nấc.
  final double marriageLineOffset;
  final double marriageLineStep;

  /// Trục ngang nối con cách đỉnh thẻ con bao nhiêu; mỗi đơn vị gia đình
  /// sau lệch thêm một nấc để các trục không chồng nhau.
  final double busClearance;
  final double busStep;

  final double padding;
}

/// Một thẻ người đã có tọa độ.
class CardLayout {
  const CardLayout({
    required this.person,
    required this.ownerId,
    required this.isSpouse,
    required this.row,
    required this.rect,
    this.hasChildren = false,
    this.isCollapsed = false,
    this.descendantCount = 0,
    this.footerRect,
  });

  final Person person;

  /// id người chính của nút chứa thẻ này (với người chính thì trùng personId).
  final String ownerId;
  final bool isSpouse;

  /// Hàng = độ sâu từ gốc (gốc = 0).
  final int row;
  final Rect rect;

  /// Chỉ có ý nghĩa với thẻ người chính: có con / đang thu gọn.
  final bool hasChildren;
  final bool isCollapsed;

  /// Số con cháu huyết thống/nuôi (đệ quy, không tính vợ/chồng).
  /// Tính trên toàn cây, không phụ thuộc đang thu gọn hay không.
  final int descendantCount;

  /// Vùng dải thu gọn (nằm trong [rect]); null nếu thẻ không có dải.
  final Rect? footerRect;

  String get personId => person.id;
}

enum LinkKind { marriage, child }

/// Một đường nối là một chuỗi điểm (polyline).
class LayoutLink {
  const LayoutLink({
    required this.kind,
    required this.ownerId,
    required this.points,
    this.childId,
    this.relation,
    this.marriage,
  });

  final LinkKind kind;
  final String ownerId;
  final List<Offset> points;

  /// Chỉ với đường con.
  final String? childId;
  final RelationType? relation;

  /// Chỉ với đường hôn nhân (null nếu cặp không có dòng hôn nhân).
  final Marriage? marriage;
}

class TreeLayout {
  TreeLayout({
    required this.cards,
    required this.links,
    required this.size,
  });

  final List<CardLayout> cards;
  final List<LayoutLink> links;
  final Size size;

  /// id người -> thẻ đầu tiên của người đó (người ở 2 nơi chỉ lấy thẻ đầu).
  late final Map<String, CardLayout> cardById = _index();

  Map<String, CardLayout> _index() {
    final map = <String, CardLayout>{};
    for (final c in cards) {
      map.putIfAbsent(c.personId, () => c);
    }
    return map;
  }
}