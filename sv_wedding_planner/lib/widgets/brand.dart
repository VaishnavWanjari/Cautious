import 'package:flutter/material.dart';

/// The SV Wedding Planner logo, rounded to match its framed look.
class BrandLogo extends StatelessWidget {
  final double size;
  final double radius;
  const BrandLogo({super.key, this.size = 64, this.radius = 16});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.asset(
        'assets/images/logo.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        // Graceful fallback if the asset can't be decoded.
        errorBuilder: (_, __, ___) => Container(
          width: size,
          height: size,
          color: const Color(0xFF0F3D2E),
          alignment: Alignment.center,
          child: Text('SV',
              style: TextStyle(
                color: const Color(0xFFC9A227),
                fontWeight: FontWeight.w900,
                fontSize: size * 0.4,
              )),
        ),
      ),
    );
  }
}
