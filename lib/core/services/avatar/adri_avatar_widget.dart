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

  // ============================================================
  // MAPA DE AVATARES (ACTUALIZADO CON 28 IDIOMAS)
  // ============================================================
  String get _avatarAsset {
    return switch (widget.language) {
      'en' => 'assets/avatars/adri_en.png',
      'es' => 'assets/avatars/adri_sp.png',
      'sw' => 'assets/avatars/adri_sw.png',
      'zh' => 'assets/avatars/adri_zh.png',
      'hi' => 'assets/avatars/adri_hi.png',
      'fr' => 'assets/avatars/adri_fr.png',
      'ru' => 'assets/avatars/adri_ru.png',
      'pt' => 'assets/avatars/adri_pt.png',
      'de' => 'assets/avatars/adri_de.png',
      'ar' => 'assets/avatars/adri_ar.png',
      'tr' => 'assets/avatars/adri_tr.png',
      'suk' => 'assets/avatars/adri_suk.png',
      'gu' => 'assets/avatars/adri_gu.png',
      'ja' => 'assets/avatars/adri_ja.png',
      'ko' => 'assets/avatars/adri_ko.png',
      'th' => 'assets/avatars/adri_th.png',
      'vi' => 'assets/avatars/adri_vi.png',
      'id' => 'assets/avatars/adri_id.png',
      'bn' => 'assets/avatars/adri_bn.png',
      'pa' => 'assets/avatars/adri_pa.png',
      'ta' => 'assets/avatars/adri_ta.png',
      'my' => 'assets/avatars/adri_my.png',
      'tl' => 'assets/avatars/adri_tl.png',
      'ro' => 'assets/avatars/adri_ro.png',
      'el' => 'assets/avatars/adri_el.png',
      'nl' => 'assets/avatars/adri_nl.png',
      'pl' => 'assets/avatars/adri_pl.png',
      'uk' => 'assets/avatars/adri_uk.png',
      'it' => 'assets/avatars/adri_it.png',
      _ => 'assets/avatars/adri_en.png',
    };
  }

  String get _languageName {
    return switch (widget.language) {
      'en' => 'English Voice',
      'es' => 'Voz en Español',
      'sw' => 'Swahili Voice',
      'zh' => 'Zhong Wen Yu Yin',
      'hi' => 'Hindi Voice',
      'fr' => 'Voix Française',
      'ru' => 'Russkiy Golos',
      'pt' => 'Voz Portuguesa',
      'de' => 'Deutsche Stimme',
      'ar' => 'Sawt Arabi',
      'tr' => 'Türkçe Ses',
      'suk' => 'Sukuma Voice',
      'gu' => 'Gujarati Voice',
      'ja' => '日本語の声',
      'ko' => '한국어 음성',
      'th' => 'เสียงไทย',
      'vi' => 'Giọng Việt',
      'id' => 'Suara Indonesia',
      'bn' => 'বাংলা ভয়েস',
      'pa' => 'ਪੰਜਾਬੀ ਆਵਾਜ਼',
      'ta' => 'தமிழ் குரல்',
      'my' => 'မြန်မာအသံ',
      'tl' => 'Boses Tagalog',
      'ro' => 'Voce Română',
      'el' => 'Ελληνική φωνή',
      'nl' => 'Nederlandse Stem',
      'pl' => 'Głos Polski',
      'uk' => 'Український голос',
      'it' => 'Voce Italiana',
      _ => 'English Voice',
    };
  }

  String get _flagEmoji {
    return switch (widget.language) {
      'en' => '🇬🇧',
      'es' => '🇪🇸',
      'sw' => '🇹🇿',
      'zh' => '🇨🇳',
      'hi' => '🇮🇳',
      'fr' => '🇫🇷',
      'ru' => '🇷🇺',
      'pt' => '🇵🇹',
      'de' => '🇩🇪',
      'ar' => '🇸🇦',
      'tr' => '🇹🇷',
      'suk' => '🇹🇿',
      'gu' => '🇮🇳',
      'ja' => '🇯🇵',
      'ko' => '🇰🇷',
      'th' => '🇹🇭',
      'vi' => '🇻🇳',
      'id' => '🇮🇩',
      'bn' => '🇧🇩',
      'pa' => '🇮🇳',
      'ta' => '🇮🇳',
      'my' => '🇲🇲',
      'tl' => '🇵🇭',
      'ro' => '🇷🇴',
      'el' => '🇬🇷',
      'nl' => '🇳🇱',
      'pl' => '🇵🇱',
      'uk' => '🇺🇦',
      'it' => '🇮🇹',
      _ => '🇬🇧',
    };
  }

  Color get _browColorForLanguage {
    return switch (widget.language) {
      'en' => const Color(0xFF46312B),
      'es' => const Color(0xFF3F281F),
      'sw' => const Color(0xFF342216),
      'zh' => const Color(0xFF56392F),
      'hi' => const Color(0xFF261C1C),
      'fr' => const Color(0xFF2C2121),
      'ru' => const Color(0xFF2C2020),
      'pt' => const Color(0xFF221919),
      'de' => const Color(0xFF3E261D),
      'ar' => const Color(0xFF23191B),
      _ => const Color(0xFF2A211C),
    };
  }

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
      _ => const Color(0xFF9A7361),
    };
  }

  double _getMouthHeight() {
    return switch (_currentViseme) {
      Viseme.closed => 0.02,
      Viseme.half => 0.04,
      Viseme.open => 0.06,
      Viseme.wide => 0.08,
      Viseme.round => 0.07,
      Viseme.smile => 0.03,
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

    const browRy = 0.090;
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

    final liftNorm = browLift / 28.0 * scale;
    final pos = Offset(
      center.dx + (rx - 0.5) * scale,
      center.dy + (ry - 0.5) * scale + liftNorm,
    );

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

  void _drawMouth(Canvas canvas, Offset center, double scale) {
    if (viseme == Viseme.closed) return;

    final mouthCenter = Offset(
      center.dx,
      center.dy + (0.374 - 0.5) * scale,
    );
    final width = 0.194 * scale;

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
    return switch (viseme) {
      Viseme.closed => 0.0,
      Viseme.half => 0.014,
      Viseme.open => 0.028,
      Viseme.wide => 0.038,
      Viseme.round => 0.032,
      Viseme.smile => 0.006,
    };
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
