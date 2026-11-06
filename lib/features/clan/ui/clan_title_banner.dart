import 'package:flutter/material.dart';

/// Tên nhãn đầu cây (cố định).
const String kClanTitle = 'Gia phả họ Nguyễn';

const Color _burgundy = Color(0xFF8B1E1E);
const Color _bronze = Color(0xFF9A7B3F);

/// Nhãn đầu cây: chữ thư pháp trong khung đôi màu đồng, hoa sen ở hai góc chéo.
class ClanTitleBanner extends StatelessWidget {
  const ClanTitleBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final pageColor = Theme.of(context).scaffoldBackgroundColor;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 10),
      child: Center(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _bronze, width: 0.8),
              ),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _bronze, width: 1.5),
                ),
                child: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    kClanTitle,
                    maxLines: 1,
                    style: TextStyle(
                      fontFamily: 'DancingScript',
                      fontSize: 30,
                      height: 1.2,
                      color: _burgundy,
                      fontVariations: [FontVariation('wght', 600)],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: -4,
              top: -8,
              child: _LotusCorner(background: pageColor),
            ),
            Positioned(
              right: -4,
              bottom: -8,
              child: _LotusCorner(background: pageColor),
            ),
          ],
        ),
      ),
    );
  }
}

class _LotusCorner extends StatelessWidget {
  const _LotusCorner({required this.background});

  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: background,
      padding: const EdgeInsets.all(1),
      child: const Icon(Icons.local_florist_outlined, size: 16, color: _bronze),
    );
  }
}