#!/usr/bin/env bash
# ============================================================
# ADRI SPEED SPEECH — v7 (reconstrucción completa de chat_screen.dart)
# ============================================================
# Diagnóstico de esta ronda: chat_screen.dart fue reemplazado por una
# versión mínima (sin avatar, sin selector de idioma, sin lista de
# mensajes) — por eso "desapareció todo". El resto de piezas de
# soporte (ai_service.dart, ai_persona_config.dart con los 10
# idiomas, locale_map.dart, speech_service.dart, avatar/adri_avatar_
# widget.dart con las coordenadas recalibradas, avatar/dialogue_
# script_parser.dart con las 15 expresiones) SÍ están correctas y
# completas — se confirmó leyendo el volcado real, no adivinando.
#
# Este script:
#  1. Reescribe chat_screen.dart COMPLETO: avatar + selector de 10
#     idiomas + burbujas con traducción al español + mic + botón de
#     cámara + animación de expresión sincronizada con el habla.
#  2. Reescribe hybrid_tts_service.dart completo (le faltaba usar
#     LocaleMap y tenía el bug de "\$msg" sin interpolar).
#  3. Extiende avatar/adri_avatar_widget.dart de 3 a 10 idiomas en
#     sus 3 getters (asset/nombre/bandera) — lo único que le faltaba.
#  4. Corrige camera_translation_service.dart (import roto +
#     LinguaLogger) — el fix de la primera ronda no había quedado.
#  5. Corrige backend_warmup_service.dart (LinguaLogger) y lo
#     conecta en main.dart.
#  6. pubspec.yaml: agrega las dependencias que faltan.
#
# Ejecutar desde la raíz del proyecto:
#   chmod +x fix_adri_speed_speech_v7.sh
#   ./fix_adri_speed_speech_v7.sh
# ============================================================
set -euo pipefail

LIB="lib"
BACKUP_SUFFIX=".bak7_$(date +%Y%m%d_%H%M%S)"
backup() { cp "$1" "$1$BACKUP_SUFFIX"; }

# ------------------------------------------------------------
# 1) chat_screen.dart — reconstrucción completa
# ------------------------------------------------------------
echo "==> 1/6  chat_screen.dart — reconstrucción completa (avatar + 10 idiomas + burbujas + traducción)"
FILE="$LIB/features/vocabulary/presentation/screens/chat_screen.dart"
backup "$FILE"
cat > "$FILE" << 'EOF'
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/ai_service.dart';
import '../../../../core/services/hybrid_tts_service.dart';
import '../../../../core/services/speech_service.dart';
import '../../../../core/services/avatar/adri_avatar_widget.dart';
import '../../../../core/services/avatar/dialogue_script_parser.dart';
import '../../../../main.dart';
import 'image_translation_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];

  late AIService _aiService;
  late HybridTtsService _ttsService;
  late SpeechService _speechService;
  late AdriSpeechState _speechState;

  String _currentLanguage = 'en';
  bool _isProcessing = false;
  AvatarExpression? _currentAvatarExpression;

  static const List<Map<String, String>> _languages = [
    {'code': 'en', 'flag': '🇬🇧', 'label': 'English'},
    {'code': 'es', 'flag': '🇪🇸', 'label': 'Español'},
    {'code': 'sw', 'flag': '🇹🇿', 'label': 'Swahili'},
    {'code': 'zh', 'flag': '🇨🇳', 'label': 'Mandarin'},
    {'code': 'hi', 'flag': '🇮🇳', 'label': 'Hindi'},
    {'code': 'fr', 'flag': '🇫🇷', 'label': 'Français'},
    {'code': 'ru', 'flag': '🇷🇺', 'label': 'Русский'},
    {'code': 'pt', 'flag': '🇵🇹', 'label': 'Português'},
    {'code': 'de', 'flag': '🇩🇪', 'label': 'Deutsch'},
    {'code': 'ar', 'flag': '🇸🇦', 'label': 'العربية'},
  ];

  @override
  void initState() {
    super.initState();
    _aiService = context.read<AIService>();
    _ttsService = context.read<HybridTtsService>();
    _speechService = context.read<SpeechService>();
    _speechState = context.read<AdriSpeechState>();

    _ttsService.initialize();
    _ttsService.setLanguage(_currentLanguage);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _changeLanguage(String code) {
    setState(() => _currentLanguage = code);
    _ttsService.setLanguage(code);
    Navigator.of(context).pop();
  }

  void _showLanguageSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Elige un idioma',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ..._languages.map((lang) {
                final isSelected = _currentLanguage == lang['code'];
                return ListTile(
                  leading: Text(lang['flag']!, style: const TextStyle(fontSize: 22)),
                  title: Text(
                    lang['label']!,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check, color: Color(0xFF7C3AED))
                      : null,
                  onTap: () => _changeLanguage(lang['code']!),
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _sendMessage([String? spokenText]) async {
    final text = (spokenText ?? _controller.text).trim();
    if (text.isEmpty || _isProcessing) return;

    _controller.clear();

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
        'tagged': adriResponse.taggedText,
        'provider': adriResponse.providerUsed,
      });
    });
    _scrollToBottom();

    await _ttsService.precache(adriResponse.cleanText);
    await Future.delayed(const Duration(milliseconds: 150));

    _speechState.setState_(AdriState.speaking);
    await _playTaggedResponse(adriResponse);
    _speechState.setState_(AdriState.idle);

    if (mounted) setState(() => _isProcessing = false);
  }

  /// Reproduce el audio y anima el avatar en paralelo: la expresión
  /// va cambiando fragmento por fragmento (duración estimada por
  /// cantidad de caracteres) mientras el TTS dice el texto completo.
  Future<void> _playTaggedResponse(AdriResponse response) async {
    final cues = DialogueScriptParser.parse(response.taggedText);
    const charsPerSecond = 14.0;

    final ttsFuture = _ttsService.speakResponse(response.cleanText);

    for (final cue in cues) {
      if (!mounted) break;
      setState(() => _currentAvatarExpression = cue.expression);
      final ms = (cue.text.length / charsPerSecond * 1000).clamp(180, 4000).toInt();
      await Future.delayed(Duration(milliseconds: ms));
    }

    await ttsFuture;
    if (mounted) setState(() => _currentAvatarExpression = null);
  }

  Future<void> _onMicPressed() async {
    if (_speechState.state == AdriState.listening) {
      await _speechService.stop();
      _speechState.setState_(AdriState.idle);
      return;
    }
    _speechState.setState_(AdriState.listening);
    await _speechService.listen(
      language: _currentLanguage,
      onLanguageDetected: (_) {},
      onResult: (text) {
        _speechState.setState_(AdriState.idle);
        if (text.trim().isNotEmpty) {
          _sendMessage(text);
        }
      },
    );
  }

  void _openCamera() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ImageTranslationScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final speechState = context.watch<AdriSpeechState>();
    final currentLangMeta = _languages.firstWhere(
      (l) => l['code'] == _currentLanguage,
      orElse: () => _languages.first,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Adri Speed Speech'),
        actions: [
          IconButton(
            tooltip: 'Traducir con la cámara',
            icon: const Icon(Icons.camera_alt_outlined),
            onPressed: _openCamera,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: AdriAvatarWidget(
              key: ValueKey(_currentLanguage),
              isSpeaking: speechState.state == AdriState.speaking,
              amplitude: speechState.amplitude,
              language: _currentLanguage,
              onLanguageTap: _showLanguageSelector,
              expressionOverride: _currentAvatarExpression,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              switch (speechState.state) {
                AdriState.listening => 'Escuchando…',
                AdriState.waiting => 'Esperando…',
                AdriState.speaking => 'Hablando…',
                AdriState.idle => '${currentLangMeta['flag']} ${currentLangMeta['label']} Voice',
              },
              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
            ),
          ),
          const SizedBox(height: 8),
          Container(height: 1, color: const Color(0xFF7C3AED).withOpacity(0.3)),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['role'] == 'user';
                return _ChatBubble(
                  text: msg['text'],
                  isUser: isUser,
                  translation: msg['translation'],
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      speechState.state == AdriState.listening
                          ? Icons.mic
                          : Icons.mic_none,
                      color: speechState.state == AdriState.listening
                          ? const Color(0xFFEC4899)
                          : Colors.white70,
                    ),
                    onPressed: _isProcessing ? null : _onMicPressed,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Type or speak...',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                        filled: true,
                        fillColor: const Color(0xFF1A1A2E),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: const Color(0xFFEC4899),
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white, size: 20),
                      onPressed: _isProcessing ? null : () => _sendMessage(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
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
          color: isUser ? const Color(0xFF1E3A5F) : const Color(0xFF7C3AED),
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
              style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.4),
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
        ),
      ),
    );
  }
}
EOF

# ------------------------------------------------------------
# 2) hybrid_tts_service.dart — reescritura completa
# ------------------------------------------------------------
echo "==> 2/6  hybrid_tts_service.dart — reescritura completa (LocaleMap + fix de \$msg)"
FILE="$LIB/core/services/hybrid_tts_service.dart"
backup "$FILE"
cat > "$FILE" << 'EOF'
import 'package:flutter_tts/flutter_tts.dart';
import '../config/locale_map.dart';
import '../utils/logger.dart';

class HybridTtsService {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isSpeaking = false;
  String? _precachedText;

  bool get isSpeaking => _isSpeaking;

  Future<void> initialize() async {
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);

    _flutterTts.setCompletionHandler(() {
      _isSpeaking = false;
    });

    _flutterTts.setErrorHandler((msg) {
      Logger.error('TTS Error: $msg');
      _isSpeaking = false;
    });
  }

  Future<void> setLanguage(String langCode) async {
    final locale = LocaleMap.forLanguage(langCode);
    await _flutterTts.setLanguage(locale);
  }

  Future<void> precache(String text) async {
    _precachedText = text;
    Logger.log('TTS precached');
  }

  Future<void> speakResponse(String text) async {
    if (text.isEmpty) return;
    _isSpeaking = true;

    final delay = (_precachedText == text) ? 200 : 800;
    await Future.delayed(Duration(milliseconds: delay));

    await _flutterTts.speak(text);
    _precachedText = null;
  }

  Future<void> stop() async {
    _isSpeaking = false;
    await _flutterTts.stop();
  }
}
EOF

# ------------------------------------------------------------
# 3) avatar/adri_avatar_widget.dart — extender de 3 a 10 idiomas
# ------------------------------------------------------------
echo "==> 3/6  avatar/adri_avatar_widget.dart — extender los 3 getters a 10 idiomas"
FILE="$LIB/core/services/avatar/adri_avatar_widget.dart"
backup "$FILE"
python3 - "$FILE" << 'PYEOF'
import sys
path = sys.argv[1]
s = open(path, encoding='utf-8').read()
before = s

if "'hi' =>" in s and "_avatarAsset" in s:
    print("avatar/adri_avatar_widget.dart: ya tenía los 10 idiomas, no se toca.")
else:
    old_asset = """  String get _avatarAsset {
    return switch (widget.language) {
      'sw' => 'assets/avatars/adri_sw.png',
      'zh' => 'assets/avatars/adri_zh.png',
      _    => 'assets/avatars/adri_en.png',
    };
  }"""
    new_asset = """  String get _avatarAsset {
    return switch (widget.language) {
      'sw' => 'assets/avatars/adri_sw.png',
      'zh' => 'assets/avatars/adri_zh.png',
      // TODO: reemplazar por fotos reales cuando existan (por ahora
      // reusan las 3 fotos ya disponibles como placeholder temporal).
      'hi' => 'assets/avatars/adri_en.png',
      'fr' => 'assets/avatars/adri_sw.png',
      'ru' => 'assets/avatars/adri_zh.png',
      'pt' => 'assets/avatars/adri_en.png',
      'de' => 'assets/avatars/adri_sw.png',
      'ar' => 'assets/avatars/adri_zh.png',
      'es' => 'assets/avatars/adri_en.png',
      _    => 'assets/avatars/adri_en.png',
    };
  }"""
    if old_asset in s:
        s = s.replace(old_asset, new_asset)
    else:
        print("AVISO: no se encontró el patrón esperado de _avatarAsset (3 idiomas) ni el de 10 ya aplicado. Revisar a mano.", file=sys.stderr)

    old_name = """  String get _languageName {
    return switch (widget.language) {
      'sw' => 'Swahili Voice',
      'zh' => 'Zhong Wen Yu Yin',
      _    => 'English Voice',
    };
  }"""
    new_name = """  String get _languageName {
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
  }"""
    if old_name in s:
        s = s.replace(old_name, new_name)

    old_flag = """  String get _flagEmoji {
    return switch (widget.language) {
      'sw' => '🇹🇿',
      'zh' => '🇨🇳',
      _    => '🇬🇧',
    };
  }"""
    new_flag = """  String get _flagEmoji {
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
  }"""
    if old_flag in s:
        s = s.replace(old_flag, new_flag)

    if s != before:
        open(path, 'w', encoding='utf-8').write(s)
        print("avatar/adri_avatar_widget.dart: 10 idiomas aplicados.")
    else:
        print("avatar/adri_avatar_widget.dart: sin cambios (ya estaba correcto o formato distinto).")
PYEOF

# ------------------------------------------------------------
# 4) camera_translation_service.dart — import roto + LinguaLogger
# ------------------------------------------------------------
echo "==> 4/6  camera_translation_service.dart — import roto + LinguaLogger -> Logger"
FILE="$LIB/core/services/camera_translation_service.dart"
backup "$FILE"
python3 - "$FILE" << 'PYEOF'
import re, sys
path = sys.argv[1]
s = open(path, encoding='utf-8').read()
before = s

s = re.sub(r"import '\.\./core/utils/logger\.dart';", "import '../utils/logger.dart';", s)
s = s.replace('LinguaLogger.', 'Logger.')

open(path, 'w', encoding='utf-8').write(s)
if s != before:
    print("camera_translation_service.dart: corregido.")
elif "LinguaLogger" not in s and "'../core/utils/logger.dart'" not in s:
    print("camera_translation_service.dart: ya estaba correcto, sin cambios.")
else:
    print("AVISO: no se pudo corregir camera_translation_service.dart automáticamente; revisar a mano.", file=sys.stderr)
PYEOF

# ------------------------------------------------------------
# 5) backend_warmup_service.dart — LinguaLogger -> Logger, + wiring
#    en main.dart (precalentar el backend al iniciar la app).
# ------------------------------------------------------------
echo "==> 5/6  backend_warmup_service.dart — LinguaLogger -> Logger + conectar en main.dart"
FILE="$LIB/core/services/backend_warmup_service.dart"
backup "$FILE"
sed -i.tmp 's/LinguaLogger\./Logger./g' "$FILE" && rm -f "$FILE.tmp"

FILE="$LIB/main.dart"
backup "$FILE"
python3 - "$FILE" << 'PYEOF'
import sys
path = sys.argv[1]
s = open(path, encoding='utf-8').read()

if "backend_warmup_service.dart" not in s:
    s = s.replace(
        "import 'core/services/speech_service.dart';",
        "import 'core/services/speech_service.dart';\nimport 'core/services/backend_warmup_service.dart';",
        1,
    )

old_main = "void main() {\n  runApp(const AdriApp());\n}"
new_main = (
    "void main() {\n"
    "  // Precalienta el backend en paralelo (Render free tier se\n"
    "  // \"duerme\" tras inactividad); no bloquea el arranque de la UI.\n"
    "  BackendWarmupService().warmup();\n"
    "  runApp(const AdriApp());\n"
    "}"
)
if old_main in s:
    s = s.replace(old_main, new_main)
    print("main.dart: BackendWarmupService conectado.")
elif "BackendWarmupService().warmup()" in s:
    print("main.dart: BackendWarmupService ya estaba conectado, sin cambios.")
else:
    print("AVISO: no se encontró void main() en el formato esperado; revisar a mano.", file=sys.stderr)

open(path, 'w', encoding='utf-8').write(s)
PYEOF

# ------------------------------------------------------------
# 6) pubspec.yaml — dependencias faltantes
# ------------------------------------------------------------
echo "==> 6/6  pubspec.yaml — agregar dependencias faltantes"
backup "pubspec.yaml"
python3 - "pubspec.yaml" << 'PYEOF'
import sys
import re
path = sys.argv[1]
s = open(path, encoding='utf-8').read()
before = s

if "flutter_localizations:" not in s:
    s = s.replace(
        "dependencies:\n  flutter:\n    sdk: flutter\n",
        "dependencies:\n  flutter:\n    sdk: flutter\n"
        "  flutter_localizations:\n    sdk: flutter\n  intl: any\n",
        1,
    )

if "image_picker:" not in s:
    s = s.replace(
        "  cupertino_icons: ^1.0.6\n",
        "  cupertino_icons: ^1.0.6\n"
        "  image_picker: ^1.1.2\n"
        "  google_mlkit_text_recognition: ^0.13.1\n"
        "  google_mlkit_translation: ^0.11.1\n"
        "  equatable: ^2.0.5\n",
        1,
    )

# FIX independiente del bloque de arriba: si en una corrida anterior
# ya se agregó google_mlkit_translation con la versión que choca
# (^0.13.1, incompatible con google_mlkit_text_recognition ^0.13.1
# porque piden versiones distintas de google_mlkit_commons), se
# corrige aquí SIEMPRE, sin importar si el resto ya estaba agregado.
if "google_mlkit_translation: ^0.13.1" in s or "google_mlkit_translation: ^0.13.0" in s:
    s = re.sub(
        r"google_mlkit_translation: \^0\.13\.\d+",
        "google_mlkit_translation: ^0.11.1",
        s,
    )
    print("pubspec.yaml: corregida versión conflictiva de google_mlkit_translation (^0.13.x -> ^0.11.1).")

open(path, 'w', encoding='utf-8').write(s)
print("pubspec.yaml:", "actualizado" if s != before else "ya tenía todo, sin cambios")
PYEOF

echo ""
echo "============================================================"
echo " v7 aplicado. Copias de seguridad con sufijo $BACKUP_SUFFIX"
echo ""
echo " Sigue pendiente (no está en lo que me compartiste, no lo"
echo " puedo tocar): android/app/src/main/AndroidManifest.xml debe"
echo " tener, dentro de <manifest ...>:"
echo '   <uses-permission android:name="android.permission.RECORD_AUDIO"/>'
echo '   <uses-permission android:name="android.permission.CAMERA"/>'
echo '   <uses-permission android:name="android.permission.INTERNET"/>'
echo ""
echo " Siguiente paso:"
echo "   flutter clean && flutter pub get && flutter run -d R9PT415VJQV"
echo "============================================================"
