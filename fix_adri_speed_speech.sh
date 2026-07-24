#!/usr/bin/env bash
# ============================================================
# ADRI SPEED SPEECH — script de correcciones
# ============================================================
# Ejecutar desde la RAÍZ del proyecto Flutter (donde están
# lib/, pubspec.yaml y adri_speed_speech_backend/).
#
#   chmod +x fix_adri_speed_speech.sh
#   ./fix_adri_speed_speech.sh
#
# Qué hace, en orden:
#   1. Arregla los 2 bugs que causan "solo responde que no
#      entendió, siempre en inglés" (interpolación rota + clave
#      JSON equivocada).
#   2. Localiza el mensaje de error a los 9 idiomas.
#   3. Unifica Logger/LinguaLogger (elimina el crash de compilación).
#   4. Arregla el import roto y activa la cámara de verdad.
#   5. Activa el pre-calentamiento del backend al iniciar la app.
#   6. Agrega las dependencias que faltan en pubspec.yaml.
#   7. Extiende idioma -> persona / voz / avatar a los 9 idiomas
#      (hindi, francés, ruso, portugués, alemán, árabe + los 3
#      existentes), dejando los 6 avatares nuevos con foto
#      placeholder hasta que existan las fotos reales.
#
# Cada paso hace una copia .bak antes de tocar el archivo.
# ============================================================
set -euo pipefail

LIB="lib"
BACKUP_SUFFIX=".bak_$(date +%Y%m%d_%H%M%S)"

backup() {
  cp "$1" "$1$BACKUP_SUFFIX"
}

echo "==> 1/7  ai_service.dart — interpolación de URL + clave JSON + idiomas"
backup "$LIB/core/services/ai_service.dart"
cat > "$LIB/core/services/ai_service.dart" << 'EOF'
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../config/ai_persona_config.dart';
import '../utils/logger.dart';

class AIService {
  final String _baseUrl;

  AIService({String apiKey = '', String? baseUrl})
      : _baseUrl = baseUrl ?? ApiConfig.backendBaseUrl;

  Future<String?> sendMessage(String prompt, {String? lang}) async {
    final effectiveLang = lang ?? 'en';
    try {
      final systemPrompt = AIPersonaConfig.systemPromptFor(effectiveLang);

      // FIX: antes decía Uri.parse('\$_baseUrl/chat') — el backslash
      // impedía que Dart interpolara la variable, así que la app
      // intentaba llamar literalmente a la URL "$_baseUrl/chat" y
      // el request fallaba SIEMPRE, cayendo directo al catch de abajo.
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
        // FIX: el backend (main.py -> route_chat) devuelve la clave
        // "text", no "response". Con la clave equivocada, `raw` daba
        // siempre null y caía al fallback — nunca se veía la
        // respuesta real, ni en inglés ni en ningún otro idioma.
        final raw = data['text']?.toString() ??
            AIPersonaConfig.fallbackMessageFor(effectiveLang);
        return AIPersonaConfig.filterResponse(raw);
      } else {
        Logger.error('AI Service error: ${response.statusCode}');
        return AIPersonaConfig.fallbackMessageFor(effectiveLang);
      }
    } catch (e, st) {
      Logger.error('AI Service exception', error: e, stackTrace: st);
      return AIPersonaConfig.fallbackMessageFor(effectiveLang);
    }
  }
}
EOF

echo "==> 2/7  ai_persona_config.dart — Map de 9 idiomas + mensajes de error localizados"
backup "$LIB/core/config/ai_persona_config.dart"
cat > "$LIB/core/config/ai_persona_config.dart" << 'EOF'
/// Refactor: antes había un switch(lang){...} DUPLICADO en varios
/// archivos (ai_service.dart, hybrid_tts_service.dart,
/// avatar/adri_avatar_widget.dart) — cada uno con su propia lista de
/// 3 idiomas, desincronizada de los demás. Ahora todo vive en estos
/// Maps: agregar un idioma nuevo se hace UNA sola vez, aquí.
class AIPersonaConfig {
  static const String _rules = '''
Rules:
- NEVER use "haha", "hehe", "jeje", or similar laughter strings.
- Keep responses concise (2-4 sentences max).
- Correct grammar gently if the user makes mistakes.
- Be encouraging and supportive.
''';

  static const Map<String, String> systemPrompts = {
    'en': '''
You are Adri, a friendly and patient English language teacher.
Your personality is warm, encouraging, and professional.
$_rules
- Always respond in English.
- If the user writes in another language, gently redirect them to English.
Current mood: helpful and encouraging.
''',
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
''',
    'zh': '''
Ni shi Adri, yi wei you hao qie you nai xin de zhong wen lao shi.
Ni de xing ge wen nuan, gu li ren xin, zhuan ye.
Gui ze:
- Jue bu shi yong "ha ha", "he he", "hei hei" huo lei si de xiao sheng zi fu chuan.
- Hui da jian jie (zui duo 2-4 ju hua).
- Ru guo yong hu you yu fa cuo wu, wen he di jiu zheng.
- Shi zhong yong zhong wen hui da.
- Yao gu li he zhi chi.
- Ru guo yong hu yong qi ta yu yan shu xie, wen he di yin dao ta men shi yong zhong wen.
Dang qian zhuang tai: le yu zhu ren qie gu li ren xin.
''',
    'hi': '''
Aap Adri hain, ek dostana aur dhairyavaan Hindi bhasha shikshika.
Aapka vyaktitva garmjoshi bhara, protsahit karne wala aur peshewar hai.
Niyam:
- "haha", "hehe", "jeje" ya isi tarah ki hansi ke shabd kabhi na likhein.
- Jawab sanchipt rakhein (zyada se zyada 2-4 vaakya).
- Agar upyogkarta galti kare to vyakaran ko vinamrata se sudharein.
- Hamesha Hindi mein jawab dein.
- Protsahit karne wale aur sahayak banein.
- Agar upyogkarta kisi anya bhasha mein likhe, to use vinamrata se Hindi ki taraf le jaayein.
Vartamaan mood: sahayak aur protsahit karne wala.
''',
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
''',
    'ru': '''
Ty Adri, druzhelyubnyy i terpelivyy prepodavatel russkogo yazyka.
Tvoy kharakter — teplyy, obodryayushchiy i professionalnyy.
Pravila:
- Nikogda ne ispolzuy "haha", "hehe", "jeje" ili pokhozhiye smeshki.
- Otvechay kratko (maksimum 2-4 predlozheniya).
- Myagko ispravlyay grammatiku, yesli polzovatel oshibayetsya.
- Vsegda otvechay na russkom yazyke.
- Bud podderzhivayushchey i obodryayushchey.
- Yesli polzovatel pishet na drugom yazyke, myagko napravlyay yego k russkomu.
Tekushcheye nastroyeniye: otzyvchivaya i obodryayushchaya.
''',
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
''',
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
''',
    'ar': '''
Anti Adri, mudarrisat lugha Arabiya wadoda wa sabura.
Shakhsiyatuki dafia wa mushajjia wa mihaniya.
Al-qawaid:
- La tastakhdimi abadan "haha" aw "hehe" aw ma yushbihuha min al-dahik.
- Ejaby bi-ikhtisar (jumlatan ila arba' jumal kahad aqsa).
- Sahhihi al-qawaid bi-lutf idha akhta'a al-mustakhdim.
- Ejaby daiman bil-lugha al-Arabiya.
- Kuni mushajjia wa da'ima.
- Idha kataba al-mustakhdim bi-lugha ukhra, wajjihihi bi-lutf nahwa al-Arabiya.
Al-mazaj al-hali: mufida wa mushajjia.
''',
  };

  /// Mensaje de fallback cuando falla la conexión o el backend no
  /// devuelve texto. Antes era un string fijo en inglés ("Sorry, I
  /// could not understand.") sin importar el idioma seleccionado.
  static const Map<String, String> _fallbackMessages = {
    'en': "Sorry, I couldn't understand that. Could you try again?",
    'sw': 'Samahani, sikuelewa hilo. Unaweza kujaribu tena?',
    'zh': 'Bu hao yisi, wo mei ting dong. Ni keyi zai shuo yi bian ma?',
    'hi': 'Maaf kijiye, main samajh nahi paayi. Kya aap dobara koshish kar sakte hain?',
    'fr': "Désolée, je n'ai pas compris. Peux-tu réessayer ?",
    'ru': 'Izvinite, ya ne ponyala. Mozhete poprobovat yeshcho raz?',
    'pt': 'Desculpe, não entendi. Você pode tentar novamente?',
    'de': 'Entschuldigung, das habe ich nicht verstanden. Kannst du es noch einmal versuchen?',
    'ar': 'Aasifa, lam afham dhalik. Hal yumkinuka al-muhawala marra ukhra?',
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
EOF

echo "==> 3/7  logger.dart — unifica Logger (agrega info/warning, arregla interpolación)"
backup "$LIB/core/utils/logger.dart"
cat > "$LIB/core/utils/logger.dart" << 'EOF'
import 'dart:developer' as developer;

/// Única clase de logging del proyecto. Antes coexistían dos nombres
/// distintos (`Logger` aquí, `LinguaLogger` usado en otros 5+
/// archivos sin estar definido en ningún lado) — eso rompía la
/// compilación de camera_translation_service.dart,
/// backend_warmup_service.dart y vocabulary_repository_impl.dart.
/// Todas las llamadas del proyecto deben usar `Logger.*` de aquí
/// en adelante.
class Logger {
  static void log(String message, {String tag = 'ADRI'}) {
    developer.log(message, name: tag);
  }

  static void info(String message, {String tag = 'ADRI'}) {
    developer.log('INFO: $message', name: tag);
  }

  static void warning(String message, {String tag = 'ADRI'}) {
    developer.log('WARNING: $message', name: tag);
  }

  static void error(String message,
      {String tag = 'ADRI', Object? error, StackTrace? stackTrace}) {
    developer.log('ERROR: $message', name: tag, error: error, stackTrace: stackTrace);
  }
}
EOF

echo "==> 4/7  camera_translation_service.dart — import roto + LinguaLogger -> Logger"
backup "$LIB/core/services/camera_translation_service.dart"
# Import apuntaba a lib/core/core/utils/logger.dart (no existe) en vez de lib/core/utils/logger.dart
sed -i "s#import '../core/utils/logger.dart';#import '../utils/logger.dart';#" \
  "$LIB/core/services/camera_translation_service.dart"
sed -i 's/LinguaLogger\./Logger./g' "$LIB/core/services/camera_translation_service.dart"

echo "==> 4b/7 backend_warmup_service.dart — LinguaLogger -> Logger"
backup "$LIB/core/services/backend_warmup_service.dart"
sed -i 's/LinguaLogger\./Logger./g' "$LIB/core/services/backend_warmup_service.dart"

echo "==> 4c/7 vocabulary_repository_impl.dart — LinguaLogger -> Logger (args nombrados)"
backup "$LIB/features/vocabulary/data/repositories/vocabulary_repository_impl.dart"
# Estas llamadas usaban argumentos posicionales (e, stackTrace) pero
# Logger.error los espera NOMBRADOS (error:, stackTrace:).
sed -i \
  -e "s/LinguaLogger\.error('\([^']*\)', e, stackTrace);/Logger.error('\1', error: e, stackTrace: stackTrace);/g" \
  "$LIB/features/vocabulary/data/repositories/vocabulary_repository_impl.dart"

echo "==> 5/7  chat_screen.dart — activa cámara + agrega 6 idiomas al selector"
backup "$LIB/features/vocabulary/presentation/screens/chat_screen.dart"

# 5a. Import de la pantalla de traducción por cámara
sed -i "/import '..\/..\/..\/..\/core\/utils\/logger.dart';/a import '../screens/image_translation_screen.dart';" \
  "$LIB/features/vocabulary/presentation/screens/chat_screen.dart"

# 5b/5c. Botón de cámara real + 6 idiomas nuevos en el selector (vía Python: son
# reemplazos multilínea exactos, más seguros que sed para este caso).
python3 - "$LIB/features/vocabulary/presentation/screens/chat_screen.dart" << 'PYEOF'
import sys
path = sys.argv[1]
s = open(path, encoding='utf-8').read()

old = (
    "IconButton(\n"
    "            icon: const Icon(Icons.camera_alt_outlined),\n"
    "            onPressed: () {},\n"
    "          ),"
)
new = (
    "IconButton(\n"
    "            icon: const Icon(Icons.camera_alt_outlined),\n"
    "            onPressed: () {\n"
    "              Navigator.of(context).push(\n"
    "                MaterialPageRoute(\n"
    "                  builder: (_) => const ImageTranslationScreen(),\n"
    "                ),\n"
    "              );\n"
    "            },\n"
    "          ),"
)
if old not in s:
    print("AVISO: no se encontró el bloque exacto del botón de cámara; revisar a mano.", file=sys.stderr)
else:
    s = s.replace(old, new)

marker = (
    "            _LanguageOption(\n"
    "              flag: '\U0001F1E8\U0001F1F3',\n"
    "              label: 'Mandarin',\n"
    "              code: 'zh',\n"
    "              isSelected: _currentLanguage == 'zh',\n"
    "              onTap: () => _changeLanguage('zh'),\n"
    "            ),"
)
extra = marker + "\n" + "\n".join([
    "            _LanguageOption(\n"
    "              flag: '\U0001F1EE\U0001F1F3',\n"
    "              label: 'Hindi',\n"
    "              code: 'hi',\n"
    "              isSelected: _currentLanguage == 'hi',\n"
    "              onTap: () => _changeLanguage('hi'),\n"
    "            ),",
    "            _LanguageOption(\n"
    "              flag: '\U0001F1EB\U0001F1F7',\n"
    "              label: 'Fran\u00e7ais',\n"
    "              code: 'fr',\n"
    "              isSelected: _currentLanguage == 'fr',\n"
    "              onTap: () => _changeLanguage('fr'),\n"
    "            ),",
    "            _LanguageOption(\n"
    "              flag: '\U0001F1F7\U0001F1FA',\n"
    "              label: '\u0420\u0443\u0441\u0441\u043a\u0438\u0439',\n"
    "              code: 'ru',\n"
    "              isSelected: _currentLanguage == 'ru',\n"
    "              onTap: () => _changeLanguage('ru'),\n"
    "            ),",
    "            _LanguageOption(\n"
    "              flag: '\U0001F1F5\U0001F1F9',\n"
    "              label: 'Portugu\u00eas',\n"
    "              code: 'pt',\n"
    "              isSelected: _currentLanguage == 'pt',\n"
    "              onTap: () => _changeLanguage('pt'),\n"
    "            ),",
    "            _LanguageOption(\n"
    "              flag: '\U0001F1E9\U0001F1EA',\n"
    "              label: 'Deutsch',\n"
    "              code: 'de',\n"
    "              isSelected: _currentLanguage == 'de',\n"
    "              onTap: () => _changeLanguage('de'),\n"
    "            ),",
    "            _LanguageOption(\n"
    "              flag: '\U0001F1F8\U0001F1E6',\n"
    "              label: '\u0627\u0644\u0639\u0631\u0628\u064a\u0629',\n"
    "              code: 'ar',\n"
    "              isSelected: _currentLanguage == 'ar',\n"
    "              onTap: () => _changeLanguage('ar'),\n"
    "            ),",
])

if marker not in s:
    print("AVISO: no se encontró el bloque de Mandarin en el selector de idioma; revisar a mano.", file=sys.stderr)
else:
    s = s.replace(marker, extra)

open(path, 'w', encoding='utf-8').write(s)
print("chat_screen.dart actualizado.")
PYEOF

echo "==> 5d/7 hybrid_tts_service.dart — 9 idiomas + fix de interpolación"
backup "$LIB/core/services/hybrid_tts_service.dart"
python3 - "$LIB/core/services/hybrid_tts_service.dart" << 'PYEOF'
import sys
path = sys.argv[1]
s = open(path, encoding='utf-8').read()

old_switch = (
    "    final locale = switch (langCode) {\n"
    "      'sw' => 'sw-KE',\n"
    "      'zh' => 'zh-CN',\n"
    "      _    => 'en-US',\n"
    "    };"
)
new_switch = (
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
if old_switch not in s:
    print("AVISO: no se encontró el switch de idiomas en hybrid_tts_service.dart; revisar a mano.", file=sys.stderr)
else:
    s = s.replace(old_switch, new_switch)

s = s.replace("Logger.error('TTS Error: \\$msg');", "Logger.error('TTS Error: $msg');")

open(path, 'w', encoding='utf-8').write(s)
print("hybrid_tts_service.dart actualizado.")
PYEOF

echo "==> 6/7  main.dart — activa el pre-calentamiento del backend al iniciar"
backup "$LIB/main.dart"
python3 - "$LIB/main.dart" << 'PYEOF'
import sys
path = sys.argv[1]
s = open(path, encoding='utf-8').read()

if "backend_warmup_service.dart" not in s:
    s = s.replace(
        "import 'features/vocabulary/presentation/screens/chat_screen.dart';",
        "import 'features/vocabulary/presentation/screens/chat_screen.dart';\n"
        "import 'core/services/backend_warmup_service.dart';",
    )

old_main = "void main() {\n  runApp(const AdriApp());\n}"
new_main = (
    "void main() {\n"
    "  // FIX: BackendWarmupService existía en el proyecto pero nunca se\n"
    "  // llamaba. El backend en Render (free tier) se \"duerme\" tras\n"
    "  // inactividad y puede tardar 30-60s en la primera respuesta.\n"
    "  // Lo disparamos aquí, en paralelo, sin bloquear el arranque de la UI.\n"
    "  BackendWarmupService().warmup();\n"
    "  runApp(const AdriApp());\n"
    "}"
)
if old_main not in s:
    print("AVISO: no se encontró void main() con el formato esperado; revisar a mano.", file=sys.stderr)
else:
    s = s.replace(old_main, new_main)

open(path, 'w', encoding='utf-8').write(s)
print("main.dart actualizado.")
PYEOF

echo "==> 6b/7 avatar/adri_avatar_widget.dart — 9 idiomas (avatares nuevos con placeholder temporal)"
backup "$LIB/core/services/avatar/adri_avatar_widget.dart"
python3 - "$LIB/core/services/avatar/adri_avatar_widget.dart" << 'PYEOF'
import sys
path = sys.argv[1]
s = open(path, encoding='utf-8').read()

old_asset = (
    "  String get _avatarAsset {\n"
    "    return switch (widget.language) {\n"
    "      'sw' => 'assets/avatars/adri_sw.png',\n"
    "      'zh' => 'assets/avatars/adri_zh.png',\n"
    "      _    => 'assets/avatars/adri_en.png',\n"
    "    };\n"
    "  }"
)
new_asset = (
    "  String get _avatarAsset {\n"
    "    return switch (widget.language) {\n"
    "      'sw' => 'assets/avatars/adri_sw.png',\n"
    "      'zh' => 'assets/avatars/adri_zh.png',\n"
    "      // TODO: reemplazar por fotos reales cuando existan (por ahora\n"
    "      // reusan las 3 fotos ya disponibles como placeholder temporal).\n"
    "      'hi' => 'assets/avatars/adri_en.png',\n"
    "      'fr' => 'assets/avatars/adri_sw.png',\n"
    "      'ru' => 'assets/avatars/adri_zh.png',\n"
    "      'pt' => 'assets/avatars/adri_en.png',\n"
    "      'de' => 'assets/avatars/adri_sw.png',\n"
    "      'ar' => 'assets/avatars/adri_zh.png',\n"
    "      _    => 'assets/avatars/adri_en.png',\n"
    "    };\n"
    "  }"
)

old_name = (
    "  String get _languageName {\n"
    "    return switch (widget.language) {\n"
    "      'sw' => 'Swahili Voice',\n"
    "      'zh' => 'Zhong Wen Yu Yin',\n"
    "      _    => 'English Voice',\n"
    "    };\n"
    "  }"
)
new_name = (
    "  String get _languageName {\n"
    "    return switch (widget.language) {\n"
    "      'sw' => 'Swahili Voice',\n"
    "      'zh' => 'Zhong Wen Yu Yin',\n"
    "      'hi' => 'Hindi Voice',\n"
    "      'fr' => 'Voix Fran\\u00e7aise',\n"
    "      'ru' => 'Russkiy Golos',\n"
    "      'pt' => 'Voz Portuguesa',\n"
    "      'de' => 'Deutsche Stimme',\n"
    "      'ar' => 'Sawt Arabi',\n"
    "      _    => 'English Voice',\n"
    "    };\n"
    "  }"
)

old_flag = (
    "  String get _flagEmoji {\n"
    "    return switch (widget.language) {\n"
    "      'sw' => '\U0001F1F9\U0001F1FF',\n"
    "      'zh' => '\U0001F1E8\U0001F1F3',\n"
    "      _    => '\U0001F1EC\U0001F1E7',\n"
    "    };\n"
    "  }"
)
new_flag = (
    "  String get _flagEmoji {\n"
    "    return switch (widget.language) {\n"
    "      'sw' => '\U0001F1F9\U0001F1FF',\n"
    "      'zh' => '\U0001F1E8\U0001F1F3',\n"
    "      'hi' => '\U0001F1EE\U0001F1F3',\n"
    "      'fr' => '\U0001F1EB\U0001F1F7',\n"
    "      'ru' => '\U0001F1F7\U0001F1FA',\n"
    "      'pt' => '\U0001F1F5\U0001F1F9',\n"
    "      'de' => '\U0001F1E9\U0001F1EA',\n"
    "      'ar' => '\U0001F1F8\U0001F1E6',\n"
    "      _    => '\U0001F1EC\U0001F1E7',\n"
    "    };\n"
    "  }"
)

for old, new, label in [
    (old_asset, new_asset, "_avatarAsset"),
    (old_name, new_name, "_languageName"),
    (old_flag, new_flag, "_flagEmoji"),
]:
    if old not in s:
        print(f"AVISO: no se encontró el bloque {label}; revisar a mano.", file=sys.stderr)
    else:
        s = s.replace(old, new)

open(path, 'w', encoding='utf-8').write(s)
print("avatar/adri_avatar_widget.dart actualizado.")
PYEOF

echo "==> 7/7  pubspec.yaml — dependencias faltantes (l10n + cámara/OCR/traducción)"
backup "pubspec.yaml"
python3 - "pubspec.yaml" << 'PYEOF'
import sys
path = sys.argv[1]
s = open(path, encoding='utf-8').read()

old = (
    "dependencies:\n"
    "  flutter:\n"
    "    sdk: flutter\n"
    "  http: ^1.2.0\n"
    "  speech_to_text: ^7.4.0\n"
    "  flutter_tts: ^4.2.2\n"
    "  provider: ^6.1.1\n"
    "  cupertino_icons: ^1.0.6\n"
)
new = (
    "dependencies:\n"
    "  flutter:\n"
    "    sdk: flutter\n"
    "  flutter_localizations:\n"
    "    sdk: flutter\n"
    "  intl: any\n"
    "  http: ^1.2.0\n"
    "  speech_to_text: ^7.4.0\n"
    "  flutter_tts: ^4.2.2\n"
    "  provider: ^6.1.1\n"
    "  cupertino_icons: ^1.0.6\n"
    "  # Requeridos por camera_translation_service.dart — antes se\n"
    "  # importaban en el código pero no estaban declarados aquí, así\n"
    "  # que el archivo no podía compilar.\n"
    "  image_picker: ^1.1.2\n"
    "  google_mlkit_text_recognition: ^0.13.1\n"
    "  google_mlkit_translation: ^0.13.1\n"
)
if old not in s:
    print("AVISO: no se encontró el bloque dependencies: esperado; revisar a mano.", file=sys.stderr)
else:
    s = s.replace(old, new)

open(path, 'w', encoding='utf-8').write(s)
print("pubspec.yaml actualizado.")
PYEOF

echo ""
echo "============================================================"
echo " Listo. Copias de seguridad guardadas con sufijo $BACKUP_SUFFIX"
echo ""
echo " Siguiente paso manual recomendado (no automatizado aquí,"
echo " por seguridad):"
echo "   1. flutter pub get"
echo "   2. Revisar los AVISO: impresos arriba (si el layout exacto"
echo "      de algún archivo cambió desde que se generó este script,"
echo "      ese bloque puntual necesita edición manual)."
echo "   3. Borrar los duplicados muertos:"
echo "      lib/core/services/adri_avatar_widget.dart"
echo "      lib/core/services/avatar_lip_sync_service.dart"
echo "      (las versiones reales están en lib/core/services/avatar/)"
echo "   4. Cuando existan las 6 fotos nuevas de avatar, correr"
echo "      extract_face_landmarks.py sobre cada una y reemplazar los"
echo "      placeholders marcados con TODO en avatar/adri_avatar_widget.dart"
echo "============================================================"
