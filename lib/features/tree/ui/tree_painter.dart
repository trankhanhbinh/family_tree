import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:familytree/features/person/domain/person.dart';
import 'package:familytree/features/tree/domain/marriage.dart';
import 'package:familytree/features/tree/domain/parent_child.dart';
import 'package:familytree/features/tree/domain/tree_layout.dart';

const Color _lineColor = Color(0xFF5D4037);
const Color _widowedColor = Color(0xFFB0B0B0);
const Color _noMarriageColor = Color(0xFF9E9E9E);
const Color _maleColor = Color(0xFF1E6BB8);
const Color _femaleColor = Color(0xFFC2185B);
const Color _otherColor = Color(0xFF757575);
const Color _footerAccent = Color(0xFF8B1E1E);
const Color _footerIdleBg = Color(0xFFF6E9E9);
const Color _footerDivider = Color(0xFFE3C9C9);
const Color _highlightColor = Color(0xFFFFA000);

Paint _stroke(Color color, double width) => Paint()
  ..style = PaintingStyle.stroke
  ..strokeWidth = width
  ..strokeJoin = StrokeJoin.round
  ..color = color;

// Dùng chung cho mọi đường cùng kiểu (không tạo Paint mới mỗi lần vẽ).
final Paint _childPaint = _stroke(_lineColor, 2);
final Paint _marriedPaint = _stroke(_lineColor, 2);
final Paint _widowedPaint = _stroke(_widowedColor, 2);
final Paint _noMarriagePaint = _stroke(_noMarriageColor, 1.2);

/// Một đường nối đã dựng sẵn thành Path, kèm khung bao để loại nhanh khi nằm ngoài màn hình.
class LinkShape {
  LinkShape(this.path, this.paint) : bounds = path.getBounds().inflate(3);

  final Path path;
  final Paint paint;
  final Rect bounds;
}

/// Dữ liệu vẽ dựng MỘT LẦN cho mỗi layout (đường nối, nét đứt).
class TreeScene {
  TreeScene(this.layout) {
    for (final link in layout.links) {
      if (link.kind == LinkKind.marriage) {
        marriageLinks.add(_buildMarriage(link));
      } else if (_isNotBiological(link.relation)) {
        childDashed.add(
          LinkShape(_dashed(link.points, 6, 4), _childPaint),
        );
      } else {
        childSolid.add(LinkShape(_polyline(link.points), _childPaint));
      }
    }
  }

  final TreeLayout layout;
  final List<LinkShape> marriageLinks = [];
  final List<LinkShape> childDashed = [];
  final List<LinkShape> childSolid = [];

  /// Các thẻ giao với vùng [area] (toạ độ canvas).
  List<CardLayout> cardsIn(Rect area) =>
      layout.cards.where((c) => c.rect.overlaps(area)).toList();

  LinkShape _buildMarriage(LayoutLink link) {
    final marriage = link.marriage;
    if (marriage == null) {
      // Cặp không có dòng hôn nhân: nét chấm mảnh.
      return LinkShape(_dashed(link.points, 2, 4), _noMarriagePaint);
    }
    final MarriageStatus status = marriage.status;
    if (status == MarriageStatus.divorced) {
      return LinkShape(_dashed(link.points, 6, 4), _marriedPaint);
    }
    if (status == MarriageStatus.widowed) {
      return LinkShape(_polyline(link.points), _widowedPaint);
    }
    return LinkShape(_polyline(link.points), _marriedPaint);
  }

  static bool _isNotBiological(RelationType? relation) =>
      relation != null && relation != RelationType.biological;

  static Path _polyline(List<Offset> points) {
    final path = Path();
    if (points.isEmpty) {
      return path;
    }
    path.moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    return path;
  }

  static Path _dashed(List<Offset> points, double dash, double gap) {
    final source = _polyline(points);
    final out = Path();
    for (final metric in source.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = math.min(distance + dash, metric.length);
        out.addPath(metric.extractPath(distance, end), Offset.zero);
        distance += dash + gap;
      }
    }
    return out;
  }
}

/// Chữ trên một thẻ (dựng một lần).
class CardText {
  CardText({required this.initial, required this.name, required this.years});

  final TextPainter initial;
  final TextPainter name;
  final TextPainter years;

  void dispose() {
    initial.dispose();
    name.dispose();
    years.dispose();
  }
}

/// Bộ nhớ đệm TextPainter. Chủ sở hữu (TreeView) gọi [clear] khi dữ liệu đổi
/// và [clear] khi huỷ.
class CardTextCache {
  final Map<String, CardText> cards = {};
  final Map<String, TextPainter> footers = {};

  void clear() {
    for (final c in cards.values) {
      c.dispose();
    }
    for (final f in footers.values) {
      f.dispose();
    }
    cards.clear();
    footers.clear();
  }
}

/// Vẽ cây theo khung nhìn: chỉ vẽ phần nhìn thấy, tự áp ma trận zoom/pan.
/// Thứ tự: đường hôn nhân -> đường con nét đứt -> đường con nét liền -> thẻ -> khung nổi bật.
class TreePainter extends CustomPainter {
  TreePainter({
    required this.scene,
    required this.controller,
    required this.cache,
    this.highlightId,
    Animation<double>? pulse,
  })  : _pulse = pulse,
        super(
          repaint: Listenable.merge([controller, ?pulse]),
        );

  final TreeScene scene;
  final TransformationController controller;
  final CardTextCache cache;

  /// Người đang nhấp nháy (sau khi tìm kiếm / "Xem trên cây").
  final String? highlightId;
  final Animation<double>? _pulse;

  /// Zoom nhỏ hơn mức này thì vẽ thẻ rút gọn (không chữ).
  static const double _liteScale = 0.3;

  static const double _pad = 10;
  static const double _avatarRadius = 21;

  static final Paint _whitePaint = Paint()..color = Colors.white;
  static final Paint _deceasedPaint = Paint()..color = const Color(0xFFECECEC);
  static final Paint _ribbonPaint = Paint()..color = Colors.black87;

  TreeLayout get layout => scene.layout;

  @override
  void paint(Canvas canvas, Size size) {
    final matrix = controller.value;
    final scale = matrix.getMaxScaleOnAxis();
    // Vùng canvas đang nhìn thấy (nới 60px để thẻ sát mép không bị cắt).
    final visible =
        MatrixUtils.inverseTransformRect(matrix, Offset.zero & size)
            .inflate(60);

    canvas.save();
    canvas.transform(matrix.storage);

    for (final s in scene.marriageLinks) {
      if (s.bounds.overlaps(visible)) {
        canvas.drawPath(s.path, s.paint);
      }
    }
    // Nét đứt trước, nét liền sau (chung đoạn thân dọc).
    for (final s in scene.childDashed) {
      if (s.bounds.overlaps(visible)) {
        canvas.drawPath(s.path, s.paint);
      }
    }
    for (final s in scene.childSolid) {
      if (s.bounds.overlaps(visible)) {
        canvas.drawPath(s.path, s.paint);
      }
    }

    final lite = scale < _liteScale;
    for (final card in layout.cards) {
      if (!card.rect.overlaps(visible)) {
        continue;
      }
      if (lite) {
        _paintCardLite(canvas, card);
      } else {
        _paintCard(canvas, card);
      }
    }

    _paintHighlight(canvas);
    canvas.restore();
  }

  @override
  bool shouldRepaint(TreePainter oldDelegate) =>
      !identical(oldDelegate.scene, scene) ||
      oldDelegate.highlightId != highlightId ||
      !identical(oldDelegate.cache, cache);

  // ---------- Khung nổi bật ----------

  /// Khung vàng nhấp nháy 3 nhịp quanh thẻ được tìm thấy, mờ dần ở cuối.
  void _paintHighlight(Canvas canvas) {
    final id = highlightId;
    if (id == null) {
      return;
    }
    final card = layout.cardById[id];
    if (card == null) {
      return;
    }
    final t = _pulse?.value ?? 0.0;
    final wave = 0.5 + 0.5 * math.cos(t * 3 * 2 * math.pi);
    final fade = t > 0.85 ? (1 - t) / 0.15 : 1.0;
    final alpha = math.min(math.max((0.35 + 0.65 * wave) * fade, 0.0), 1.0);

    final rrect = RRect.fromRectAndRadius(
      card.rect.inflate(6),
      const Radius.circular(14),
    );
    canvas.drawRRect(
      rrect,
      Paint()..color = _highlightColor.withValues(alpha: alpha * 0.25),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = _highlightColor.withValues(alpha: alpha),
    );
  }

  // ---------- Thẻ ----------

  Color _accentOf(Gender? gender) {
    if (gender == Gender.male) {
      return _maleColor;
    }
    if (gender == Gender.female) {
      return _femaleColor;
    }
    return _otherColor;
  }

  String _initialOf(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    final last = parts.isEmpty ? '' : parts.last;
    if (last.isEmpty) {
      return '?';
    }
    return String.fromCharCode(last.runes.first).toUpperCase();
  }

  String _yearsText(Person person) {
    final int? birthYear = person.birthYear;
    final DateTime? birthDate = person.birthDate;
    final int? deathYear = person.deathYear;
    final DateTime? deathDate = person.deathDate;
    final bool alive = person.isAlive;

    final int? birth = birthYear ?? birthDate?.year;
    final int? death = deathYear ?? deathDate?.year;

    if (!alive) {
      return '${birth ?? '?'} – ${death ?? '?'}';
    }
    return birth == null ? '?' : '$birth –';
  }

  TextPainter _text(
    String text,
    TextStyle style,
    double maxWidth, {
    int maxLines = 1,
  }) {
    return TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: maxLines,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);
  }

  CardText _cardText(CardLayout card) {
    final cached = cache.cards[card.personId];
    if (cached != null) {
      return cached;
    }
    final person = card.person;
    final accent = _accentOf(person.gender);
    final textLeft = _pad + _avatarRadius * 2 + 8;
    final textWidth = card.rect.width - 8 - textLeft;

    final text = CardText(
      initial: _text(
        _initialOf(person.fullName),
        TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: accent),
        _avatarRadius * 2,
      ),
      name: _text(
        person.fullName,
        const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          height: 1.15,
          color: Color(0xFF212121),
        ),
        textWidth,
        maxLines: 2,
      ),
      years: _text(
        _yearsText(person),
        const TextStyle(fontSize: 12, color: Color(0xFF616161)),
        textWidth,
      ),
    );
    cache.cards[card.personId] = text;
    return text;
  }

  /// Thẻ rút gọn khi zoom xa: chỉ nền + viền + dải, không chữ.
  void _paintCardLite(Canvas canvas, CardLayout card) {
    final rect = card.rect;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(10));
    final accent = _accentOf(card.person.gender);

    canvas.drawRRect(
      rrect,
      card.person.isAlive ? _whitePaint : _deceasedPaint,
    );
    canvas.drawRRect(
      rrect,
      Paint()..color = accent.withValues(alpha: 0.18),
    );
    final footer = card.footerRect;
    if (footer != null) {
      canvas.save();
      canvas.clipRRect(rrect);
      canvas.drawRect(
        footer,
        Paint()..color = card.isCollapsed ? _footerAccent : _footerIdleBg,
      );
      canvas.restore();
    }
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = accent,
    );
  }

  void _paintCard(Canvas canvas, CardLayout card) {
    final person = card.person;
    final rect = card.rect;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(10));

    final deceased = !person.isAlive;
    final accent = _accentOf(person.gender);

    // Nền
    canvas.drawRRect(rrect, deceased ? _deceasedPaint : _whitePaint);

    // Dải băng đen góc trên phải (người đã mất)
    if (deceased) {
      canvas.save();
      canvas.clipRRect(rrect);
      final ribbon = Path()
        ..moveTo(rect.right - 20, rect.top)
        ..lineTo(rect.right, rect.top)
        ..lineTo(rect.right, rect.top + 20)
        ..close();
      canvas.drawPath(ribbon, _ribbonPaint);
      canvas.restore();
    }

    // Dải thu gọn ở đáy (vẽ trước viền để viền nằm đè lên).
    _paintFooter(canvas, card, rrect);

    // Viền theo giới tính
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = accent,
    );

    // Nội dung căn giữa trong phần trên (nếu có dải) hoặc cả thẻ (thẻ lá).
    final contentBottom = card.footerRect?.top ?? rect.bottom;
    final contentCy = (rect.top + contentBottom) / 2;

    final text = _cardText(card);

    // Avatar tròn (chữ cái đầu của tên)
    final avatarCenter =
        Offset(rect.left + _pad + _avatarRadius, contentCy);
    canvas.drawCircle(
      avatarCenter,
      _avatarRadius,
      Paint()..color = accent.withValues(alpha: 0.15),
    );
    text.initial.paint(
      canvas,
      Offset(
        avatarCenter.dx - text.initial.width / 2,
        avatarCenter.dy - text.initial.height / 2,
      ),
    );

    // Khối chữ bên phải (họ tên + năm sinh - năm mất)
    final textLeft = rect.left + _pad + _avatarRadius * 2 + 8;
    const gapBetween = 4.0;
    final totalHeight = text.name.height + gapBetween + text.years.height;
    var y = contentCy - totalHeight / 2;

    text.name.paint(canvas, Offset(textLeft, y));
    y += text.name.height + gapBetween;
    text.years.paint(canvas, Offset(textLeft, y));
  }

  // ---------- Dải thu gọn / mở rộng ----------

  TextPainter _footerLabel(CardLayout card, Rect footer) {
    final collapsed = card.isCollapsed;
    final key = '$collapsed|${card.descendantCount}';
    final cached = cache.footers[key];
    if (cached != null) {
      return cached;
    }
    const chevronW = 18.0;
    const innerGap = 6.0;
    const sidePad = 8.0;
    final avail = footer.width - sidePad * 2 - chevronW - innerGap;
    final style = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: collapsed ? Colors.white : _footerAccent,
    );

    var tp = _text(
      collapsed ? 'Xem thêm ${card.descendantCount} người' : 'Ẩn con cháu',
      style,
      double.infinity,
    );
    if (tp.width > avail) {
      // Số quá lớn: rút gọn nhãn để không bị cắt "…".
      tp.dispose();
      tp = _text('Xem thêm ${card.descendantCount}', style, double.infinity);
    }
    cache.footers[key] = tp;
    return tp;
  }

  void _paintFooter(Canvas canvas, CardLayout card, RRect cardRRect) {
    final footer = card.footerRect;
    if (footer == null) {
      return;
    }
    final collapsed = card.isCollapsed;
    final fg = collapsed ? Colors.white : _footerAccent;

    canvas.save();
    canvas.clipRRect(cardRRect);

    // Nền dải: đang thu gọn = nền đặc nổi bật, đang mở = nền nhạt.
    canvas.drawRect(
      footer,
      Paint()..color = collapsed ? _footerAccent : _footerIdleBg,
    );
    if (!collapsed) {
      canvas.drawLine(
        footer.topLeft,
        footer.topRight,
        Paint()
          ..color = _footerDivider
          ..strokeWidth = 1,
      );
    }

    const chevronW = 18.0;
    const chevronH = 10.0;
    const innerGap = 6.0;

    final tp = _footerLabel(card, footer);
    final groupW = tp.width + innerGap + chevronW;
    final startX = footer.center.dx - groupW / 2;
    final cy = footer.center.dy;

    tp.paint(canvas, Offset(startX, cy - tp.height / 2));

    final cx = startX + tp.width + innerGap + chevronW / 2;
    final halfW = chevronW / 2;
    final halfH = chevronH / 2;
    // Mở: chevron lên (^). Thu gọn: chevron xuống (v).
    final chevron = Path();
    if (collapsed) {
      chevron
        ..moveTo(cx - halfW, cy - halfH)
        ..lineTo(cx, cy + halfH)
        ..lineTo(cx + halfW, cy - halfH);
    } else {
      chevron
        ..moveTo(cx - halfW, cy + halfH)
        ..lineTo(cx, cy - halfH)
        ..lineTo(cx + halfW, cy + halfH);
    }
    canvas.drawPath(
      chevron,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = fg,
    );

    canvas.restore();
  }
}