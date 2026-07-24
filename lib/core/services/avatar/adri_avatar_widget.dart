import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'avatar_lip_sync_service.dart';
import 'dialogue_script_parser.dart';

enum FacialExpression { neutral, happy, thinking, surprised }

class AdriAvatarWidget extends StatefulWidget {
  final bool isSpeaking;
  final double amplitude;
  final String language;
  final VoidCallback? onLanguageTap;
  // Si viene distinto de null, pisa el viseme calculado por
  // amplitud y dibuja la expresión completa (cejas, ojos, boca)
  // de las 15 posiciones. Si es null, el widget se comporta como
  // antes (solo boca por amplitud, sin cejas).
  final AvatarExpression? expressionOverride;

  const AdriAvatarWidget({
    super.key,
    this.isSpeaking = false,
    this.amplitude = 0.0,
    this.language = 'en',
    this.onLanguageTap,
    this.expressionOverride,
  });

  @override
  State<AdriAvatarWidget> createState() => _AdriAvatarWidgetState();
}

class _AdriAvatarWidgetState extends State<AdriAvatarWidget>
    with TickerProviderStateMixin {
  late AnimationController _blinkController;
  late AnimationController _mouthController;
  late AnimationController _expressionController;

  final AvatarLipSyncService _lipSync = AvatarLipSyncService();
  FacialExpression _expression = FacialExpression.neutral;
  bool _isBlinking = false;
  Timer? _blinkTimer;
  Viseme _currentViseme = Viseme.closed;

  static const Color _lipColor = Color(0xFFCC8E8E);
  static const Color _skinColor = Color(0xFFF5D0C5);
  static const Color _eyeColor = Color(0xFF2D1B4E);
  static const Color _hairColor = Color(0xFF6B3FA0);

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
    );
    _mouthController = AnimationController(vsync: this);
    _expressionController = AnimationController(vsync: this);
    _startBlinking();
  }

  void _startBlinking() {
    _blinkTimer?.cancel();
    _scheduleNextBlink();
  }

  void _scheduleNextBlink() {
    final nextBlink = Duration(milliseconds: 2200 + Random().nextInt(2600));
    _blinkTimer = Timer(nextBlink, () {
      if (mounted) {
        _blinkController.forward().then((_) => _blinkController.reverse());
        _scheduleNextBlink();
      }
    });
  }

  @override
  void didUpdateWidget(covariant AdriAvatarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.expressionOverride != null) {
      final params = kExpressionParams[widget.expressionOverride]!;
      _currentViseme = params.viseme;
    } else if (widget.isSpeaking && widget.amplitude > 0.05) {
      _currentViseme = _lipSync.calculateViseme(widget.amplitude);
    } else {
      _currentViseme = Viseme.closed;
    }

    if (widget.isSpeaking != oldWidget.isSpeaking) {
      setState(() {
        _expression = widget.isSpeaking ? FacialExpression.happy : FacialExpression.neutral;
      });
    }
    if (widget.expressionOverride != oldWidget.expressionOverride) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _blinkController.dispose();
    _mouthController.dispose();
    _expressionController.dispose();
    super.dispose();
  }

  String get _avatarAsset {
    return switch (widget.language) {
      'sw' => 'assets/avatars/adri_sw.png',
      'zh' => 'assets/avatars/adri_zh.png',
      // Fotos reales (ya en assets/avatars/) — si alguno de estos
      // nombres no coincide con el archivo real, avisar para
      // corregirlo aquí.
      'hi' => 'assets/avatars/adri_hi.png',
      'fr' => 'assets/avatars/adri_fr.png',
      'ru' => 'assets/avatars/adri_ru.png',
      'pt' => 'assets/avatars/adri_pt.png',
      'de' => 'assets/avatars/adri_de.png',
      'ar' => 'assets/avatars/adri_ar.png',
      'es' => 'assets/avatars/adri_sp.png',
      _    => 'assets/avatars/adri_en.png',
    };
  }

  String get _languageName {
    return switch (widget.language) {
      'sw' => 'Swahili Voice',
      'zh' => 'Zhong Wen Yu Yin',
      'hi' => 'Hindi Voice',
      'fr' => 'Voix Française',
      'ru' => 'Russkiy Golos',
      'pt' => 'Voz Portuguesa',
      'de' => 'Deutsche Stimme',
      'ar' => 'Sawt Arabi',
      'es' => 'Voz en Español',
      _    => 'English Voice',
    };
  }

  String get _flagEmoji {
    return switch (widget.language) {
      'sw' => '🇹🇿',
      'zh' => '🇨🇳',
      'hi' => '🇮🇳',
      'fr' => '🇫🇷',
      'ru' => '🇷🇺',
      'pt' => '🇵🇹',
      'de' => '🇩🇪',
      'ar' => '🇸🇦',
      'es' => '🇪🇸',
      _    => '🇬🇧',
    };
  }

  // Color de cejas por avatar -- antes era un solo castaño fijo
  // para los 10 idiomas, que no calzaba con cabello oscuro/negro en
  // varios de ellos. en/sw/zh son las 3 fotos originales (colores
  // ajustados a cada una); el resto usa un tono neutro oscuro por
  // defecto hasta poder calibrar cada foto nueva individualmente.
  // Medido con reconocimiento facial sobre las 10 fotos reales
  // (clúster de píxeles más oscuros en la zona de la ceja de cada
  // una -- no un promedio con la piel, que daba tonos muy claros).
  Color get _browColorForLanguage {
    return switch (widget.language) {
      'en' => const Color(0xFF46312B), // rubia -- ceja castaño medio
      'es' => const Color(0xFF3F281F), // castaño oscuro
      'sw' => const Color(0xFF342216), // casi negro
      'zh' => const Color(0xFF56392F), // castaño oscuro cálido
      'hi' => const Color(0xFF261C1C), // negro
      'fr' => const Color(0xFF2C2121), // negro-castaño
      'ru' => const Color(0xFF2C2020), // negro-castaño
      'pt' => const Color(0xFF221919), // negro
      'de' => const Color(0xFF3E261D), // castaño medio
      'ar' => const Color(0xFF23191B), // negro
      _    => const Color(0xFF2A211C),
    };
  }

  // Medido con reconocimiento facial sobre las 10 fotos reales
  // (color promedio de la zona rellena del labio de cada avatar).
  Color get _lipColorForLanguage {
    return switch (widget.language) {
      'en' => const Color(0xFF9A7361),
      'es' => const Color(0xFFAB7363),
      'sw' => const Color(0xFF7B5747),
      'zh' => const Color(0xFF926B58),
      'hi' => const Color(0xFF865350),
      'fr' => const Color(0xFF95635E),
      'ru' => const Color(0xFF9B6763),
      'pt' => const Color(0xFF97615D),
      'de' => const Color(0xFFAA6B65),
      'ar' => const Color(0xFF9B6763),
      _    => const Color(0xFF9A7361),
    };
  }

    double _getMouthHeight() {
    return switch (_currentViseme) {
      Viseme.closed => 0.02,
      Viseme.half   => 0.04,
      Viseme.open   => 0.06,
      Viseme.wide   => 0.08,
      Viseme.round  => 0.07,
      Viseme.smile  => 0.03,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _hairColor.withOpacity(0.3),
                border: Border.all(color: const Color(0xFF7C3AED), width: 3),
              ),
              child: ClipOval(
                child: Image.asset(
                  _avatarAsset,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => _buildFallbackAvatar(),
                ),
              ),
            ),
            Positioned.fill(
              child: CustomPaint(
                painter: _FacePainter(
                  isSpeaking: widget.isSpeaking || widget.expressionOverride != null,
                  isBlinking: _isBlinking || _blinkController.value > 0.5,
                  viseme: _currentViseme,
                  expression: _expression,
                  amplitude: widget.amplitude,
                  browLift: widget.expressionOverride != null
                      ? kExpressionParams[widget.expressionOverride]!.browLift
                      : 0,
                  eyeOpen: widget.expressionOverride != null
                      ? kExpressionParams[widget.expressionOverride]!.eyeOpen
                      : 0.5,
                  headTiltDeg: widget.expressionOverride != null
                      ? kExpressionParams[widget.expressionOverride]!.headTiltDeg
                      : 0,
                  browColor: _browColorForLanguage,
                  lipColor: _lipColorForLanguage,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Adri',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          widget.isSpeaking ? 'Speaking...' : 'Waiting...',
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: widget.onLanguageTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_flagEmoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Text(
                  _languageName,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.white,
                  ),
                ),
                const Icon(Icons.arrow_drop_down, color: Colors.white, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFallbackAvatar() {
    return Container(
      color: _skinColor,
      child: Center(
        child: Icon(Icons.person, size: 60, color: _hairColor),
      ),
    );
  }
}

class _FacePainter extends CustomPainter {
  final bool isSpeaking;
  final bool isBlinking;
  final Viseme viseme;
  final FacialExpression expression;
  final double amplitude;
  final double browLift;
  final double eyeOpen;
  final double headTiltDeg;
  final Color browColor;
  final Color lipColor;

  _FacePainter({
    required this.isSpeaking,
    required this.isBlinking,
    required this.viseme,
    required this.expression,
    required this.amplitude,
    this.browLift = 0,
    this.eyeOpen = 0.5,
    this.headTiltDeg = 0,
    this.browColor = const Color(0xFF4A3220),
    this.lipColor = const Color(0xFF9A7361),
  });

  static const Color _eyeColor = Color(0xFF2D1B4E);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    final pivot = Offset(size.width / 2, size.height / 2);
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(headTiltDeg * 3.1415926535 / 180);
    canvas.translate(-pivot.dx, -pivot.dy);

    final center = Offset(size.width / 2, size.height / 2);
    final scale = size.width;

    // Coordenadas recalibradas: la foto (768x1376) se muestra en
    // un contenedor CUADRADO con BoxFit.cover, que recorta ~44% de
    // la imagen (22% arriba + 22% abajo) para llenar el cuadrado.
    // X no se recorta (el ancho SÍ llena el cuadrado exactamente),
    // por eso solo Y cambia respecto a la posición real en la foto.
    const browRy = 0.090; // medido + ajuste fino según feedback visual
    // Overlay de ojos desactivado a pedido: la foto ya trae los ojos
    // reales, y el dibujo procedural encima se veía desalineado.
    // Se conservan cejas y boca (mueve bien y sí se ve correcto).
    _drawEyebrow(canvas, center, scale, 0.40, browRy);
    _drawEyebrow(canvas, center, scale, 0.61, browRy);

    if (isSpeaking) {
      _drawMouth(canvas, center, scale);
    }

    canvas.restore();
  }

  void _drawEyebrow(
      Canvas canvas, Offset center, double scale, double rx, double ry) {
    final paint = Paint()
      ..color = browColor.withOpacity(0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    // Movimiento x3 más visible que antes: al no dibujar los ojos,
    // la ceja quedó como el único canal (junto a la boca) para que
    // se note el cambio de expresión, así que el desplazamiento
    // tenía que ser más notorio (antes: 120.0, casi imperceptible).
    final liftNorm = browLift / 28.0 * scale; // más sensible -- las expresiones no se notaban
    final pos = Offset(
      center.dx + (rx - 0.5) * scale,
      center.dy + (ry - 0.5) * scale + liftNorm,
    );

    // Ceja más angosta (antes 0.05 de radio, ahora 0.036) y con un
    // arco natural sutil en vez de una línea recta pegada encima de
    // la foto -- se ve más como una ceja real y menos como un trazo.
    final halfWidth = 0.036 * scale;
    final archHeight = 0.010 * scale;

    final path = Path()
      ..moveTo(pos.dx - halfWidth, pos.dy + archHeight * 0.3)
      ..quadraticBezierTo(
        pos.dx, pos.dy - archHeight,
        pos.dx + halfWidth, pos.dy + archHeight * 0.5,
      );

    canvas.drawPath(path, paint);
  }

  void _drawEye(Canvas canvas, Offset center, double scale, double rx, double ry) {
    final eyePaint = Paint()
      ..color = _eyeColor
      ..style = PaintingStyle.fill;

    final pos = Offset(
      center.dx + (rx - 0.5) * scale,
      center.dy + (ry - 0.5) * scale,
    );

    final radius = (0.040 + eyeOpen * 0.026) * scale;
    canvas.drawCircle(pos, radius, eyePaint);

    final shinePaint = Paint()
      ..color = Colors.white.withOpacity(0.6)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(pos.dx - 0.01 * scale, pos.dy - 0.01 * scale),
      0.012 * scale,
      shinePaint,
    );
  }

  void _drawClosedEye(Canvas canvas, Offset center, double scale, double rx, double ry) {
    final paint = Paint()
      ..color = _eyeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final pos = Offset(
      center.dx + (rx - 0.5) * scale,
      center.dy + (ry - 0.5) * scale,
    );

    final path = Path()
      ..moveTo(pos.dx - 0.03 * scale, pos.dy)
      ..quadraticBezierTo(pos.dx, pos.dy + 0.005 * scale, pos.dx + 0.03 * scale, pos.dy);

    canvas.drawPath(path, paint);
  }

  void _drawMouth(Canvas canvas, Offset center, double scale) {
    // Con la boca CERRADA no se dibuja nada -- se deja ver la boca
    // real de la foto (siempre más fiel que cualquier forma pintada).
    if (viseme == Viseme.closed) return;

    // Posición y ancho medidos con MediaPipe sobre las 10 fotos
    // reales (promedio), transformados al recorte cuadrado de
    // BoxFit.cover (ver nota en paint()).
    final mouthCenter = Offset(
      center.dx,
      center.dy + (0.374 - 0.5) * scale,
    );
    final width = 0.194 * scale;

    // Rediseño: en vez de UN bloque de color (la "mancha" reportada),
    // se dibujan labio SUPERIOR e INFERIOR como dos formas finas y
    // SEPARADAS por un hueco pequeño -- el inferior un poco más
    // lleno que el superior, como en una boca real. El hueco crece
    // sutilmente según cuánto está "hablando" ese fragmento.
    final gap = _getMouthGap() * scale;
    final lipPaint = Paint()
      ..color = lipColor
      ..style = PaintingStyle.fill;

    final upperThickness = width * 0.095;
    final lowerThickness = width * 0.125;

    final upperRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(mouthCenter.dx, mouthCenter.dy - gap / 2 - upperThickness / 2),
        width: width,
        height: upperThickness,
      ),
      Radius.circular(upperThickness / 2),
    );
    final lowerRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(mouthCenter.dx, mouthCenter.dy + gap / 2 + lowerThickness / 2),
        width: width * 0.94,
        height: lowerThickness,
      ),
      Radius.circular(lowerThickness / 2),
    );

    // Interior visible solo si de verdad hay separación entre los
    // labios (evita un hueco oscuro visible en aperturas mínimas).
    if (gap > 1.0) {
      final innerPaint = Paint()
        ..color = const Color(0xFF2E1818)
        ..style = PaintingStyle.fill;
      final innerRect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: mouthCenter, width: width * 0.7, height: gap),
        Radius.circular(gap / 2),
      );
      canvas.drawRRect(innerRect, innerPaint);
    }

    canvas.drawRRect(upperRect, lipPaint);
    canvas.drawRRect(lowerRect, lipPaint);
  }


    double _getMouthGap() {
    // Valores pequeños y sutiles a propósito -- el hueco entre labio
    // superior e inferior, no la altura de un bloque completo.
    return switch (viseme) {
      Viseme.closed => 0.0,
      Viseme.half   => 0.014,
      Viseme.open   => 0.028,
      Viseme.wide   => 0.038,
      Viseme.round  => 0.032,
      Viseme.smile  => 0.006,
    };
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
