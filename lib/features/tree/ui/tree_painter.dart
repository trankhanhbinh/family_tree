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

    // Viền theo giới tính
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = accent,
    );

    // Avatar tròn (chữ cái đầu của tên)
    const pad = 10.0;
    const avatarRadius = 21.0;
    final avatarCenter = Offset(rect.left + pad + avatarRadius, rect.center.dy);
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

    // Khối chữ bên phải
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
    final Object? generation = person.generation;
    final generationText = generation == null ? null : 'Đời thứ $generation';
    final gen = generationText == null
        ? null
        : _text(
            generationText,
            const TextStyle(fontSize: 11, color: Color(0xFF8D6E63)),
            textWidth,
          );

    const gapBetween = 2.0;
    final totalHeight = name.height +
        gapBetween +
        years.height +
        (gen == null ? 0 : gapBetween + gen.height);
    var y = rect.center.dy - totalHeight / 2;

    name.paint(canvas, Offset(textLeft, y));
    y += name.height + gapBetween;
    years.paint(canvas, Offset(textLeft, y));
    y += years.height + gapBetween;
    gen?.paint(canvas, Offset(textLeft, y));

    name.dispose();
    years.dispose();
    gen?.dispose();
  }
}