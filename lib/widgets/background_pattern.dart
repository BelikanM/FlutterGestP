import 'package:flutter/material.dart';

class BackgroundPattern extends StatelessWidget {
  final Widget child;
  final Color? backgroundColor;
  final double opacity;
  final PatternType patternType;

  const BackgroundPattern({
    super.key,
    required this.child,
    this.backgroundColor,
    this.opacity = 0.1,
    this.patternType = PatternType.whatsapp,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? const Color(0xFF121212),
        image: DecorationImage(
          image: AssetImage(_getPatternAsset(patternType)),
          repeat: ImageRepeat.repeat,
          opacity: opacity,
        ),
      ),
      child: child,
    );
  }

  String _getPatternAsset(PatternType type) {
    switch (type) {
      case PatternType.whatsapp:
        return 'assets/patterns/whatsapp_pattern.png';
      case PatternType.dots:
        return 'assets/patterns/dots_pattern.png';
      case PatternType.circles:
        return 'assets/patterns/circles_pattern.png';
      case PatternType.hexagon:
        return 'assets/patterns/hexagon_pattern.png';
    }
  }
}

enum PatternType {
  whatsapp,
  dots,
  circles,
  hexagon,
}

// Widget pour créer des motifs CSS purs sans images
class CSSBackgroundPattern extends StatelessWidget {
  final Widget child;
  final Color? backgroundColor;
  final CSSPatternType patternType;

  const CSSBackgroundPattern({
    super.key,
    required this.child,
    this.backgroundColor,
    this.patternType = CSSPatternType.whatsappDots,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? const Color(0xFF121212),
      ),
      child: CustomPaint(
        painter: _getPatternPainter(patternType),
        child: child,
      ),
    );
  }

  CustomPainter _getPatternPainter(CSSPatternType type) {
    switch (type) {
      case CSSPatternType.whatsappDots:
        return WhatsAppDotsPainter();
      case CSSPatternType.subtleDots:
        return SubtleDotsPainter();
      case CSSPatternType.gridLines:
        return GridLinesPainter();
      case CSSPatternType.diagonalLines:
        return DiagonalLinesPainter();
    }
  }
}

enum CSSPatternType {
  whatsappDots,
  subtleDots,
  gridLines,
  diagonalLines,
}

// Painter pour les motifs WhatsApp-style
class WhatsAppDotsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.fill;

    const double dotSize = 2.0;
    const double spacing = 20.0;

    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(
          Offset(x + (y % (spacing * 2) == 0 ? 0 : spacing / 2), y),
          dotSize,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class SubtleDotsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
      ..style = PaintingStyle.fill;

    const double dotSize = 1.5;
    const double spacing = 15.0;

    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), dotSize, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class GridLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.02)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    const double spacing = 30.0;

    // Lignes verticales
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Lignes horizontales
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class DiagonalLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    const double spacing = 25.0;

    // Lignes diagonales de gauche à droite
    for (double i = -size.height; i < size.width; i += spacing) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Widget animé pour des motifs plus dynamiques
class AnimatedBackgroundPattern extends StatefulWidget {
  final Widget child;
  final Color? backgroundColor;

  const AnimatedBackgroundPattern({
    super.key,
    required this.child,
    this.backgroundColor,
  });

  @override
  State<AnimatedBackgroundPattern> createState() => _AnimatedBackgroundPatternState();
}

class _AnimatedBackgroundPatternState extends State<AnimatedBackgroundPattern>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();
    
    _animation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: widget.backgroundColor ?? const Color(0xFF121212),
      ),
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return CustomPaint(
            painter: AnimatedDotsPainter(_animation.value),
            child: widget.child,
          );
        },
      ),
    );
  }
}

class AnimatedDotsPainter extends CustomPainter {
  final double animationValue;

  AnimatedDotsPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..style = PaintingStyle.fill;

    const double dotSize = 1.5;
    const double spacing = 25.0;
    final double offset = animationValue * spacing;

    for (double x = -spacing; x < size.width + spacing; x += spacing) {
      for (double y = -spacing; y < size.height + spacing; y += spacing) {
        final adjustedX = x + offset;
        final adjustedY = y + (offset * 0.5);
        
        if (adjustedX >= -dotSize && adjustedX <= size.width + dotSize &&
            adjustedY >= -dotSize && adjustedY <= size.height + dotSize) {
          canvas.drawCircle(
            Offset(adjustedX, adjustedY),
            dotSize,
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(AnimatedDotsPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}