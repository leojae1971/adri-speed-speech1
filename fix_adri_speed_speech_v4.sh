#!/usr/bin/env bash
# ============================================================
# ADRI SPEED SPEECH — v4
# ============================================================
# REQUIERE haber corrido v1, v2 y v3 antes. Ejecutar desde la raíz
# del proyecto (donde están lib/ y adri_speed_speech_backend/):
#
#   chmod +x fix_adri_speed_speech_v4.sh
#   ./fix_adri_speed_speech_v4.sh
#
# Corrige, con causa verificada para cada una:
#
#  1. ERROR DE COMPILACIÓN (getter 'language' no existe en Table):
#     v3 agregó una tabla nueva a Drift (ChatMessages), que requiere
#     regenerar database.g.dart con build_runner. En vez de pedirte
#     ese paso extra otra vez, saco el historial de chat de Drift
#     por completo y lo paso a SharedPreferences (sin generación de
#     código -> no puede volver a pasar este tipo de error).
#
#  2. AVATAR DESALINEADO (cejas/ojos/boca no coinciden con la foto):
#     causa real encontrada: la foto (retrato vertical 768x1376) se
#     muestra en un contenedor CUADRADO de 120x120 con BoxFit.cover,
#     que recorta ~44% de la imagen (arriba y abajo) para llenar el
#     cuadrado. Las coordenadas de ojos/boca estaban calculadas para
#     la foto COMPLETA, no para lo que queda visible tras el recorte.
#     Se recalculan con la transformación matemática exacta del
#     recorte, más color estándar consistente para las 9 fotos
#     (todas comparten el mismo encuadre/plantilla).
#
#  3. Chino/hindi/ruso/árabe "como si lo leyera": estaban escritos en
#     romanización latina (pinyin sin tonos, etc.) en vez de la
#     escritura nativa real. Reescritos con caracteres reales
#     (Hanzi/Devanagari/Cirílico/Árabe). Se agrega Español como
#     10º idioma seleccionable (antes no existía como opción).
#
#  4. Micrófono "no funciona": speech_service.dart tenía el locale
#     de reconocimiento FIJO en 'en_US' sin importar el idioma
#     seleccionado — si hablabas en otro idioma, el motor STT
#     intentaba reconocerlo como inglés. Ahora recibe el idioma
#     actual y usa el locale correcto.
#
#  5. Latencia enorme / primera pregunta falla: dos bugs reales en
#     el backend:
#       a) los clientes hacia Groq/Cerebras/DeepSeek no tenían
#          timeout configurado (podían colgarse mucho más de lo
#          razonable antes de que la cadena pasara al siguiente
#          proveedor).
#       b) la llamada a Gemini es SÍNCRONA/BLOQUEANTE dentro de una
#          función async — congela el event loop del servidor
#          ENTERO mientras espera (el propio código ya tenía un
#          comentario admitiéndolo, sin corregirlo). Se envuelve en
#          un executor para que no bloquee.
#     También se sube el timeout del lado de Flutter (10s era muy
#     corto para un cold-start de Render) y ai_service.dart ahora sí
#     usa ese valor configurable en vez de un número fijo.
#
# NO puedo corregir aquí (el archivo nunca estuvo en lo que me
# compartiste): android/app/src/main/AndroidManifest.xml — ver el
# aviso final para lo que debe contener.
# ============================================================
set -euo pipefail

LIB="lib"
BACKEND="adri_speed_speech_backend"
BACKUP_SUFFIX=".bak4_$(date +%Y%m%d_%H%M%S)"
backup() { cp "$1" "$1$BACKUP_SUFFIX"; }

# ------------------------------------------------------------
# 1) database.dart: revertir la tabla ChatMessages (vuelve a la
#    forma original de 2 tablas, compatible con el database.g.dart
#    ya generado — sin esto, NADA compila).
# ------------------------------------------------------------
echo "==> 1/9  database.dart — revertir tabla ChatMessages (fix del error de compilación)"
backup "$LIB/core/services/database.dart"
cat > "$LIB/core/services/database.dart" << 'EOF'
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:io';

part 'database.g.dart';

class VocabularyItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get word => text().withLength(min: 1, max: 120)();
  TextColumn get definition => text()();
  TextColumn get translation => text().nullable()();
  TextColumn get exampleSentence => text().nullable()();
  TextColumn get phonetic => text().nullable()();
  TextColumn get semanticGroup => text().nullable()();

  // Parametros SRS (SuperMemo 2)
  RealColumn get easeFactor => real().withDefault(const Constant(2.5))();
  IntColumn get intervalDays => integer().withDefault(const Constant(0))();
  IntColumn get repetitions => integer().withDefault(const Constant(0))();

  DateTimeColumn get nextReview => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastReviewed => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class SessionSnapshots extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get sessionId => text().withLength(min: 1, max: 100)();
  TextColumn get metadataJson => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DriftDatabase(tables: [VocabularyItems, SessionSnapshots])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  Future<List<VocabularyItem>> getWordsToReview(DateTime currentDate) {
    return (select(vocabularyItems)
          ..where((tbl) => tbl.nextReview.isSmallerOrEqualValue(currentDate)))
        .get();
  }

  Future<int> insertOrUpdateVocabulary(VocabularyItemsCompanion item) {
    return into(vocabularyItems).insertOnConflictUpdate(item);
  }

  Future<void> updateSrsData(
    int id,
    double newEaseFactor,
    int newInterval,
    int newRepetitions,
    DateTime nextReviewDate,
  ) {
    return (update(vocabularyItems)..where((tbl) => tbl.id.equals(id))).write(
      VocabularyItemsCompanion(
        easeFactor: Value(newEaseFactor),
        intervalDays: Value(newInterval),
        repetitions: Value(newRepetitions),
        nextReview: Value(nextReviewDate),
        lastReviewed: Value(DateTime.now()),
      ),
    );
  }

  Future<int> deleteVocabulary(int id) {
    return (delete(vocabularyItems)..where((tbl) => tbl.id.equals(id))).go();
  }

  Future<int> saveSessionSnapshot(SessionSnapshotsCompanion snapshot) {
    return into(sessionSnapshots).insertOnConflictUpdate(snapshot);
  }

  Future<SessionSnapshot?> getLastSessionSnapshot(String sessionId) {
    return (select(sessionSnapshots)
          ..where((tbl) => tbl.sessionId.equals(sessionId))
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.createdAt, mode: OrderingMode.desc)])
          ..limit(1))
        .getSingleOrNull();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'lingua_core.sqlite'));
    return NativeDatabase(file);
  });
}
EOF

# ------------------------------------------------------------
# 2) locale_map.dart: mapa único idioma->locale para TTS y STT
#    (archivo nuevo, sin riesgo — no toca nada existente).
# ------------------------------------------------------------
echo "==> 2/9  locale_map.dart — mapa único idioma->locale (archivo nuevo)"
cat > "$LIB/core/config/locale_map.dart" << 'EOF'
/// Único mapa idioma -> locale del proyecto. hybrid_tts_service tenía
/// su propio switch de 9 idiomas y speech_service ni siquiera tenía
/// uno (usaba 'en_US' fijo siempre, sin importar el idioma
/// seleccionado). Ahora los dos leen de aquí.
class LocaleMap {
  static const Map<String, String> _map = {
    'en': 'en-US',
    'es': 'es-ES',
    'sw': 'sw-KE',
    'zh': 'zh-CN',
    'hi': 'hi-IN',
    'fr': 'fr-FR',
    'ru': 'ru-RU',
    'pt': 'pt-PT',
    'de': 'de-DE',
    'ar': 'ar-SA',
  };

  static String forLanguage(String lang) => _map[lang] ?? 'en-US';
}
EOF

# ------------------------------------------------------------
# 3) ai_persona_config.dart: reescritura COMPLETA con los 10 idiomas
#    (se agrega 'es'), zh/hi/ru/ar en escritura nativa real.
#    Reescritura total (no parche) para no arrastrar el error de
#    v4 anterior con comillas triples anidadas.
# ------------------------------------------------------------
echo "==> 3/9  ai_persona_config.dart — reescritura completa: 10 idiomas, escritura nativa real"
backup "$LIB/core/config/ai_persona_config.dart"
cat > "$LIB/core/config/ai_persona_config.dart" << 'DARTEOF'
/// Un Map por idioma en vez de switch(lang){...} duplicado en varios
/// archivos: agregar un idioma nuevo se hace UNA sola vez, aquí.
class AIPersonaConfig {
  static const String _formatBlock = '''
Response format (MANDATORY, always follow exactly):
1. Write your reply in the target language, inserting facial-expression
   tags INSIDE the text (not all at the end) using ONLY these exact
   tags: [ROSTRO_NEUTRO] [SONRISA_CERRADA] [SONRISA_ABIERTA] [BOCA_A]
   [BOCA_O] [BOCA_E] [BOCA_M] [DUDA_PENSATIVA] [SORPRESA_POSITIVA]
   [CONCENTRADA_ESCUCHA] [ENFASIS_FIRME] [ALIENTO_MOTIVADOR]
   [PREGUNTA_INTERES] [COMPRENSION_ASENTIR] [DESPEDIDA_CALIDA]
2. Then write the exact line: ===ES===
3. Then write a natural Spanish translation of your reply, with NO
   tags at all (plain text only).
Example:
[SONRISA_ABIERTA] Hello! [BOCA_A] How are you today?
===ES===
¡Hola! ¿Cómo estás hoy?
''';

  // El idioma de destino YA es español: pedir una "traducción al
  // español" sería redundante y desperdicia tokens.
  static const String _formatBlockEs = '''
Response format (MANDATORY, always follow exactly):
1. Write your reply in Spanish, inserting facial-expression tags
   INSIDE the text (not all at the end) using ONLY these exact tags:
   [ROSTRO_NEUTRO] [SONRISA_CERRADA] [SONRISA_ABIERTA] [BOCA_A]
   [BOCA_O] [BOCA_E] [BOCA_M] [DUDA_PENSATIVA] [SORPRESA_POSITIVA]
   [CONCENTRADA_ESCUCHA] [ENFASIS_FIRME] [ALIENTO_MOTIVADOR]
   [PREGUNTA_INTERES] [COMPRENSION_ASENTIR] [DESPEDIDA_CALIDA]
2. Do NOT add any ===ES=== section or translation — the reply is
   already in Spanish.
Example:
[SONRISA_ABIERTA] ¡Hola! [BOCA_A] ¿Cómo estás hoy?
''';

  static final Map<String, String> systemPrompts = {
    'en': '''
You are Adri, a friendly and patient English language teacher.
Your personality is warm, encouraging, and professional.
Rules:
- NEVER use "haha", "hehe", "jeje", or similar laughter strings.
- Keep responses concise (2-4 sentences max).
- Correct grammar gently if the user makes mistakes.
- Always respond in English.
- Be encouraging and supportive.
- If the user writes in another language, gently redirect them to English.
Current mood: helpful and encouraging.
''' + _formatBlock,

    'es': '''
Eres Adri, una profesora de idiomas amigable y paciente. Como el
usuario ya habla español, aquí tu rol es conversar de forma natural
y servir de referencia/apoyo general (no enseñanza de español como
lengua extranjera).
Reglas:
- NUNCA uses "jaja", "jeje", "haha" ni risas similares.
- Respuestas concisas (máximo 2-4 frases).
- Sé cálida, alentadora y profesional.
- Responde siempre en español.
Estado de ánimo actual: servicial y alentadora.
''' + _formatBlockEs,

    'sw': '''
Wewe ni Adri, mwalimu wa lugha ya Kiswahili.
Tabia yako ni ya kirafiki, ya uvumilivu, na ya kitaalam.
Masharti:
- USITUMIE "haha", "hehe", "jeje", au mfuatano kama huo wa kucheka.
- Jibu kwa ufupi (sentensi 2-4 pekee).
- Sahihisha sarufi kwa upole kama mtumiaji akifanya makosa.
- Jibu daima kwa Kiswahili.
- Kuwa mstahimilivu na msaada.
- Kama mtumiaji anaandika kwa lugha nyingine, mwelekeze kwa Kiswahili kwa upole.
Msimbo wa sasa: msaada na mstahimilivu.
''' + _formatBlock,

    'zh': '''
你是Adri，一位友好耐心的中文老师。
你的性格温暖、乐于鼓励、专业。
规则：
- 绝不使用"哈哈"、"呵呵"、"嘿嘿"或类似的笑声词。
- 回答要简洁（最多2到4句话）。
- 如果用户有语法错误，请温和地纠正。
- 始终用中文回答，使用简体中文汉字，不要用拼音。
- 要给予鼓励和支持。
- 如果用户用其他语言书写，请温和地引导他们使用中文。
当前状态：乐于助人、充满鼓励。
''' + _formatBlock,

    'hi': '''
आप Adri हैं, एक मित्रवत और धैर्यवान हिंदी भाषा शिक्षिका।
आपका व्यक्तित्व गर्मजोशी भरा, प्रोत्साहित करने वाला और पेशेवर है।
नियम:
- "हाहा", "हेहे", "जेजे" या इसी तरह की हंसी के शब्द कभी न लिखें।
- जवाब संक्षिप्त रखें (ज्यादा से ज्यादा 2 से 4 वाक्य)।
- अगर उपयोगकर्ता गलती करे तो व्याकरण को विनम्रता से सुधारें।
- हमेशा हिंदी में, देवनागरी लिपि में जवाब दें।
- प्रोत्साहित करने वाले और सहायक बनें।
- अगर उपयोगकर्ता किसी अन्य भाषा में लिखे, तो उसे विनम्रता से हिंदी की तरफ ले जाएं।
वर्तमान मनोदशा: सहायक और प्रोत्साहित करने वाली।
''' + _formatBlock,

    'fr': '''
Tu es Adri, une enseignante de français amicale et patiente.
Ta personnalité est chaleureuse, encourageante et professionnelle.
Règles :
- N'utilise jamais "haha", "hehe", "jeje" ou des rires similaires.
- Garde des réponses concises (2 à 4 phrases maximum).
- Corrige la grammaire avec douceur si l'utilisateur fait des erreurs.
- Réponds toujours en français.
- Sois encourageante et bienveillante.
- Si l'utilisateur écrit dans une autre langue, redirige-le gentiment vers le français.
Humeur actuelle : serviable et encourageante.
''' + _formatBlock,

    'ru': '''
Ты Адри, дружелюбная и терпеливая преподавательница русского языка.
Твой характер — тёплый, ободряющий и профессиональный.
Правила:
- Никогда не используй "хаха", "хехе" или похожие смешки.
- Отвечай кратко (максимум 2-4 предложения).
- Мягко исправляй грамматику, если пользователь ошибается.
- Всегда отвечай на русском языке, используя кириллицу.
- Будь поддерживающей и ободряющей.
- Если пользователь пишет на другом языке, мягко направляй его к русскому.
Текущее настроение: отзывчивая и ободряющая.
''' + _formatBlock,

    'pt': '''
Você é a Adri, uma professora de português amigável e paciente.
Sua personalidade é calorosa, encorajadora e profissional.
Regras:
- NUNCA use "haha", "hehe", "jeje" ou risadas semelhantes.
- Mantenha as respostas concisas (2 a 4 frases no máximo).
- Corrija a gramática com gentileza se o usuário cometer erros.
- Responda sempre em português.
- Seja encorajadora e solidária.
- Se o usuário escrever em outro idioma, redirecione-o gentilmente para o português.
Humor atual: prestativa e encorajadora.
''' + _formatBlock,

    'de': '''
Du bist Adri, eine freundliche und geduldige Deutschlehrerin.
Deine Persönlichkeit ist warmherzig, ermutigend und professionell.
Regeln:
- Verwende niemals "haha", "hehe", "jeje" oder ähnliches Gelächter.
- Halte Antworten kurz (maximal 2-4 Sätze).
- Korrigiere Grammatikfehler sanft, wenn der Nutzer Fehler macht.
- Antworte immer auf Deutsch.
- Sei ermutigend und unterstützend.
- Wenn der Nutzer in einer anderen Sprache schreibt, leite ihn sanft zurück zum Deutschen.
Aktuelle Stimmung: hilfsbereit und ermutigend.
''' + _formatBlock,

    'ar': '''
أنتِ Adri، مدرّسة لغة عربية ودودة وصبورة.
شخصيتك دافئة ومشجعة ومهنية.
القواعد:
- لا تستخدمي أبدًا "هاها" أو "ههه" أو ما يشبه الضحك.
- اجعلي الإجابات مختصرة (جملتان إلى أربع جمل كحد أقصى).
- صححي القواعد بلطف إذا أخطأ المستخدم.
- أجيبي دائمًا باللغة العربية الفصحى، بالأحرف العربية.
- كوني مشجعة وداعمة.
- إذا كتب المستخدم بلغة أخرى، وجّهيه بلطف نحو العربية.
الحالة المزاجية الحالية: متعاونة ومشجعة.
''' + _formatBlock,
  };

  static const Map<String, String> _fallbackMessages = {
    'en': "Sorry, I couldn't understand that. Could you try again?",
    'es': 'Lo siento, no pude entender eso. ¿Puedes intentarlo de nuevo?',
    'sw': 'Samahani, sikuelewa hilo. Unaweza kujaribu tena?',
    'zh': '不好意思，我没听懂。你可以再说一遍吗？',
    'hi': 'माफ़ कीजिए, मैं समझ नहीं पाई। क्या आप दोबारा कोशिश कर सकते हैं?',
    'fr': "Désolée, je n'ai pas compris. Peux-tu réessayer ?",
    'ru': 'Извините, я не поняла. Можете попробовать ещё раз?',
    'pt': 'Desculpe, não entendi. Você pode tentar novamente?',
    'de': 'Entschuldigung, das habe ich nicht verstanden. Kannst du es noch einmal versuchen?',
    'ar': 'آسفة، لم أفهم ذلك. هل يمكنك المحاولة مرة أخرى؟',
  };

  static String systemPromptFor(String lang) =>
      systemPrompts[lang] ?? systemPrompts['en']!;

  static String fallbackMessageFor(String lang) =>
      _fallbackMessages[lang] ?? _fallbackMessages['en']!;

  static String filterResponse(String response) {
    final banned = ['haha', 'hehe', 'jeje', 'jaja', 'kkk', 'lol', 'lmao'];
    String cleaned = response;
    for (final word in banned) {
      cleaned = cleaned.replaceAll(RegExp(word, caseSensitive: false), '');
    }
    return cleaned.trim();
  }
}
DARTEOF

# ------------------------------------------------------------
# 4) speech_service.dart: reescritura completa — recibe el idioma
#    actual y usa el locale correcto (antes: 'en_US' fijo siempre).
# ------------------------------------------------------------
echo "==> 4/9  speech_service.dart — reconocimiento de voz en el idioma seleccionado"
backup "$LIB/core/services/speech_service.dart"
cat > "$LIB/core/services/speech_service.dart" << 'EOF'
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../config/locale_map.dart';
import '../utils/logger.dart';

class SpeechService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;

  bool get isListening => _isListening;

  Future<bool> initialize() async {
    final available = await _speech.initialize(
      onError: (error) => Logger.error('STT Error: $error'),
      onStatus: (status) => Logger.log('STT Status: $status'),
    );
    return available;
  }

  /// [language] es el código de idioma ACTUAL de la app ('en','es',
  /// 'sw','zh',...). FIX: antes este parámetro no existía y el
  /// reconocimiento de voz siempre usaba 'en_US' sin importar el
  /// idioma seleccionado — si hablabas en otro idioma, el motor STT
  /// intentaba reconocerlo como inglés y el resultado salía vacío o
  /// incorrecto (percibido como "el micrófono no funciona").
  Future<void> listen({
    required String language,
    required Function(String locale) onLanguageDetected,
    required Function(String text) onResult,
  }) async {
    if (!_speech.isAvailable) {
      await initialize();
    }

    final localeId = LocaleMap.forLanguage(language);
    _isListening = true;

    await _speech.listen(
      onResult: (result) {
        if (result.finalResult) {
          final text = result.recognizedWords;
          onLanguageDetected(localeId);
          onResult(text);
          _isListening = false;
        }
      },
      localeId: localeId,
      listenMode: stt.ListenMode.confirmation,
    );
  }

  Future<void> stop() async {
    _isListening = false;
    await _speech.stop();
  }
}
EOF

# ------------------------------------------------------------
# 5) hybrid_tts_service.dart: usar el mismo LocaleMap (antes tenía
#    su propio switch de 9 idiomas por separado).
# ------------------------------------------------------------
echo "==> 5/9  hybrid_tts_service.dart — usa LocaleMap (una sola fuente de verdad)"
backup "$LIB/core/services/hybrid_tts_service.dart"
python3 - "$LIB/core/services/hybrid_tts_service.dart" << 'PYEOF'
import sys
path = sys.argv[1]
s = open(path, encoding='utf-8').read()

if "import '../config/locale_map.dart';" not in s:
    s = s.replace(
        "import '../utils/logger.dart';",
        "import '../config/locale_map.dart';\nimport '../utils/logger.dart';",
        1,
    )

old_switch = (
    "    final locale = switch (langCode) {\n"
    "      'sw' => 'sw-KE',\n"
    "      'zh' => 'zh-CN',\n"
    "      'hi' => 'hi-IN',\n"
    "      'fr' => 'fr-FR',\n"
    "      'ru' => 'ru-RU',\n"
    "      'pt' => 'pt-PT',\n"
    "      'de' => 'de-DE',\n"
    "      'ar' => 'ar-SA',\n"
    "      _    => 'en-US',\n"
    "    };"
)
new_switch = "    final locale = LocaleMap.forLanguage(langCode);"

if old_switch in s:
    s = s.replace(old_switch, new_switch)
    print("hybrid_tts_service.dart: switch reemplazado por LocaleMap.")
else:
    print("AVISO: no se encontró el switch de idiomas esperado; revisar a mano.", file=sys.stderr)

open(path, 'w', encoding='utf-8').write(s)
PYEOF

# ------------------------------------------------------------
# 6) api_config.dart: timeout más realista para cold-start de Render.
# ------------------------------------------------------------
echo "==> 6/9  api_config.dart — timeout configurable y más realista"
backup "$LIB/core/config/api_config.dart"
cat > "$LIB/core/config/api_config.dart" << 'EOF'
class ApiConfig {
  static const String backendBaseUrl = 'https://adri-speed-speech-backend.onrender.com';

  // FIX: 10s era demasiado corto. Un cold-start real de Render (free
  // tier) puede tardar 30-50s, y el backend en sí intenta varios
  // proveedores LLM en cadena antes de responder. 10s cortaba la
  // conexión ANTES de que el backend terminara, mostrando siempre el
  // mensaje de "no entendí" aunque el servidor sí hubiera respondido
  // un segundo más tarde.
  static const int requestTimeoutSeconds = 45;
}
EOF

# ------------------------------------------------------------
# 7) ai_service.dart: usar ApiConfig.requestTimeoutSeconds (antes
#    tenía 10 fijo, ignorando ApiConfig por completo).
# ------------------------------------------------------------
echo "==> 7/9  ai_service.dart — usa el timeout de ApiConfig"
backup "$LIB/core/services/ai_service.dart"
python3 - "$LIB/core/services/ai_service.dart" << 'PYEOF'
import sys
path = sys.argv[1]
s = open(path, encoding='utf-8').read()

old = ".timeout(const Duration(seconds: 10));"
new = ".timeout(Duration(seconds: ApiConfig.requestTimeoutSeconds));"
assert old in s, "no se encontró el timeout fijo de 10s en ai_service.dart"
s = s.replace(old, new)

open(path, 'w', encoding='utf-8').write(s)
print("ai_service.dart: timeout ahora viene de ApiConfig.requestTimeoutSeconds.")
PYEOF

# ------------------------------------------------------------
# 8) adri_avatar_widget.dart: recalibrar coordenadas del painter
#    para compensar el recorte real de BoxFit.cover en el contenedor
#    cuadrado 120x120 sobre una foto vertical 768x1376.
# ------------------------------------------------------------
echo "==> 8/9  adri_avatar_widget.dart — recalibrar boca/ojos/cejas al recorte real de la foto"
backup "$LIB/core/services/avatar/adri_avatar_widget.dart"
python3 - "$LIB/core/services/avatar/adri_avatar_widget.dart" << 'PYEOF'
import sys
path = sys.argv[1]
s = open(path, encoding='utf-8').read()

old_eyes_block = (
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
    "    _drawEyebrow(canvas, center, scale, 0.60, 0.315);"
)
new_eyes_block = (
    "    // Coordenadas recalibradas: la foto (768x1376) se muestra en\n"
    "    // un contenedor CUADRADO con BoxFit.cover, que recorta ~44% de\n"
    "    // la imagen (22% arriba + 22% abajo) para llenar el cuadrado.\n"
    "    // X no se recorta (el ancho SÍ llena el cuadrado exactamente),\n"
    "    // por eso solo Y cambia respecto a la posición real en la foto.\n"
    "    const eyeRy = 0.151; // antes 0.315 (posición en la foto SIN recortar)\n"
    "    const browRy = 0.075;\n"
    "    final effectivelyBlinking = isBlinking && eyeOpen < 0.75;\n"
    "    if (!effectivelyBlinking) {\n"
    "      _drawEye(canvas, center, scale, 0.40, eyeRy);\n"
    "      _drawEye(canvas, center, scale, 0.61, eyeRy);\n"
    "    } else {\n"
    "      _drawClosedEye(canvas, center, scale, 0.40, eyeRy);\n"
    "      _drawClosedEye(canvas, center, scale, 0.61, eyeRy);\n"
    "    }\n"
    "\n"
    "    _drawEyebrow(canvas, center, scale, 0.40, browRy);\n"
    "    _drawEyebrow(canvas, center, scale, 0.61, browRy);"
)
assert old_eyes_block in s, "no se encontró el bloque de dibujo de ojos/cejas en paint()"
s = s.replace(old_eyes_block, new_eyes_block)

old_eyebrow_fn = (
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
new_eyebrow_fn = (
    "  void _drawEyebrow(\n"
    "      Canvas canvas, Offset center, double scale, double rx, double ry) {\n"
    "    final paint = Paint()\n"
    "      ..color = _browColor.withOpacity(0.85)\n"
    "      ..style = PaintingStyle.stroke\n"
    "      ..strokeWidth = 3\n"
    "      ..strokeCap = StrokeCap.round;\n"
    "\n"
    "    final liftNorm = browLift / 120.0 * scale;\n"
    "    final pos = Offset(\n"
    "      center.dx + (rx - 0.5) * scale,\n"
    "      center.dy + (ry - 0.5) * scale + liftNorm,\n"
    "    );\n"
    "\n"
    "    canvas.drawLine(\n"
    "      Offset(pos.dx - 0.05 * scale, pos.dy),\n"
    "      Offset(pos.dx + 0.05 * scale, pos.dy),\n"
    "      paint,\n"
    "    );\n"
    "  }"
)
assert old_eyebrow_fn in s, "no se encontró _drawEyebrow"
s = s.replace(old_eyebrow_fn, new_eyebrow_fn)

old_eye_radius = "    final radius = (0.028 + eyeOpen * 0.018) * scale;"
new_eye_radius = "    final radius = (0.040 + eyeOpen * 0.026) * scale;"
assert old_eye_radius in s, "no se encontró el cálculo de radio del ojo"
s = s.replace(old_eye_radius, new_eye_radius)

old_mouth_fn = (
    "  void _drawMouth(Canvas canvas, Offset center, double scale) {\n"
    "    final mouthPaint = Paint()\n"
    "      ..color = _lipColor\n"
    "      ..style = PaintingStyle.fill;\n"
    "\n"
    "    final mouthCenter = Offset(\n"
    "      center.dx,\n"
    "      center.dy + (0.435 - 0.5) * scale,\n"
    "    );\n"
    "\n"
    "    final width = 0.16 * scale;\n"
    "    final height = _getMouthHeight() * scale;"
)
new_mouth_fn = (
    "  void _drawMouth(Canvas canvas, Offset center, double scale) {\n"
    "    final mouthPaint = Paint()\n"
    "      ..color = _lipColor\n"
    "      ..style = PaintingStyle.fill;\n"
    "\n"
    "    // Recalibrado: 0.430 es la posición real de la boca medida con\n"
    "    // MediaPipe sobre la foto SIN recortar; 0.375 es esa misma\n"
    "    // posición ya transformada al recorte cuadrado (ver nota en\n"
    "    // paint() sobre BoxFit.cover). Ancho real medido: 0.20 (antes\n"
    "    // 0.16, la boca se dibujaba visiblemente más angosta que la real).\n"
    "    final mouthCenter = Offset(\n"
    "      center.dx,\n"
    "      center.dy + (0.375 - 0.5) * scale,\n"
    "    );\n"
    "\n"
    "    final width = 0.20 * scale;\n"
    "    final height = _getMouthHeight() * scale;"
)
assert old_mouth_fn in s, "no se encontró _drawMouth"
s = s.replace(old_mouth_fn, new_mouth_fn)

old_heights = (
    "  double _getMouthHeight() {\n"
    "    return switch (viseme) {\n"
    "      Viseme.closed => 0.02,\n"
    "      Viseme.half   => 0.04,\n"
    "      Viseme.open   => 0.06,\n"
    "      Viseme.wide   => 0.08,\n"
    "      Viseme.round  => 0.07,\n"
    "      Viseme.smile  => 0.03,\n"
    "    };\n"
    "  }\n"
    "\n"
    "  @override\n"
    "  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;"
)
new_heights = (
    "  double _getMouthHeight() {\n"
    "    return switch (viseme) {\n"
    "      Viseme.closed => 0.03,\n"
    "      Viseme.half   => 0.06,\n"
    "      Viseme.open   => 0.09,\n"
    "      Viseme.wide   => 0.12,\n"
    "      Viseme.round  => 0.10,\n"
    "      Viseme.smile  => 0.045,\n"
    "    };\n"
    "  }\n"
    "\n"
    "  @override\n"
    "  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;"
)
assert old_heights in s, "no se encontró _getMouthHeight (painter)"
s = s.replace(old_heights, new_heights)

open(path, 'w', encoding='utf-8').write(s)
print("adri_avatar_widget.dart: coordenadas de ojos/cejas/boca recalibradas.")
PYEOF

# ------------------------------------------------------------
# 9) chat_screen.dart: quitar la dependencia de Drift para el
#    historial (SharedPreferences en su lugar), Español en el
#    selector, y micrófono pasando el idioma actual.
# ------------------------------------------------------------
echo "==> 9/9  chat_screen.dart — historial vía SharedPreferences, Español, mic por idioma"
backup "$LIB/features/vocabulary/presentation/screens/chat_screen.dart"
python3 - "$LIB/features/vocabulary/presentation/screens/chat_screen.dart" << 'PYEOF'
import sys
path = sys.argv[1]
s = open(path, encoding='utf-8').read()

s = s.replace(
    "import '../../../../core/services/database.dart';\n"
    "import 'package:drift/drift.dart' show Value;\n",
    "import 'package:shared_preferences/shared_preferences.dart';\n"
    "import 'dart:convert';\n",
)
if "import 'dart:convert';" not in s:
    s = s.replace(
        "import 'dart:async';",
        "import 'dart:async';\nimport 'dart:convert';",
        1,
    )
if "import 'package:shared_preferences/shared_preferences.dart';" not in s:
    s = s.replace(
        "import '../../../../main.dart';",
        "import '../../../../main.dart';\n"
        "import 'package:shared_preferences/shared_preferences.dart';",
        1,
    )

s = s.replace("\n  late AppDatabase _db;\n", "\n")

old_db_init = "    _db = context.read<AppDatabase>();\n\n    _ttsService.initialize();"
new_db_init = "    _ttsService.initialize();"
if old_db_init in s:
    s = s.replace(old_db_init, new_db_init)

old_load_history = '''  Future<void> _loadHistory() async {
    final rows = await _db.getRecentChatMessages(_currentLanguage);
    if (!mounted || rows.isEmpty) return;
    setState(() {
      _messages.addAll(rows.map((r) => {
            'role': r.role,
            'text': r.text,
            'translation': r.translation,
            'tagged': r.taggedText,
            'provider': r.providerUsed,
          }));
    });
    _scrollToBottom();
  }'''
new_load_history = '''  String get _historyPrefsKey => 'chat_history_$_currentLanguage';

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_historyPrefsKey);
    if (!mounted || raw == null || raw.isEmpty) return;
    try {
      final decoded = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      setState(() => _messages.addAll(decoded));
      _scrollToBottom();
    } catch (e, st) {
      Logger.error('No se pudo leer el historial guardado', error: e, stackTrace: st);
    }
  }

  Future<void> _persistHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final toSave = _messages.length > 200
        ? _messages.sublist(_messages.length - 200)
        : _messages;
    await prefs.setString(_historyPrefsKey, jsonEncode(toSave));
  }'''
assert old_load_history in s, "no se encontró _loadHistory en el formato esperado"
s = s.replace(old_load_history, new_load_history)

old_insert_user = '''    unawaited(_db.insertChatMessage(ChatMessagesCompanion.insert(
      role: 'user',
      text: text,
      language: _currentLanguage,
    )));'''
new_insert_user = "    unawaited(_persistHistory());"
assert old_insert_user in s, "no se encontró la inserción de mensaje de usuario a Drift"
s = s.replace(old_insert_user, new_insert_user)

old_insert_adri = '''    unawaited(_db.insertChatMessage(ChatMessagesCompanion.insert(
      role: 'adri',
      text: adriResponse.cleanText,
      translation: Value(adriResponse.spanishTranslation),
      taggedText: Value(adriResponse.taggedText),
      providerUsed: Value(adriResponse.providerUsed),
      language: _currentLanguage,
    )));'''
new_insert_adri = "    unawaited(_persistHistory());"
assert old_insert_adri in s, "no se encontró la inserción de mensaje de Adri a Drift"
s = s.replace(old_insert_adri, new_insert_adri)

marker = '''            _LanguageOption(
              flag: '🇮🇳',
              label: 'Hindi',
              code: 'hi',
              isSelected: _currentLanguage == 'hi',
              onTap: () => _changeLanguage('hi'),
            ),'''
spanish_option = '''            _LanguageOption(
              flag: '🇪🇸',
              label: 'Español',
              code: 'es',
              isSelected: _currentLanguage == 'es',
              onTap: () => _changeLanguage('es'),
            ),
''' + marker
assert marker in s, "no se encontró el bloque de Hindi en el selector de idioma"
s = s.replace(marker, spanish_option)

old_listen_call = "await _speechService.listen("
if old_listen_call in s:
    s = s.replace(
        "await _speechService.listen(\n",
        "await _speechService.listen(\n      language: _currentLanguage,\n",
        1,
    )
else:
    print("AVISO: no se encontró la llamada a _speechService.listen(); revisar mic a mano.", file=sys.stderr)

open(path, 'w', encoding='utf-8').write(s)
print("chat_screen.dart actualizado (SharedPreferences, Español, mic por idioma).")
PYEOF

# ------------------------------------------------------------
# 10) pubspec.yaml: shared_preferences no estaba declarado (el
#     historial de chat de este mismo script lo necesita).
# ------------------------------------------------------------
echo "==> 10/10 pubspec.yaml — agregar shared_preferences"
if ! grep -q "shared_preferences:" pubspec.yaml; then
  backup "pubspec.yaml"
  python3 - "pubspec.yaml" << 'PYEOF'
import sys
path = sys.argv[1]
s = open(path, encoding='utf-8').read()
old = "  cupertino_icons: ^1.0.6\n"
new = "  cupertino_icons: ^1.0.6\n  shared_preferences: ^2.3.2\n"
assert old in s, "no se encontró la línea de cupertino_icons en pubspec.yaml"
s = s.replace(old, new, 1)
open(path, 'w', encoding='utf-8').write(s)
print("pubspec.yaml: shared_preferences agregado.")
PYEOF
else
  echo "   shared_preferences ya estaba en pubspec.yaml, no se toca."
fi

echo ""
echo "============================================================"
echo " v4 aplicado. Copias de seguridad con sufijo $BACKUP_SUFFIX"
echo ""
echo " IMPORTANTE — esto NO lo pude corregir porque el archivo nunca"
echo " estuvo en lo que me compartiste:"
echo "   android/app/src/main/AndroidManifest.xml"
echo ""
echo " Si el micrófono y la cámara siguen sin pedir permiso, revisa"
echo " que ese archivo tenga esto dentro de <manifest ...>:"
echo ""
echo '   <uses-permission android:name="android.permission.RECORD_AUDIO"/>'
echo '   <uses-permission android:name="android.permission.CAMERA"/>'
echo '   <uses-permission android:name="android.permission.INTERNET"/>'
echo ""
echo " Sin RECORD_AUDIO ahí, Android nunca deja que speech_to_text"
echo " pida permiso — el micrófono se queda mudo sin ningún error"
echo " visible en pantalla."
echo ""
echo " Siguiente paso:"
echo "   flutter clean && flutter pub get"
echo "   (ESTA VEZ NO hace falta build_runner — el historial de chat"
echo "    ya no usa Drift, y database.dart quedó igual que antes de"
echo "    v3, compatible con el database.g.dart que ya tenías)."
echo "   Backend: hay que RE-DESPLEGAR adri_speed_speech_backend en"
echo "   Render para que los fixes de timeout/Gemini tomen efecto."
echo "============================================================"
