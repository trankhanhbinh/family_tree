import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:familytree/features/person/domain/person.dart';
import 'package:familytree/features/tree/domain/marriage.dart';
import 'package:familytree/features/tree/domain/parent_child.dart';
import 'package:familytree/features/tree/domain/tree_layout.dart';

/// Vẽ toàn bộ cây (đường nối + thẻ) lên một canvas duy nhất.
/// Thứ tự vẽ: đường hôn nhân -> đường con nuôi (nét đứt) -> đường con ruột (nét liền) -> thẻ.
class TreePainter extends CustomPainter {
  TreePainter(this.layout);

  final TreeLayout layout;

  static const Color _lineColor = Color(0xFF5D4037);
  static const Color _widowedColor = Color(0xFFB0B0B0);
  static const Color _noMarriageColor = Color(0xFF9E9E9E);
  static const Color _maleColor = Color(0xFF1E6BB8);
  static const Color _femaleColor = Color(0xFFC2185B);
  static const Color _otherColor = Color(0xFF757575);
  static const Color _footerAccent = Color(0xFF8B1E1E);
  static const Color _footerIdleBg = Color(0xFFF6E9E9);
  static const Color _footerDivider = Color(0xFFE3C9C9);
  static const double _dash = 6;
  static const double _gap = 4;

  @override
  void paint(Canvas canvas, Size size) {
    _paintMarriageLinks(canvas);
    _paintChildLinks(canvas);
    for (final card in layout.cards) {
      _paintCard(canvas, card);
    }
  }

  @override
  bool shouldRepaint(TreePainter oldDelegate) =>
      !identical(oldDelegate.layout, layout);

  // ---------- Đường nối ----------

  void _paintMarriageLinks(Canvas canvas) {
    for (final link in layout.links) {
      if (link.kind != LinkKind.marriage) {
        continue;
      }
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..color = _lineColor;

      final marriage = link.marriage;
      if (marriage == null) {
        // Cặp không có dòng hôn nhân: nét chấm mảnh.
        paint
          ..strokeWidth = 1.2
          ..color = _noMarriageColor;
        _strokePolyline(canvas, link.points, paint, dash: 2, gap: 4);
        continue;
      }

      final MarriageStatus status = marriage.status;
      if (status == MarriageStatus.divorced) {
        _strokePolyline(canvas, link.points, paint, dash: _dash, gap: _gap);
      } else if (status == MarriageStatus.widowed) {
        paint.color = _widowedColor;
        _strokePolyline(canvas, link.points, paint);
      } else {
        _strokePolyline(canvas, link.points, paint);
      }
    }
  }

  void _paintChildLinks(Canvas canvas) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.round
      ..color = _lineColor;

    final childLinks =
        layout.links.where((l) => l.kind == LinkKind.child).toList();

    // Các đường con cùng đơn vị dùng chung đoạn thân dọc:
    // vẽ nét đứt (con nuôi/con riêng) trước, nét liền (con ruột) sau.
    for (final link in childLinks) {
      if (_isNotBiological(link.relation)) {
        _strokePolyline(canvas, link.points, paint, dash: _dash, gap: _gap);
      }
    }
    for (final link in childLinks) {
      if (!_isNotBiological(link.relation)) {
        _strokePolyline(canvas, link.points, paint);
      }
    }
  }

  bool _isNotBiological(RelationType? relation) =>
      relation != null && relation != RelationType.biological;

  void _strokePolyline(
    Canvas canvas,
    List<Offset> points,
    Paint paint, {
    double dash = 0,
    double gap = 0,
  }) {
    if (points.length < 2) {
      return;
    }
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    if (dash <= 0) {
      canvas.drawPath(path, paint);
      return;
    }
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = math.min(distance + dash, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += dash + gap;
      }
    }
  }

  // ---------- Thẻ người ----------

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

  void _paintCard(Canvas canvas, CardLayout card) {
    final person = card.person;
    final rect = card.rect;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(10));

    final deceased = !person.isAlive;
    final accent = _accentOf(person.gender);

    // Nền
    canvas.drawRRect(
      rrect,
      Paint()..color = deceased ? const Color(0xFFECECEC) : Colors.white,
    );

    // Dải băng đen góc trên phải (người đã mất)
    if (deceased) {
      canvas.save();
      canvas.clipRRect(rrect);
      final ribbon = Path()
        ..moveTo(rect.right - 20, rect.top)
        ..lineTo(rect.right, rect.top)
        ..lineTo(rect.right, rect.top + 20)
        ..close();
      canvas.drawPath(ribbon, Paint()..color = Colors.black87);
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

    // Avatar tròn (chữ cái đầu của tên)
    const pad = 10.0;
    const avatarRadius = 21.0;
    final avatarCenter = Offset(rect.left + pad + avatarRadius, contentCy);
    canvas.drawCircle(
      avatarCenter,
      avatarRadius,
      Paint()..color = accent.withValues(alpha: 0.15),
    );
    final initial = _text(
      _initialOf(person.fullName),
      TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: accent,
      ),
      avatarRadius * 2,
    );
    initial.paint(
      canvas,
      Offset(
        avatarCenter.dx - initial.width / 2,
        avatarCenter.dy - initial.height / 2,
      ),
    );
    initial.dispose();

    // Khối chữ bên phải (họ tên + năm sinh - năm mất)
    final textLeft = rect.left + pad + avatarRadius * 2 + 8;
    final textWidth = rect.right - 8 - textLeft;

    final name = _text(
      person.fullName,
      const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        height: 1.15,
        color: Color(0xFF212121),
      ),
      textWidth,
      maxLines: 2,
    );
    final years = _text(
      _yearsText(person),
      const TextStyle(fontSize: 12, color: Color(0xFF616161)),
      textWidth,
    );

    const gapBetween = 4.0;
    final totalHeight = name.height + gapBetween + years.height;
    var y = contentCy - totalHeight / 2;

    name.paint(canvas, Offset(textLeft, y));
    y += name.height + gapBetween;
    years.paint(canvas, Offset(textLeft, y));

    name.dispose();
    years.dispose();
  }

  // ---------- Dải thu gọn / mở rộng ----------

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

    // Chữ + chevron căn giữa thành một nhóm.
    const chevronW = 18.0;
    const chevronH = 10.0;
    const innerGap = 6.0;
    const sidePad = 8.0;
    final avail = footer.width - sidePad * 2 - chevronW - innerGap;
    final style = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: fg,
    );

    var label =
        collapsed ? 'Xem thêm ${card.descendantCount} người' : 'Ẩn con cháu';
    var tp = _text(label, style, double.infinity);
    if (tp.width > avail) {
      // Số quá lớn: rút gọn nhãn để không bị cắt "…".
      tp.dispose();
      label = 'Xem thêm ${card.descendantCount}';
      tp = _text(label, style, double.infinity);
    }

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

    tp.dispose();
    canvas.restore();
  }
}