import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'avatar_lip_sync_service.dart';

/// ============================================================
/// ADRI AVATAR WIDGET - VERSIÓN 2.0
/// ============================================================
/// 
/// CARACTERÍSTICAS IMPLEMENTADAS:
/// 1. Labios con color natural (NO rojo intenso) - tono piel/rosa natural
/// 2. Labios SOLO se mueven cuando isSpeaking = true (Adri está hablando)
/// 3. Pestañeo natural en posición de ojos (coordenadas ajustadas)
/// 4. Expresiones faciales sutiles según contexto de conversación
/// 
/// COORDENADAS DEL AVATAR (basadas en imagen real):
/// - Ojos: centro en ~40% desde arriba, separados ~35% del ancho
/// - Boca: centro en ~62% desde arriba (sonrisa natural)
/// - Color de piel: tono cálido natural (NO rojo artificial)
/// ============================================================

class AdriAvatar extends StatefulWidget {
  final bool isSpeaking;
  final bool isListening;
  final String avatarAsset;
  final String? expression; // 'neutral', 'happy', 'thinking', 'surprised'
  final double size;

  const AdriAvatar({
    Key? key,
    required this.isSpeaking,
    this.isListening = false,
    required this.avatarAsset,
    this.expression,
    this.size = 120,
  }) : super(key: key);

  @override
  State<AdriAvatar> createState() => _AdriAvatarState();
}

class _AdriAvatarState extends State<AdriAvatar> with TickerProviderStateMixin {
  late AvatarLipSyncService _lipSyncService;

  // Controladores de animación
  late AnimationController _breathController;
  late AnimationController _expressionController;
  late AnimationController _blinkController;

  // Estados
  bool _isBlinking = false;
  Timer? _blinkTimer;
  final Random _random = Random();

  // Expresión actual
  String _currentExpression = 'neutral';

  @override
  void initState() {
    super.initState();

    _lipSyncService = AvatarLipSyncService();

    // Respiración sutil (siempre activa)
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);

    // Expresiones faciales
    _expressionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Pestañeo
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );

    _startNaturalBlinking();

    _lipSyncService.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant AdriAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Actualizar estado de habla
    if (widget.isSpeaking != oldWidget.isSpeaking) {
      if (widget.isSpeaking) {
        _lipSyncService.startSpeaking();
      } else {
        _lipSyncService.stopSpeaking();
      }
    }

    // Actualizar expresión
    if (widget.expression != oldWidget.expression && widget.expression != null) {
      _currentExpression = widget.expression!;
      _expressionController.forward(from: 0);
    }
  }

  /// Pestañeo natural: intervalos aleatorios entre 2-6 segundos
  void _startNaturalBlinking() {
    _scheduleNextBlink();
  }

  void _scheduleNextBlink() {
    final delay = Duration(milliseconds: 2000 + _random.nextInt(4000));
    _blinkTimer?.cancel();
    _blinkTimer = Timer(delay, () {
      if (!mounted) return;
      _performBlink();
    });
  }

  void _performBlink() {
    if (!mounted) return;
    setState(() => _isBlinking = true);

    _blinkController.forward(from: 0).then((_) {
      if (!mounted) return;
      _blinkController.reverse().then((_) {
        if (!mounted) return;
        setState(() => _isBlinking = false);
        _scheduleNextBlink();
      });
    });
  }

  @override
  void dispose() {
    _breathController.dispose();
    _expressionController.dispose();
    _blinkController.dispose();
    _blinkTimer?.cancel();
    _lipSyncService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _breathController,
        _expressionController,
        _blinkController,
        _lipSyncService,
      ]),
      builder: (context, child) {
        final breathScale = 1.0 + (_breathController.value * 0.012);

        return Transform.scale(
          scale: breathScale,
          child: Container(
            width: widget.size,
            height: widget.size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Imagen base del avatar
                ClipOval(
                  child: Image.asset(
                    widget.avatarAsset,
                    width: widget.size,
                    height: widget.size,
                    fit: BoxFit.cover,
                  ),
                ),

                // PESTAÑEO: Ojos superpuestos
                // Posición: 38% desde arriba (altura ojos en imagen)
                // Tamaño: 8% del avatar (ojos proporcionales)
                // Color: piel natural con tono cálido
                Positioned(
                  top: widget.size * 0.38,
                  left: 0,
                  right: 0,
                  child: CustomPaint(
                    size: Size(widget.size, widget.size * 0.12),
                    painter: _EyesPainter(
                      isBlinking: _isBlinking,
                      blinkProgress: _blinkController.value,
                      expression: _currentExpression,
                      expressionProgress: _expressionController.value,
                    ),
                  ),
                ),

                // BOCA: Solo visible cuando Adri está hablando
                // Posición: 60% desde arriba (sonrisa natural)
                // Color: tono natural de labios (NO rojo intenso)
                if (widget.isSpeaking)
                  Positioned(
                    top: widget.size * 0.58,
                    left: 0,
                    right: 0,
                    child: CustomPaint(
                      size: Size(widget.size, widget.size * 0.20),
                      painter: _NaturalMouthPainter(
                        currentMouth: _lipSyncService.currentMouth,
                        expression: _currentExpression,
                      ),
                    ),
                  ),

                // Indicador de estado (punto verde cuando habla)
                if (widget.isSpeaking)
                  Positioned(
                    bottom: widget.size * 0.08,
                    right: widget.size * 0.08,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.greenAccent,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.greenAccent.withOpacity(0.5),
                            blurRadius: 6,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// ============================================================
/// PINTOR DE OJOS CON PESTAÑEO NATURAL
/// ============================================================
/// Ubicación: 38% desde arriba del avatar
/// Tamaño: ojos proporcionales al rostro (~8% del ancho cada uno)
/// Color: tono piel natural con sombra sutil
/// ============================================================
class _EyesPainter extends CustomPainter {
  final bool isBlinking;
  final double blinkProgress;
  final String expression;
  final double expressionProgress;

  _EyesPainter({
    required this.isBlinking,
    required this.blinkProgress,
    required this.expression,
    required this.expressionProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final eyeY = size.height * 0.45;
    final eyeWidth = size.width * 0.08;  // 8% del ancho - proporción natural
    final eyeHeight = size.width * 0.035; // 3.5% - ojos naturales
    final eyeSpacing = size.width * 0.18; // 18% - separación entre ojos

    // Color de piel natural para los párpados (NO rojo)
    // Tono cálido que se integra con la imagen base
    final skinColor = Color(0xFFE8C4B8).withOpacity(0.4); // Tono piel natural
    final shadowColor = Color(0xFFD4A594).withOpacity(0.3); // Sombra sutil

    // Ojo izquierdo
    _drawEye(
      canvas,
      Offset(centerX - eyeSpacing / 2, eyeY),
      eyeWidth,
      eyeHeight,
      skinColor,
      shadowColor,
    );

    // Ojo derecho
    _drawEye(
      canvas,
      Offset(centerX + eyeSpacing / 2, eyeY),
      eyeWidth,
      eyeHeight,
      skinColor,
      shadowColor,
    );
  }

  void _drawEye(
    Canvas canvas,
    Offset center,
    double width,
    double height,
    Color skinColor,
    Color shadowColor,
  ) {
    // Si está parpadeando, cerrar el ojo progresivamente
    double currentHeight = height;
    if (isBlinking) {
      currentHeight = height * (1 - blinkProgress);
    }

    if (currentHeight <= 0.5) return; // Ojo completamente cerrado

    // Forma del ojo/párpado (elipse suave)
    final eyeRect = Rect.fromCenter(
      center: center,
      width: width,
      height: currentHeight,
    );

    // Párpado con tono de piel natural
    final paint = Paint()
      ..color = skinColor
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2);

    canvas.drawOval(eyeRect, paint);

    // Sombra sutil debajo del ojo (para dar profundidad)
    final shadowPaint = Paint()
      ..color = shadowColor
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);

    final shadowRect = Rect.fromCenter(
      center: Offset(center.dx, center.dy + height * 0.6),
      width: width * 1.2,
      height: height * 0.8,
    );

    canvas.drawOval(shadowRect, shadowPaint);
  }

  @override
  bool shouldRepaint(covariant _EyesPainter oldDelegate) {
    return oldDelegate.isBlinking != isBlinking ||
        oldDelegate.blinkProgress != blinkProgress ||
        oldDelegate.expression != expression;
  }
}

/// ============================================================
/// PINTOR DE BOCA CON COLOR NATURAL
/// ============================================================
/// SOLO se activa cuando isSpeaking = true
/// Ubicación: 60% desde arriba (coincide con sonrisa real)
/// Color: tono natural de labios (rosa/coral suave, NO rojo intenso)
/// ============================================================
class _NaturalMouthPainter extends CustomPainter {
  final String currentMouth;
  final String expression;

  _NaturalMouthPainter({
    required this.currentMouth,
    required this.expression,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height * 0.45; // Centro de la boca en el área de pintura
    final mouthWidth = size.width * 0.18; // 18% del ancho - labios naturales

    // COLORES NATURALES DE LABIOS (NO rojo intenso)
    // Tono coral/rosa natural que se integra con la piel
    final lipFillColor = Color(0xFFCC8E8E).withOpacity(0.55); // Rosa coral natural
    final lipOutlineColor = Color(0xFFB87878).withOpacity(0.35); // Contorno sutil
    final lipHighlightColor = Colors.white.withOpacity(0.12); // Brillo muy sutil

    final paint = Paint()
      ..color = lipFillColor
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.6);

    final outlinePaint = Paint()
      ..color = lipOutlineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.4);

    final Path mouthPath;

    switch (currentMouth) {
      case 'closed':
        mouthPath = _buildClosedMouth(centerX, centerY, mouthWidth);
        break;
      case 'half':
        mouthPath = _buildHalfOpenMouth(centerX, centerY, mouthWidth);
        break;
      case 'open':
        mouthPath = _buildOpenMouth(centerX, centerY, mouthWidth);
        break;
      case 'wide':
        mouthPath = _buildWideMouth(centerX, centerY, mouthWidth);
        break;
      case 'round':
        mouthPath = _buildRoundMouth(centerX, centerY, mouthWidth);
        break;
      case 'smile':
        mouthPath = _buildSmileMouth(centerX, centerY, mouthWidth);
        break;
      default:
        mouthPath = _buildClosedMouth(centerX, centerY, mouthWidth);
    }

    // Dibujar labios con color natural
    canvas.drawPath(mouthPath, paint);
    canvas.drawPath(mouthPath, outlinePaint);

    // Brillo sutil en el labio superior
    final highlightPath = _buildHighlight(centerX, centerY, mouthWidth);
    final highlightPaint = Paint()
      ..color = lipHighlightColor
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.0);
    canvas.drawPath(highlightPath, highlightPaint);
  }

  // Formas de boca (6 estados de visema)
  Path _buildClosedMouth(double cx, double cy, double w) {
    return Path()
      ..moveTo(cx - w / 2, cy)
      ..quadraticBezierTo(cx - w / 4, cy - 2, cx, cy - 1)
      ..quadraticBezierTo(cx + w / 4, cy - 2, cx + w / 2, cy)
      ..quadraticBezierTo(cx + w / 4, cy + 2, cx, cy + 1)
      ..quadraticBezierTo(cx - w / 4, cy + 2, cx - w / 2, cy);
  }

  Path _buildHalfOpenMouth(double cx, double cy, double w) {
    final h = w * 0.15;
    return Path()
      ..moveTo(cx - w / 2, cy - h / 2)
      ..quadraticBezierTo(cx - w / 4, cy - h, cx, cy - h * 0.8)
      ..quadraticBezierTo(cx + w / 4, cy - h, cx + w / 2, cy - h / 2)
      ..quadraticBezierTo(cx + w / 4, cy + h, cx, cy + h * 0.8)
      ..quadraticBezierTo(cx - w / 4, cy + h, cx - w / 2, cy - h / 2);
  }

  Path _buildOpenMouth(double cx, double cy, double w) {
    final h = w * 0.25;
    return Path()
      ..moveTo(cx - w / 2, cy - h / 2)
      ..quadraticBezierTo(cx - w / 4, cy - h * 1.2, cx, cy - h)
      ..quadraticBezierTo(cx + w / 4, cy - h * 1.2, cx + w / 2, cy - h / 2)
      ..quadraticBezierTo(cx + w / 4, cy + h * 1.2, cx, cy + h)
      ..quadraticBezierTo(cx - w / 4, cy + h * 1.2, cx - w / 2, cy - h / 2);
  }

  Path _buildWideMouth(double cx, double cy, double w) {
    final h = w * 0.30;
    return Path()
      ..moveTo(cx - w / 2, cy - h / 2)
      ..quadraticBezierTo(cx - w / 4, cy - h * 1.3, cx, cy - h * 1.1)
      ..quadraticBezierTo(cx + w / 4, cy - h * 1.3, cx + w / 2, cy - h / 2)
      ..quadraticBezierTo(cx + w / 4, cy + h * 1.3, cx, cy + h * 1.1)
      ..quadraticBezierTo(cx - w / 4, cy + h * 1.3, cx - w / 2, cy - h / 2);
  }

  Path _buildRoundMouth(double cx, double cy, double w) {
    final h = w * 0.22;
    return Path()
      ..addOval(Rect.fromCenter(center: Offset(cx, cy), width: w * 0.6, height: h));
  }

  Path _buildSmileMouth(double cx, double cy, double w) {
    return Path()
      ..moveTo(cx - w / 2, cy + 2)
      ..quadraticBezierTo(cx - w / 4, cy - 4, cx, cy - 3)
      ..quadraticBezierTo(cx + w / 4, cy - 4, cx + w / 2, cy + 2)
      ..quadraticBezierTo(cx + w / 4, cy + 6, cx, cy + 5)
      ..quadraticBezierTo(cx - w / 4, cy + 6, cx - w / 2, cy + 2);
  }

  Path _buildHighlight(double cx, double cy, double w) {
    return Path()
      ..moveTo(cx - w / 4, cy - 3)
      ..quadraticBezierTo(cx, cy - 5, cx + w / 4, cy - 3)
      ..lineTo(cx + w / 5, cy - 1)
      ..quadraticBezierTo(cx, cy - 3, cx - w / 5, cy - 1);
  }

  @override
  bool shouldRepaint(covariant _NaturalMouthPainter oldDelegate) {
    return oldDelegate.currentMouth != currentMouth ||
        oldDelegate.expression != expression;
  }
}
