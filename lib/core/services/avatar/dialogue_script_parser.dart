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
