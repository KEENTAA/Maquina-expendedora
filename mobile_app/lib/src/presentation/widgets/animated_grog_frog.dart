import 'dart:math' as math;
import 'package:flutter/material.dart';

class AnimatedGrogFrog extends StatefulWidget {
  final double size;
  final bool isPasswordFocused;

  const AnimatedGrogFrog({
    super.key,
    this.size = 110,
    this.isPasswordFocused = false,
  });

  @override
  State<AnimatedGrogFrog> createState() => _AnimatedGrogFrogState();
}

class _AnimatedGrogFrogState extends State<AnimatedGrogFrog> with TickerProviderStateMixin {
  late AnimationController _idleController;
  late AnimationController _blinkController;
  late Animation<double> _floatAnim;
  late Animation<double> _blinkAnim;

  @override
  void initState() {
    super.initState();

    _idleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _floatAnim = Tween<double>(begin: -3.0, end: 3.0).animate(
      CurvedAnimation(parent: _idleController, curve: Curves.easeInOut),
    );

    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );

    _blinkAnim = Tween<double>(begin: 1.0, end: 0.08).animate(
      CurvedAnimation(parent: _blinkController, curve: Curves.easeIn),
    );

    _startBlinkCycle();
  }

  void _startBlinkCycle() async {
    while (mounted) {
      final waitSeconds = 3 + math.Random().nextInt(3);
      await Future.delayed(Duration(seconds: waitSeconds));
      if (!mounted) break;
      await _blinkController.forward();
      if (!mounted) break;
      await _blinkController.reverse();
    }
  }

  @override
  void dispose() {
    _idleController.dispose();
    _blinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_idleController, _blinkController]),
      builder: (context, _) {
        return Transform.translate(
          offset: Offset(0, _floatAnim.value),
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: CustomPaint(
              painter: _FrogPainter(
                blinkFactor: widget.isPasswordFocused ? 0.05 : _blinkAnim.value,
                isCoveringEyes: widget.isPasswordFocused,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FrogPainter extends CustomPainter {
  final double blinkFactor;
  final bool isCoveringEyes;

  _FrogPainter({
    required this.blinkFactor,
    required this.isCoveringEyes,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    const primaryIndigo = Color(0xFF4F46E5);
    const lighterIndigo = Color(0xFF6366F1);
    const darkIndigo = Color(0xFF3730A3);
    const blushPink = Color(0xFFF472B6);

    final bgGlowPaint = Paint()
      ..color = primaryIndigo.withValues(alpha: 0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
    canvas.drawCircle(Offset(w / 2, h / 2), w * 0.44, bgGlowPaint);

    final eyeBaseRadius = w * 0.20;
    final leftEyeCenter = Offset(w * 0.27, h * 0.32);
    final rightEyeCenter = Offset(w * 0.73, h * 0.32);

    final headGradient = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [lighterIndigo, primaryIndigo],
    ).createShader(Rect.fromLTWH(0, 0, w, h));

    final headPaint = Paint()..shader = headGradient;

    // Eyeballs base mounds
    canvas.drawCircle(leftEyeCenter, eyeBaseRadius, headPaint);
    canvas.drawCircle(rightEyeCenter, eyeBaseRadius, headPaint);

    // Main head shape
    final headRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(w / 2, h * 0.58), width: w * 0.82, height: h * 0.56),
      Radius.circular(w * 0.28),
    );
    canvas.drawRRect(headRect, headPaint);

    // Belly / Chin highlight
    final chinPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w / 2, h * 0.72), width: w * 0.52, height: h * 0.22),
      chinPaint,
    );

    // Cheeks
    final blushPaint = Paint()..color = blushPink.withValues(alpha: 0.45);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.22, h * 0.62), width: w * 0.13, height: h * 0.08),
      blushPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.78, h * 0.62), width: w * 0.13, height: h * 0.08),
      blushPaint,
    );

    // Eyes
    _drawEye(canvas, leftEyeCenter, eyeBaseRadius * 0.75, blinkFactor, isLeft: true);
    _drawEye(canvas, rightEyeCenter, eyeBaseRadius * 0.75, blinkFactor, isLeft: false);

    // Nose
    final nosePaint = Paint()
      ..color = darkIndigo
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(w * 0.45, h * 0.53), w * 0.02, nosePaint);
    canvas.drawCircle(Offset(w * 0.55, h * 0.53), w * 0.02, nosePaint);

    // Smile
    final smilePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.032
      ..strokeCap = StrokeCap.round;

    final smilePath = Path();
    smilePath.moveTo(w * 0.35, h * 0.65);
    smilePath.quadraticBezierTo(w * 0.5, h * 0.76, w * 0.65, h * 0.65);
    canvas.drawPath(smilePath, smilePaint);

    // Tongue
    final tonguePaint = Paint()..color = const Color(0xFFFB7185);
    final tonguePath = Path();
    tonguePath.moveTo(w * 0.46, h * 0.71);
    tonguePath.quadraticBezierTo(w * 0.50, h * 0.78, w * 0.54, h * 0.71);
    canvas.drawPath(tonguePath, tonguePaint);
  }

  void _drawEye(Canvas canvas, Offset center, double radius, double blink, {required bool isLeft}) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(1.0, blink.clamp(0.05, 1.0));

    final eyeWhitePaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset.zero, radius, eyeWhitePaint);

    if (blink > 0.3) {
      final pupilPaint = Paint()..color = const Color(0xFF1E1B4B);
      canvas.drawCircle(Offset(isLeft ? 1.5 : -1.5, 0), radius * 0.68, pupilPaint);

      final reflect1 = Paint()..color = Colors.white;
      canvas.drawCircle(Offset(isLeft ? -radius * 0.22 : -radius * 0.18, -radius * 0.22), radius * 0.24, reflect1);

      final reflect2 = Paint()..color = Colors.white.withValues(alpha: 0.85);
      canvas.drawCircle(Offset(isLeft ? radius * 0.22 : radius * 0.20, radius * 0.20), radius * 0.12, reflect2);
    } else {
      final closeLinePaint = Paint()
        ..color = const Color(0xFF1E1B4B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.22
        ..strokeCap = StrokeCap.round;
      final linePath = Path();
      linePath.moveTo(-radius * 0.65, 0);
      linePath.quadraticBezierTo(0, radius * 0.3, radius * 0.65, 0);
      canvas.drawPath(linePath, closeLinePaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _FrogPainter oldDelegate) {
    return oldDelegate.blinkFactor != blinkFactor ||
        oldDelegate.isCoveringEyes != isCoveringEyes;
  }
}
