import 'dart:math' as math;
import 'package:flutter/material.dart';

const brandColor = Color(0xFF8B5CF6);

Color brandDark() => Color.lerp(brandColor, Colors.black, 0.55)!;

/// شعار MT: مربع متدرج وخمسة أعمدة موجات (نفس تصميم الأيقونة)
class BrandMark extends StatelessWidget {
  final double size;
  final List<double>? bars;
  const BrandMark({super.key, required this.size, this.bars});

  static const _base = [0.22, 0.36, 0.50, 0.36, 0.22];

  @override
  Widget build(BuildContext context) {
    final bw = size * 0.085;
    final gap = size * 0.045;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.28),
        gradient: LinearGradient(
          colors: [brandColor, brandDark()],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [BoxShadow(color: brandColor.withAlpha(110), blurRadius: size * 0.4)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (var i = 0; i < 5; i++)
            Container(
              width: bw,
              height: math.max(bw, size * _base[i] * (bars == null ? 1.0 : bars![i])),
              margin: EdgeInsets.symmetric(horizontal: gap / 2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(bw / 2),
              ),
            ),
        ],
      ),
    );
  }
}
// ===== END brand =====