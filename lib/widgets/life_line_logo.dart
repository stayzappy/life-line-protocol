import 'package:flutter/material.dart';
import 'dart:math' as math;

class LifeLineLogo extends StatelessWidget {
  final double size;
  final bool withText;

  const LifeLineLogo({
    super.key,
    this.size = 100.0,
    this.withText = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _LogoPainter(),
          ),
        ),
        if (withText) ...[
          const SizedBox(height: 16),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFF6366F1), Color(0xFF3B82F6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(bounds),
            child: Text(
              'LifeLine',
              style: TextStyle(
                fontSize: size * 0.3,
                fontWeight: FontWeight.bold,
                color: Colors.white, // Required for ShaderMask
                letterSpacing: 1.2,
              ),
            ),
          ),
          Text(
            'Protocol',
            style: TextStyle(
              fontSize: size * 0.15,
              color: Colors.grey[400],
              letterSpacing: 4.0,
            ),
          ),
        ],
      ],
    );
  }
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.12
      ..strokeCap = StrokeCap.round;

    // Define the gradient
    const gradient = LinearGradient(
      colors: [Color(0xFF6366F1), Color(0xFF06B6D4)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    paint.shader = gradient.createShader(
      Rect.fromCircle(center: center, radius: radius),
    );

    // Draw the stylized 'L' shape using two arcs
    final path = Path();
    
    // Top-right arc (part of the vertical line)
    path.addArc(
      Rect.fromCircle(center: center.translate(radius * 0.3, -radius * 0.3), radius: radius * 0.7),
      math.pi * 0.8,
      math.pi * 0.6,
    );

    // Bottom-left arc (part of the horizontal line)
    path.addArc(
      Rect.fromCircle(center: center.translate(-radius * 0.3, radius * 0.3), radius: radius * 0.7),
      math.pi * 1.8,
      math.pi * 0.6,
    );
    
    // Connect them with a central pulse/loop
    path.moveTo(center.dx - radius * 0.2, center.dy + radius * 0.2);
    path.quadraticBezierTo(
      center.dx, center.dy,
      center.dx + radius * 0.2, center.dy - radius * 0.2
    );

    canvas.drawPath(path, paint);

    // Add a subtle glow effect
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.15
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF6366F1).withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    canvas.drawPath(path, glowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}