#!/usr/bin/env bash
# ============================================================
# ADRI SPEED SPEECH — v2: expresiones faciales + traducción ES
# ============================================================
# REQUIERE haber corrido antes fix_adri_speed_speech.sh (v1).
# Ejecutar desde la raíz del proyecto:
#
#   chmod +x fix_adri_speed_speech_v2.sh
#   ./fix_adri_speed_speech_v2.sh
#
# Qué hace:
#   1. Crea dialogue_script_parser.dart — las 15 etiquetas de
#      expresión + el parser, compartido por todo el proyecto.
#   2. Extiende el AdriAvatarWidget REAL (el que ya usa chat_screen,
#      el de dibujo procedural con CustomPainter) para que dibuje
#      cejas y reaccione a las 15 expresiones, no solo a 4. Es un
#      cambio ADITIVO: si no se le pasa expresión, se comporta
#      exactamente igual que hoy (no rompe nada existente).
#   3. Actualiza los 9 prompts (ai_persona_config.dart) para que
#      Adri responda usando las etiquetas + agregue la traducción
#      al español después de un separador.
#   4. Reescribe ai_service.dart para devolver un objeto con:
#      texto con etiquetas, texto limpio, y traducción al español.
#   5. Conecta todo en chat_screen.dart: el avatar cambia de
#      expresión en sincronía con el habla (por fragmento de texto,
#      igual que el TTS), y cada burbuja de Adri muestra debajo la
#      traducción al español.
# ============================================================
set -euo pipefail

LIB="lib"
BACKUP_SUFFIX=".bak2_$(date +%Y%m%d_%H%M%S)"
backup() { cp "$1" "$1$BACKUP_SUFFIX"; }

AVATAR_DIR="$LIB/core/services/avatar"

echo "==> 1/5  dialogue_script_parser.dart — las 15 expresiones + parser (archivo nuevo)"
cat > "$AVATAR_DIR/dialogue_script_parser.dart" << 'EOF'
// ============================================================
// Las 15 expresiones faciales de Adri + el parser que convierte el
// texto etiquetado que devuelve el LLM en una secuencia de
// animación. Compartido por AdriAvatarWidget y por chat_screen.dart.
// ============================================================
import 'avatar_lip_sync_service.dart'; // reutiliza el enum Viseme existente

enum AvatarExpression {
  neutro,
  sonrisaCerrada,
  sonrisaAbierta,
  bocaA,
  bocaO,
  bocaE,
  bocaM,
  dudaPensativa,
  sorpresaPositiva,
  concentradaEscucha,
  enfasisFirme,
  alientoMotivador,
  preguntaInteres,
  comprensionAsentir,
  despedidaCalida,
}

/// Etiqueta `[TEXTO]` que usa el LLM -> valor del enum.
const Map<String, AvatarExpression> kExpressionTags = {
  'ROSTRO_NEUTRO': AvatarExpression.neutro,
  'SONRISA_CERRADA': AvatarExpression.sonrisaCerrada,
  'SONRISA_ABIERTA': AvatarExpression.sonrisaAbierta,
  'BOCA_A': AvatarExpression.bocaA,
  'BOCA_O': AvatarExpression.bocaO,
  'BOCA_E': AvatarExpression.bocaE,
  'BOCA_M': AvatarExpression.bocaM,
  'DUDA_PENSATIVA': AvatarExpression.dudaPensativa,
  'SORPRESA_POSITIVA': AvatarExpression.sorpresaPositiva,
  'CONCENTRADA_ESCUCHA': AvatarExpression.concentradaEscucha,
  'ENFASIS_FIRME': AvatarExpression.enfasisFirme,
  'ALIENTO_MOTIVADOR': AvatarExpression.alientoMotivador,
  'PREGUNTA_INTERES': AvatarExpression.preguntaInteres,
  'COMPRENSION_ASENTIR': AvatarExpression.comprensionAsentir,
  'DESPEDIDA_CALIDA': AvatarExpression.despedidaCalida,
};

/// Cómo se ve cada expresión: qué forma de boca (reusa el Viseme que
/// ya existía para el lip-sync por amplitud), cuánto se levantan las
/// cejas, qué tan abiertos están los ojos, y la inclinación de cabeza.
class ExpressionParams {
  final Viseme viseme;
  final double browLift;   // 0 = normal, hacia negativo = cejas suben
  final double eyeOpen;    // 0 = cerrado, 0.5 = normal, 1 = muy abierto
  final double headTiltDeg;
  const ExpressionParams(
    this.viseme, {
    this.browLift = 0,
    this.eyeOpen = 0.5,
    this.headTiltDeg = 0,
  });
}

const Map<AvatarExpression, ExpressionParams> kExpressionParams = {
  AvatarExpression.neutro: ExpressionParams(Viseme.closed),
  AvatarExpression.sonrisaCerrada:
      ExpressionParams(Viseme.smile, eyeOpen: 0.4),
  AvatarExpression.sonrisaAbierta:
      ExpressionParams(Viseme.wide, browLift: -3, eyeOpen: 0.55),
  AvatarExpression.bocaA: ExpressionParams(Viseme.wide, browLift: -2),
  AvatarExpression.bocaO: ExpressionParams(Viseme.round),
  AvatarExpression.bocaE: ExpressionParams(Viseme.half),
  AvatarExpression.bocaM: ExpressionParams(Viseme.closed),
  AvatarExpression.dudaPensativa: ExpressionParams(Viseme.closed,
      browLift: -4, eyeOpen: 0.45, headTiltDeg: 6),
  AvatarExpression.sorpresaPositiva: ExpressionParams(Viseme.round,
      browLift: -6, eyeOpen: 0.9),
  AvatarExpression.concentradaEscucha: ExpressionParams(Viseme.closed,
      eyeOpen: 0.45, headTiltDeg: 8),
  AvatarExpression.enfasisFirme:
      ExpressionParams(Viseme.wide, browLift: -3, eyeOpen: 0.6),
  AvatarExpression.alientoMotivador:
      ExpressionParams(Viseme.smile, eyeOpen: 0.3),
  AvatarExpression.preguntaInteres:
      ExpressionParams(Viseme.half, browLift: -3, eyeOpen: 0.6),
  AvatarExpression.comprensionAsentir:
      ExpressionParams(Viseme.smile, eyeOpen: 0.3),
  AvatarExpression.despedidaCalida:
      ExpressionParams(Viseme.wide, browLift: -2, eyeOpen: 0.3),
};

class DialogueCue {
  final String text;
  final AvatarExpression expression;
  const DialogueCue(this.text, this.expression);
}

class DialogueScriptParser {
  static final RegExp _tagRe = RegExp(r'\[([A-ZÁÉÍÓÚÑ_]+)\]');

  /// "[SONRISA_ABIERTA] Hola [BOCA_A] ¿qué tal?" -> lista de cues.
  static List<DialogueCue> parse(String raw) {
    final cues = <DialogueCue>[];
    var currentExpr = AvatarExpression.neutro;
    var lastEnd = 0;

    for (final match in _tagRe.allMatches(raw)) {
      final before = raw.substring(lastEnd, match.start).trim();
      if (before.isNotEmpty) cues.add(DialogueCue(before, currentExpr));
      currentExpr = kExpressionTags[match.group(1)!] ?? currentExpr;
      lastEnd = match.end;
    }
    final tail = raw.substring(lastEnd).trim();
    if (tail.isNotEmpty) cues.add(DialogueCue(tail, currentExpr));
    if (cues.isEmpty && raw.trim().isNotEmpty) {
      cues.add(DialogueCue(raw.trim(), AvatarExpression.neutro));
    }
    return cues;
  }

  /// Texto sin ninguna etiqueta [XXX] — es lo que se manda al TTS y
  /// lo que se muestra en la burbuja del chat.
  static String stripTags(String raw) =>
      raw.replaceAll(_tagRe, ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
}
EOF

echo "==> 2/5  adri_avatar_widget.dart — dibuja cejas y reacciona a las 15 expresiones"
backup "$AVATAR_DIR/adri_avatar_widget.dart"
python3 - "$AVATAR_DIR/adri_avatar_widget.dart" << 'PYEOF'
import sys
path = sys.argv[1]
s = open(path, encoding='utf-8').read()

s = s.replace(
    "import 'avatar_lip_sync_service.dart';",
    "import 'avatar_lip_sync_service.dart';\nimport 'dialogue_script_parser.dart';",
    1,
)

old_ctor = (
    "class AdriAvatarWidget extends StatefulWidget {\n"
    "  final bool isSpeaking;\n"
    "  final double amplitude;\n"
    "  final String language;\n"
    "  final VoidCallback? onLanguageTap;\n"
    "\n"
    "  const AdriAvatarWidget({\n"
    "    super.key,\n"
    "    this.isSpeaking = false,\n"
    "    this.amplitude = 0.0,\n"
    "    this.language = 'en',\n"
    "    this.onLanguageTap,\n"
    "  });"
)
new_ctor = (
    "class AdriAvatarWidget extends StatefulWidget {\n"
    "  final bool isSpeaking;\n"
    "  final double amplitude;\n"
    "  final String language;\n"
    "  final VoidCallback? onLanguageTap;\n"
    "  // Si viene distinto de null, pisa el viseme calculado por\n"
    "  // amplitud y dibuja la expresión completa (cejas, ojos, boca)\n"
    "  // de las 15 posiciones. Si es null, el widget se comporta como\n"
    "  // antes (solo boca por amplitud, sin cejas).\n"
    "  final AvatarExpression? expressionOverride;\n"
    "\n"
    "  const AdriAvatarWidget({\n"
    "    super.key,\n"
    "    this.isSpeaking = false,\n"
    "    this.amplitude = 0.0,\n"
    "    this.language = 'en',\n"
    "    this.onLanguageTap,\n"
    "    this.expressionOverride,\n"
    "  });"
)
assert old_ctor in s, "no se encontró el constructor de AdriAvatarWidget"
s = s.replace(old_ctor, new_ctor)

old_update = (
    "  void didUpdateWidget(covariant AdriAvatarWidget oldWidget) {\n"
    "    super.didUpdateWidget(oldWidget);\n"
    "    if (widget.isSpeaking && widget.amplitude > 0.05) {\n"
    "      _currentViseme = _lipSync.calculateViseme(widget.amplitude);\n"
    "    } else {\n"
    "      _currentViseme = Viseme.closed;\n"
    "    }\n"
    "\n"
    "    if (widget.isSpeaking != oldWidget.isSpeaking) {\n"
    "      setState(() {\n"
    "        _expression = widget.isSpeaking ? FacialExpression.happy : FacialExpression.neutral;\n"
    "      });\n"
    "    }\n"
    "  }"
)
new_update = (
    "  void didUpdateWidget(covariant AdriAvatarWidget oldWidget) {\n"
    "    super.didUpdateWidget(oldWidget);\n"
    "\n"
    "    if (widget.expressionOverride != null) {\n"
    "      final params = kExpressionParams[widget.expressionOverride]!;\n"
    "      _currentViseme = params.viseme;\n"
    "    } else if (widget.isSpeaking && widget.amplitude > 0.05) {\n"
    "      _currentViseme = _lipSync.calculateViseme(widget.amplitude);\n"
    "    } else {\n"
    "      _currentViseme = Viseme.closed;\n"
    "    }\n"
    "\n"
    "    if (widget.isSpeaking != oldWidget.isSpeaking) {\n"
    "      setState(() {\n"
    "        _expression = widget.isSpeaking ? FacialExpression.happy : FacialExpression.neutral;\n"
    "      });\n"
    "    }\n"
    "    if (widget.expressionOverride != oldWidget.expressionOverride) {\n"
    "      setState(() {});\n"
    "    }\n"
    "  }"
)
assert old_update in s, "no se encontró didUpdateWidget"
s = s.replace(old_update, new_update)

old_painter_call = (
    "                painter: _FacePainter(\n"
    "                  isSpeaking: widget.isSpeaking,\n"
    "                  isBlinking: _isBlinking || _blinkController.value > 0.5,\n"
    "                  viseme: _currentViseme,\n"
    "                  expression: _expression,\n"
    "                  amplitude: widget.amplitude,\n"
    "                ),"
)
new_painter_call = (
    "                painter: _FacePainter(\n"
    "                  isSpeaking: widget.isSpeaking || widget.expressionOverride != null,\n"
    "                  isBlinking: _isBlinking || _blinkController.value > 0.5,\n"
    "                  viseme: _currentViseme,\n"
    "                  expression: _expression,\n"
    "                  amplitude: widget.amplitude,\n"
    "                  browLift: widget.expressionOverride != null\n"
    "                      ? kExpressionParams[widget.expressionOverride]!.browLift\n"
    "                      : 0,\n"
    "                  eyeOpen: widget.expressionOverride != null\n"
    "                      ? kExpressionParams[widget.expressionOverride]!.eyeOpen\n"
    "                      : 0.5,\n"
    "                  headTiltDeg: widget.expressionOverride != null\n"
    "                      ? kExpressionParams[widget.expressionOverride]!.headTiltDeg\n"
    "                      : 0,\n"
    "                ),"
)
assert old_painter_call in s, "no se encontró la instanciación de _FacePainter"
s = s.replace(old_painter_call, new_painter_call)

old_painter_class_head = (
    "class _FacePainter extends CustomPainter {\n"
    "  final bool isSpeaking;\n"
    "  final bool isBlinking;\n"
    "  final Viseme viseme;\n"
    "  final FacialExpression expression;\n"
    "  final double amplitude;\n"
    "\n"
    "  _FacePainter({\n"
    "    required this.isSpeaking,\n"
    "    required this.isBlinking,\n"
    "    required this.viseme,\n"
    "    required this.expression,\n"
    "    required this.amplitude,\n"
    "  });\n"
    "\n"
    "  static const Color _lipColor = Color(0xFFCC8E8E);\n"
    "  static const Color _eyeColor = Color(0xFF2D1B4E);\n"
    "\n"
    "  @override\n"
    "  void paint(Canvas canvas, Size size) {\n"
    "    final center = Offset(size.width / 2, size.height / 2);\n"
    "    final scale = size.width;\n"
    "\n"
    "    if (!isBlinking) {\n"
    "      _drawEye(canvas, center, scale, 0.40, 0.315);\n"
    "      _drawEye(canvas, center, scale, 0.60, 0.315);\n"
    "    } else {\n"
    "      _drawClosedEye(canvas, center, scale, 0.40, 0.315);\n"
    "      _drawClosedEye(canvas, center, scale, 0.60, 0.315);\n"
    "    }\n"
    "\n"
    "    if (isSpeaking) {\n"
    "      _drawMouth(canvas, center, scale);\n"
    "    }\n"
    "  }"
)
new_painter_class_head = (
    "class _FacePainter extends CustomPainter {\n"
    "  final bool isSpeaking;\n"
    "  final bool isBlinking;\n"
    "  final Viseme viseme;\n"
    "  final FacialExpression expression;\n"
    "  final double amplitude;\n"
    "  final double browLift;\n"
    "  final double eyeOpen;\n"
    "  final double headTiltDeg;\n"
    "\n"
    "  _FacePainter({\n"
    "    required this.isSpeaking,\n"
    "    required this.isBlinking,\n"
    "    required this.viseme,\n"
    "    required this.expression,\n"
    "    required this.amplitude,\n"
    "    this.browLift = 0,\n"
    "    this.eyeOpen = 0.5,\n"
    "    this.headTiltDeg = 0,\n"
    "  });\n"
    "\n"
    "  static const Color _lipColor = Color(0xFFCC8E8E);\n"
    "  static const Color _eyeColor = Color(0xFF2D1B4E);\n"
    "  static const Color _browColor = Color(0xFF4A3220);\n"
    "\n"
    "  @override\n"
    "  void paint(Canvas canvas, Size size) {\n"
    "    canvas.save();\n"
    "    final pivot = Offset(size.width / 2, size.height / 2);\n"
    "    canvas.translate(pivot.dx, pivot.dy);\n"
    "    canvas.rotate(headTiltDeg * 3.1415926535 / 180);\n"
    "    canvas.translate(-pivot.dx, -pivot.dy);\n"
    "\n"
    "    final center = Offset(size.width / 2, size.height / 2);\n"
    "    final scale = size.width;\n"
    "\n"
    "    final effectivelyBlinking = isBlinking && eyeOpen < 0.75;\n"
    "    if (!effectivelyBlinking) {\n"
    "      _drawEye(canvas, center, scale, 0.40, 0.315);\n"
    "      _drawEye(canvas, center, scale, 0.60, 0.315);\n"
    "    } else {\n"
    "      _drawClosedEye(canvas, center, scale, 0.40, 0.315);\n"
    "      _drawClosedEye(canvas, center, scale, 0.60, 0.315);\n"
    "    }\n"
    "\n"
    "    _drawEyebrow(canvas, center, scale, 0.40, 0.315);\n"
    "    _drawEyebrow(canvas, center, scale, 0.60, 0.315);\n"
    "\n"
    "    if (isSpeaking) {\n"
    "      _drawMouth(canvas, center, scale);\n"
    "    }\n"
    "\n"
    "    canvas.restore();\n"
    "  }\n"
    "\n"
    "  void _drawEyebrow(\n"
    "      Canvas canvas, Offset center, double scale, double rx, double ry) {\n"
    "    final paint = Paint()\n"
    "      ..color = _browColor.withOpacity(0.7)\n"
    "      ..style = PaintingStyle.stroke\n"
    "      ..strokeWidth = 2.5\n"
    "      ..strokeCap = StrokeCap.round;\n"
    "\n"
    "    final liftNorm = browLift / 120.0 * scale;\n"
    "    final pos = Offset(\n"
    "      center.dx + (rx - 0.5) * scale,\n"
    "      center.dy + (ry - 0.5) * scale - 0.075 * scale + liftNorm,\n"
    "    );\n"
    "\n"
    "    canvas.drawLine(\n"
    "      Offset(pos.dx - 0.045 * scale, pos.dy),\n"
    "      Offset(pos.dx + 0.045 * scale, pos.dy),\n"
    "      paint,\n"
    "    );\n"
    "  }"
)
assert old_painter_class_head in s, "no se encontró el bloque de _FacePainter/paint()"
s = s.replace(old_painter_class_head, new_painter_class_head)

old_draw_eye = (
    "  void _drawEye(Canvas canvas, Offset center, double scale, double rx, double ry) {\n"
    "    final eyePaint = Paint()\n"
    "      ..color = _eyeColor\n"
    "      ..style = PaintingStyle.fill;\n"
    "\n"
    "    final pos = Offset(\n"
    "      center.dx + (rx - 0.5) * scale,\n"
    "      center.dy + (ry - 0.5) * scale,\n"
    "    );\n"
    "\n"
    "    canvas.drawCircle(pos, 0.037 * scale, eyePaint);"
)
new_draw_eye = (
    "  void _drawEye(Canvas canvas, Offset center, double scale, double rx, double ry) {\n"
    "    final eyePaint = Paint()\n"
    "      ..color = _eyeColor\n"
    "      ..style = PaintingStyle.fill;\n"
    "\n"
    "    final pos = Offset(\n"
    "      center.dx + (rx - 0.5) * scale,\n"
    "      center.dy + (ry - 0.5) * scale,\n"
    "    );\n"
    "\n"
    "    final radius = (0.028 + eyeOpen * 0.018) * scale;\n"
    "    canvas.drawCircle(pos, radius, eyePaint);"
)
assert old_draw_eye in s, "no se encontró _drawEye"
s = s.replace(old_draw_eye, new_draw_eye)

open(path, 'w', encoding='utf-8').write(s)
print("adri_avatar_widget.dart actualizado (15 expresiones + cejas).")
PYEOF

echo "==> 3/5  ai_persona_config.dart — instrucciones de etiquetas + traducción ES en los 9 idiomas"
backup "$LIB/core/config/ai_persona_config.dart"
python3 - "$LIB/core/config/ai_persona_config.dart" << 'PYEOF'
import sys
path = sys.argv[1]
s = open(path, encoding='utf-8').read()

FORMAT_BLOCK = (
    "Response format (MANDATORY, always follow exactly):\n"
    "1. Write your reply in the target language, inserting facial-expression\n"
    "   tags INSIDE the text (not all at the end) using ONLY these exact\n"
    "   tags: [ROSTRO_NEUTRO] [SONRISA_CERRADA] [SONRISA_ABIERTA] [BOCA_A]\n"
    "   [BOCA_O] [BOCA_E] [BOCA_M] [DUDA_PENSATIVA] [SORPRESA_POSITIVA]\n"
    "   [CONCENTRADA_ESCUCHA] [ENFASIS_FIRME] [ALIENTO_MOTIVADOR]\n"
    "   [PREGUNTA_INTERES] [COMPRENSION_ASENTIR] [DESPEDIDA_CALIDA]\n"
    "2. Then write the exact line: ===ES===\n"
    "3. Then write a natural Spanish translation of your reply, with NO\n"
    "   tags at all (plain text only).\n"
    "Example:\n"
    "[SONRISA_ABIERTA] Hello! [BOCA_A] How are you today?\n"
    "===ES===\n"
    "¡Hola! ¿Cómo estás hoy?"
)

# Ancla EXACTA de cierre de cada uno de los 9 prompts (la última línea
# de cada idioma en systemPrompts, verificada contra el archivo real
# generado por v1). Se inserta el bloque justo después de esa línea,
# sin tocar la constante _rules ni ningún otro '''  del archivo.
anchors = [
    "Current mood: helpful and encouraging.",
    "Msimbo wa sasa: msaada na mstahimilivu.",
    "Dang qian zhuang tai: le yu zhu ren qie gu li ren xin.",
    "Vartamaan mood: sahayak aur protsahit karne wala.",
    "Humeur actuelle : serviable et encourageante.",
    "Tekushcheye nastroyeniye: otzyvchivaya i obodryayushchaya.",
    "Humor atual: prestativa e encorajadora.",
    "Aktuelle Stimmung: hilfsbereit und ermutigend.",
    "Al-mazaj al-hali: mufida wa mushajjia.",
]

count = 0
for anchor in anchors:
    if anchor not in s:
        print(f"AVISO: no se encontró el ancla de cierre: {anchor!r}", file=sys.stderr)
        continue
    s = s.replace(anchor, anchor + "\n" + FORMAT_BLOCK, 1)
    count += 1

open(path, 'w', encoding='utf-8').write(s)
print(f"ai_persona_config.dart: bloque de formato insertado en {count}/9 prompts.")
PYEOF

echo "==> 4/5  ai_service.dart — AdriResponse (texto con etiquetas + limpio + traducción ES)"
backup "$LIB/core/services/ai_service.dart"
cat > "$LIB/core/services/ai_service.dart" << 'EOF'
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../config/ai_persona_config.dart';
import '../utils/logger.dart';

/// Resultado de una respuesta de Adri:
///  - taggedText: texto con las etiquetas [SONRISA_ABIERTA] etc,
///    tal como lo generó el LLM. Se usa para animar el avatar.
///  - cleanText: el mismo texto SIN etiquetas. Se manda al TTS y se
///    muestra en la burbuja del chat.
///  - spanishTranslation: traducción al español, siempre presente
///    (aunque el idioma seleccionado sea otro), para mostrarse debajo
///    del texto principal en la burbuja.
class AdriResponse {
  final String taggedText;
  final String cleanText;
  final String spanishTranslation;
  const AdriResponse({
    required this.taggedText,
    required this.cleanText,
    required this.spanishTranslation,
  });
}

const String _kSpanishFallback =
    'Lo siento, no pude entender eso. ¿Puedes intentarlo de nuevo?';

class AIService {
  final String _baseUrl;

  AIService({String apiKey = '', String? baseUrl})
      : _baseUrl = baseUrl ?? ApiConfig.backendBaseUrl;

  Future<AdriResponse> sendMessage(String prompt, {String? lang}) async {
    final effectiveLang = lang ?? 'en';
    try {
      final systemPrompt = AIPersonaConfig.systemPromptFor(effectiveLang);

      final response = await http
          .post(
            Uri.parse('$_baseUrl/chat'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'messages': [
                {'role': 'system', 'content': systemPrompt},
                {'role': 'user', 'content': prompt}
              ],
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final raw = data['text']?.toString() ??
            AIPersonaConfig.fallbackMessageFor(effectiveLang);
        return _parseDualLanguage(raw, effectiveLang);
      } else {
        Logger.error('AI Service error: ${response.statusCode}');
        return _fallbackResponse(effectiveLang);
      }
    } catch (e, st) {
      Logger.error('AI Service exception', error: e, stackTrace: st);
      return _fallbackResponse(effectiveLang);
    }
  }

  /// Separa "[tags] texto ===ES=== traducción" en sus 3 componentes.
  /// Si el modelo no incluyó el separador (puede pasar, ningún LLM es
  /// 100% consistente con el formato), se degrada con gracia: se usa
  /// todo el texto como respuesta y se deja la traducción vacía en
  /// vez de romper la conversación.
  AdriResponse _parseDualLanguage(String raw, String lang) {
    const delimiter = '===ES===';
    final idx = raw.indexOf(delimiter);

    String taggedPart;
    String spanishPart;
    if (idx == -1) {
      Logger.error(
          'AI Service: el modelo no devolvió el separador $delimiter (idioma=$lang). '
          'Revisar el prompt o el proveedor LLM en uso.');
      taggedPart = raw;
      spanishPart = '';
    } else {
      taggedPart = raw.substring(0, idx);
      spanishPart = raw.substring(idx + delimiter.length);
    }

    final cleanTagged = AIPersonaConfig.filterResponse(taggedPart);
    final cleanSpanish = AIPersonaConfig.filterResponse(spanishPart);

    return AdriResponse(
      taggedText: cleanTagged,
      cleanText: _stripTags(cleanTagged),
      spanishTranslation: cleanSpanish,
    );
  }

  AdriResponse _fallbackResponse(String lang) {
    final msg = AIPersonaConfig.fallbackMessageFor(lang);
    return AdriResponse(
      taggedText: msg,
      cleanText: msg,
      spanishTranslation: _kSpanishFallback,
    );
  }

  static final RegExp _tagRe = RegExp(r'\[([A-ZÁÉÍÓÚÑ_]+)\]');
  String _stripTags(String raw) =>
      raw.replaceAll(_tagRe, ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
}
EOF

echo "==> 5/5  chat_screen.dart — orquesta avatar+TTS por etiquetas y muestra la traducción ES"
backup "$LIB/features/vocabulary/presentation/screens/chat_screen.dart"
python3 - "$LIB/features/vocabulary/presentation/screens/chat_screen.dart" << 'PYEOF'
import sys
path = sys.argv[1]
s = open(path, encoding='utf-8').read()

s = s.replace(
    "import '../../../../core/services/avatar/adri_avatar_widget.dart';",
    "import '../../../../core/services/avatar/adri_avatar_widget.dart';\n"
    "import '../../../../core/services/avatar/dialogue_script_parser.dart';",
    1,
)

old_field = "  String _currentLanguage = 'en';\n  bool _isProcessing = false;"
new_field = (
    "  String _currentLanguage = 'en';\n"
    "  bool _isProcessing = false;\n"
    "  AvatarExpression? _currentAvatarExpression;"
)
assert old_field in s, "no se encontró el bloque de campos de estado"
s = s.replace(old_field, new_field)

old_send = '''  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isProcessing) return;

    _clearInputCompletely();

    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _isProcessing = true;
    });
    _scrollToBottom();

    _speechState.setState_(AdriState.waiting);

    final response = await _aiService.sendMessage(text, lang: _currentLanguage);

    if (response != null) {
      setState(() {
        _messages.add({'role': 'adri', 'text': response});
      });
      _scrollToBottom();

      await _ttsService.precache(response);
      await Future.delayed(const Duration(milliseconds: 200));

      _speechState.setState_(AdriState.speaking);
      await _ttsService.speakResponse(response);

      _speechState.setState_(AdriState.idle);
    }

    setState(() => _isProcessing = false);
  }'''

new_send = '''  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isProcessing) return;

    _clearInputCompletely();

    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _isProcessing = true;
    });
    _scrollToBottom();

    _speechState.setState_(AdriState.waiting);

    final adriResponse = await _aiService.sendMessage(text, lang: _currentLanguage);

    setState(() {
      _messages.add({
        'role': 'adri',
        'text': adriResponse.cleanText,
        'translation': adriResponse.spanishTranslation,
      });
    });
    _scrollToBottom();

    await _ttsService.precache(adriResponse.cleanText);
    await Future.delayed(const Duration(milliseconds: 200));

    _speechState.setState_(AdriState.speaking);
    await _playTaggedResponse(adriResponse);
    _speechState.setState_(AdriState.idle);

    setState(() => _isProcessing = false);
  }

  /// Reproduce el audio (TTS) y anima el avatar en paralelo: el
  /// avatar va cambiando de expresión por fragmento de texto (misma
  /// estimación de duración por cantidad de caracteres que usa el
  /// motor de diálogo), mientras el TTS dice el texto completo en
  /// una sola locución (para que no suene cortado).
  Future<void> _playTaggedResponse(AdriResponse response) async {
    final cues = DialogueScriptParser.parse(response.taggedText);
    const charsPerSecond = 14.0;

    final ttsFuture = _ttsService.speakResponse(response.cleanText);

    for (final cue in cues) {
      if (!mounted) break;
      setState(() => _currentAvatarExpression = cue.expression);
      final ms = (cue.text.length / charsPerSecond * 1000)
          .clamp(180, 4000)
          .toInt();
      await Future.delayed(Duration(milliseconds: ms));
    }

    await ttsFuture;
    if (mounted) setState(() => _currentAvatarExpression = null);
  }'''

assert old_send in s, "no se encontró _sendMessage en el formato esperado"
s = s.replace(old_send, new_send)

old_avatar = '''            child: AdriAvatarWidget(
              key: UniqueKey(),
              isSpeaking: speechState.state == AdriState.speaking,
              amplitude: speechState.amplitude,
              language: _currentLanguage,
              onLanguageTap: _showLanguageSelector,
            ),'''
new_avatar = '''            child: AdriAvatarWidget(
              key: UniqueKey(),
              isSpeaking: speechState.state == AdriState.speaking,
              amplitude: speechState.amplitude,
              language: _currentLanguage,
              onLanguageTap: _showLanguageSelector,
              expressionOverride: _currentAvatarExpression,
            ),'''
assert old_avatar in s, "no se encontró la instanciación de AdriAvatarWidget"
s = s.replace(old_avatar, new_avatar)

old_bubble_call = '''                return _ChatBubble(
                  text: msg['text'],
                  isUser: isUser,
                );'''
new_bubble_call = '''                return _ChatBubble(
                  text: msg['text'],
                  isUser: isUser,
                  translation: msg['translation'],
                );'''
assert old_bubble_call in s, "no se encontró la construcción de _ChatBubble en el ListView"
s = s.replace(old_bubble_call, new_bubble_call)

old_bubble_class = '''class _ChatBubble extends StatelessWidget {
  final String text;
  final bool isUser;

  const _ChatBubble({required this.text, required this.isUser});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isUser
              ? const Color(0xFF1E3A5F)
              : const Color(0xFF7C3AED),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            height: 1.4,
          ),
        ),'''
new_bubble_class = '''class _ChatBubble extends StatelessWidget {
  final String text;
  final bool isUser;
  final String? translation;

  const _ChatBubble({required this.text, required this.isUser, this.translation});

  @override
  Widget build(BuildContext context) {
    final hasTranslation =
        !isUser && translation != null && translation!.trim().isNotEmpty;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isUser
              ? const Color(0xFF1E3A5F)
              : const Color(0xFF7C3AED),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                height: 1.4,
              ),
            ),
            if (hasTranslation) ...[
              const SizedBox(height: 6),
              Container(height: 1, color: Colors.white.withOpacity(0.2)),
              const SizedBox(height: 6),
              Text(
                translation!,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.75),
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  height: 1.3,
                ),
              ),
            ],
          ],
        ),'''
assert old_bubble_class in s, "no se encontró la clase _ChatBubble en el formato esperado"
s = s.replace(old_bubble_class, new_bubble_class)

open(path, 'w', encoding='utf-8').write(s)
print("chat_screen.dart actualizado (expresión sincronizada + traducción ES).")
PYEOF

echo ""
echo "============================================================"
echo " v2 aplicado. Copias de seguridad con sufijo $BACKUP_SUFFIX"
echo " Siguiente paso: flutter pub get && revisar que compile."
echo "============================================================"
