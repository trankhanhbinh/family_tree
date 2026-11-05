import 'package:flutter/material.dart';

class PortraitFrame extends StatelessWidget {
  const PortraitFrame({
    super.key,
    required this.width,
    required this.accent,
    this.child,
    this.image,
  });

  static const double heightRatio = 4 / 3;

  final double width;
  final Color accent;
  final Widget? child;
  final ImageProvider? image;

  @override
  Widget build(BuildContext context) {
    final ImageProvider? photo = image;
    return Container(
      width: width,
      height: width * heightRatio,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular((width * 0.14).clamp(4.0, 10.0)),
        border: Border.all(color: accent.withValues(alpha: 0.45), width: 1),
        image: photo == null
            ? null
            : DecorationImage(
                image: photo,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
              ),
      ),
      child: photo == null ? child : null,
    );
  }
}
