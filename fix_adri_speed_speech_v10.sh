#!/usr/bin/env bash
# ============================================================
# ADRI SPEED SPEECH — v10
# ============================================================
# Ejecutar desde la raíz del proyecto:
#   chmod +x fix_adri_speed_speech_v10.sh
#   ./fix_adri_speed_speech_v10.sh
#
# Corrige:
#  1. Historial de chat separado POR IDIOMA (antes era una sola
#     lista compartida: cambiar de idioma no cambiaba lo que se veía
#     en pantalla). Ahora cada idioma tiene su propia conversación.
#  2. Ese historial ahora se guarda en el dispositivo (antes vivía
#     solo en memoria y se perdía al cerrar la app) — persiste entre
#     secciones, por idioma.
#  3. Botón de repetir audio en cada burbuja de Adri.
#  4. Se restaura la etiqueta de "vía <proveedor>" bajo cada
#     respuesta (ya se guardaba el dato, pero no se mostraba) — te
#     va a servir para diagnosticar la latencia: si ves "vía
#     deepseek" o "vía gemini_flash" seguido, es señal de que Groq/
#     Cerebras se están agotando y cayendo a proveedores más lentos.
#  5. Cejas: se baja un poco la posición (estaban ligeramente altas)
#     y el color ahora varía según el avatar en vez de ser un solo
#     castaño fijo para los 10 (que no calzaba con cabello oscuro).
#
# Cambio de bajo riesgo: en vez de reescribir cada línea que usa
# _messages, se convirtió en un getter que apunta a la lista del
# idioma actual -- todo el código existente que ya usaba _messages
# sigue funcionando exactamente igual, sin tocarlo.
# ============================================================
set -euo pipefail

LIB="lib"
BACKUP_SUFFIX=".bak10_$(date +%Y%m%d_%H%M%S)"
backup() { cp "$1" "$1$BACKUP_SUFFIX"; }

# ------------------------------------------------------------
# 1) pubspec.yaml — shared_preferences
# ------------------------------------------------------------
echo "==> 1/3  pubspec.yaml — agregar shared_preferences"
if ! grep -q "shared_preferences:" pubspec.yaml; then
  backup "pubspec.yaml"
  python3 - "pubspec.yaml" << 'PYEOF'
import sys
path = sys.argv[1]
s = open(path, encoding='utf-8').read()
old = "  cupertino_icons: ^1.0.6\n"
new = "  cupertino_icons: ^1.0.6\n  shared_preferences: ^2.3.2\n"
assert old in s, "no se encontró la línea de cupertino_icons"
s = s.replace(old, new, 1)
open(path, 'w', encoding='utf-8').write(s)
print("pubspec.yaml: shared_preferences agregado.")
PYEOF
else
  echo "   pubspec.yaml: shared_preferences ya estaba, sin cambios."
fi

# ------------------------------------------------------------
# 2) chat_screen.dart — reescritura completa (preserva TODO lo
#    existente: avatar, 10 idiomas con scroll, traducción, mic,
#    cámara, expresiones, 350ms mínimo, audio en español) +
#    historial por idioma persistente + botón de repetir + proveedor
# ------------------------------------------------------------
echo "==> 2/3  chat_screen.dart — historial por idioma + persistencia + botón de repetir"
FILE="$LIB/features/vocabulary/presentation/screens/chat_screen.dart"
backup "$FILE"
cat > "$FILE" << 'EOF'
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  // Historial SEPARADO por idioma: cambiar de idioma ya no mezcla
  // conversaciones. _messages (abajo) es un getter de conveniencia
  // que apunta siempre a la lista del idioma actual, así que todo el
  // código que ya usaba `_messages.add(...)` / `_messages[i]` sigue
  // funcionando exactamente igual sin tener que tocarlo.
  final Map<String, List<Map<String, dynamic>>> _messagesByLanguage = {};
  List<Map<String, dynamic>> get _messages =>
      _messagesByLanguage.putIfAbsent(_currentLanguage, () => []);

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

    _loadAllHistories();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Carga el historial guardado de LOS 10 idiomas al abrir la app
  /// (cada uno en su propia clave, así que no se mezclan).
  Future<void> _loadAllHistories() async {
    final prefs = await SharedPreferences.getInstance();
    for (final lang in _languages) {
      final code = lang['code']!;
      final raw = prefs.getString('chat_history_$code');
      if (raw == null || raw.isEmpty) continue;
      try {
        final decoded = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
        _messagesByLanguage[code] = decoded;
      } catch (_) {
        // Si el JSON guardado está corrupto, se ignora esa entrada en
        // vez de romper la carga del resto de los idiomas.
      }
    }
    if (mounted) setState(() {});
    _scrollToBottom();
  }

  /// Guarda el historial del idioma ACTUAL (se llama después de cada
  /// mensaje nuevo, de usuario o de Adri).
  Future<void> _persistCurrentHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _messages;
    // Tope de 200 mensajes por idioma para no crecer sin límite.
    final toSave = list.length > 200 ? list.sublist(list.length - 200) : list;
    await prefs.setString('chat_history_$_currentLanguage', jsonEncode(toSave));
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
    _scrollToBottom();
  }

  void _showLanguageSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
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
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: _languages.map((lang) {
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
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
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
    unawaited(_persistCurrentHistory());

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
    unawaited(_persistCurrentHistory());

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
      final ms = (cue.text.length / charsPerSecond * 1000).clamp(350, 4000).toInt();
      await Future.delayed(Duration(milliseconds: ms));
    }

    await ttsFuture;
    if (mounted) setState(() => _currentAvatarExpression = null);

    await _ttsService.speakTranslation(response.spanishTranslation);
  }

  /// Repite el audio (y la animación) de un mensaje de Adri ya
  /// mostrado en pantalla, sin volver a llamar al LLM.
  Future<void> _replayMessage(Map<String, dynamic> msg) async {
    if (_isProcessing) return;
    final tagged = (msg['tagged'] as String?) ?? (msg['text'] as String);
    final clean = msg['text'] as String;
    final translation = (msg['translation'] as String?) ?? '';

    setState(() => _isProcessing = true);
    _speechState.setState_(AdriState.speaking);
    await _playTaggedResponse(
      AdriResponse(taggedText: tagged, cleanText: clean, spanishTranslation: translation),
    );
    _speechState.setState_(AdriState.idle);
    if (mounted) setState(() => _isProcessing = false);
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
                  providerUsed: msg['provider'],
                  onReplay: isUser ? null : () => _replayMessage(msg),
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
  final String? providerUsed;
  final VoidCallback? onReplay;

  const _ChatBubble({
    required this.text,
    required this.isUser,
    this.translation,
    this.providerUsed,
    this.onReplay,
  });

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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    text,
                    style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.4),
                  ),
                ),
                if (onReplay != null)
                  InkWell(
                    onTap: onReplay,
                    borderRadius: BorderRadius.circular(16),
                    child: const Padding(
                      padding: EdgeInsets.only(left: 6, top: 1),
                      child: Icon(Icons.volume_up_rounded, size: 18, color: Colors.white70),
                    ),
                  ),
              ],
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
            if (providerUsed != null && providerUsed!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'vía $providerUsed',
                style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 10),
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
# 3) adri_avatar_widget.dart — cejas: posición un poco más abajo +
#    color según el avatar (en vez de un castaño fijo para los 10).
# ------------------------------------------------------------
echo "==> 3/3  adri_avatar_widget.dart — posición y color de cejas por avatar"
FILE="$LIB/core/services/avatar/adri_avatar_widget.dart"
backup "$FILE"
python3 - "$FILE" << 'PYEOF'
import sys
path = sys.argv[1]
s = open(path, encoding='utf-8').read()
changes = []

# a) _FacePainter: agregar campo browColor (con default = el mismo
#    castaño de antes, para no romper nada si algún día se llama sin
#    especificarlo).
old_ctor = """  final double browLift;
  final double eyeOpen;
  final double headTiltDeg;

  _FacePainter({
    required this.isSpeaking,
    required this.isBlinking,
    required this.viseme,
    required this.expression,
    required this.amplitude,
    this.browLift = 0,
    this.eyeOpen = 0.5,
    this.headTiltDeg = 0,
  });

  static const Color _lipColor = Color(0xFFCC8E8E);
  static const Color _eyeColor = Color(0xFF2D1B4E);
  static const Color _browColor = Color(0xFF4A3220);"""
new_ctor = """  final double browLift;
  final double eyeOpen;
  final double headTiltDeg;
  final Color browColor;

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
  });

  static const Color _lipColor = Color(0xFFCC8E8E);
  static const Color _eyeColor = Color(0xFF2D1B4E);"""

if old_ctor in s:
    s = s.replace(old_ctor, new_ctor)
    changes.append("campo browColor agregado a _FacePainter")
elif "final Color browColor;" in s:
    changes.append("_FacePainter ya tenía browColor")
else:
    print("AVISO: no se encontró el constructor de _FacePainter esperado; revisar a mano.", file=sys.stderr)

# b) _drawEyebrow: usar browColor (instancia) en vez de _browColor
#    (static), y bajar un poco la posición (estaba ligeramente alta).
old_draw = """  void _drawEyebrow(
      Canvas canvas, Offset center, double scale, double rx, double ry) {
    final paint = Paint()
      ..color = _browColor.withOpacity(0.75)"""
new_draw = """  void _drawEyebrow(
      Canvas canvas, Offset center, double scale, double rx, double ry) {
    final paint = Paint()
      ..color = browColor.withOpacity(0.75)"""
if old_draw in s:
    s = s.replace(old_draw, new_draw)
    changes.append("_drawEyebrow usa el color por avatar")
elif "..color = browColor.withOpacity(0.75)" in s:
    changes.append("_drawEyebrow ya usaba browColor")

# c) bajar un poco browRy (estaba en 0.075, se sentía "más arriba de
#    lo natural" -- se sube el valor porque Y crece hacia abajo).
old_browry = "    const browRy = 0.075;"
new_browry = "    const browRy = 0.095;"
if old_browry in s:
    s = s.replace(old_browry, new_browry)
    changes.append("posición de cejas bajada (0.075 -> 0.095)")
elif "const browRy = 0.095;" in s:
    changes.append("posición de cejas ya estaba en 0.095")
else:
    print("AVISO: no se encontró 'const browRy = 0.075;'; revisar a mano.", file=sys.stderr)

# d) pasar el color calculado por idioma al instanciar _FacePainter.
old_call = """                  headTiltDeg: widget.expressionOverride != null
                      ? kExpressionParams[widget.expressionOverride]!.headTiltDeg
                      : 0,
                ),"""
new_call = """                  headTiltDeg: widget.expressionOverride != null
                      ? kExpressionParams[widget.expressionOverride]!.headTiltDeg
                      : 0,
                  browColor: _browColorForLanguage,
                ),"""
if old_call in s:
    s = s.replace(old_call, new_call)
    changes.append("color de cejas conectado a la instanciación del painter")
elif "browColor: _browColorForLanguage," in s:
    changes.append("ya estaba conectado")
else:
    print("AVISO: no se encontró la instanciación de _FacePainter esperada; revisar a mano.", file=sys.stderr)

# e) agregar el getter _browColorForLanguage en el State (antes de
#    _getMouthHeight, que ya sabemos que existe ahí). Se chequea
#    PRIMERO si ya existe (para no duplicarlo en una segunda corrida)
#    y solo si no existe se busca el ancla para insertarlo.
if "Color get _browColorForLanguage" in s:
    changes.append("getter ya existía")
else:
    old_anchor = "  double _getMouthHeight() {\n    return switch (_currentViseme) {"
    new_anchor = """  // Color de cejas por avatar -- antes era un solo castaño fijo
  // para los 10 idiomas, que no calzaba con cabello oscuro/negro en
  // varios de ellos. en/sw/zh son las 3 fotos originales (colores
  // ajustados a cada una); el resto usa un tono neutro oscuro por
  // defecto hasta poder calibrar cada foto nueva individualmente.
  Color get _browColorForLanguage {
    return switch (widget.language) {
      'en' => const Color(0xFF6B4423), // castaño medio (rubia)
      'sw' => const Color(0xFF1A1210), // casi negro
      'zh' => const Color(0xFF1F1B18), // negro azabache
      _    => const Color(0xFF2A211C), // neutro oscuro (resto de avatares)
    };
  }

  double _getMouthHeight() {
    return switch (_currentViseme) {"""
    if old_anchor in s:
        s = s.replace(old_anchor, new_anchor)
        changes.append("getter _browColorForLanguage agregado")
    else:
        print("AVISO: no se encontró el ancla para insertar _browColorForLanguage; revisar a mano.", file=sys.stderr)

open(path, 'w', encoding='utf-8').write(s)
print("adri_avatar_widget.dart: " + ("; ".join(changes) + "." if changes else "sin cambios."))
PYEOF

echo ""
echo "============================================================"
echo " v10 aplicado. Copias de seguridad con sufijo $BACKUP_SUFFIX"
echo ""
echo " Sobre la latencia: ahora cada burbuja de Adri muestra abajo"
echo " \"vía <proveedor>\" en letra chica. Si ves seguido \"vía"
echo " deepseek\" o \"vía gemini_flash\" en vez de \"vía groq\" o \"vía"
echo " cerebras\", es señal de que los proveedores rápidos se están"
echo " agotando (límite de peticiones gratis) y cayendo a los más"
echo " lentos -- eso, sumado al cold-start de Render (30-60s si el"
echo " backend llevaba más de ~15 min sin uso), es la explicación"
echo " más probable de los varios segundos de espera."
echo ""
echo " Sobre las cejas: el ajuste de posición/color es una mejora"
echo " razonada pero no puedo verificarla contra la foto real (no"
echo " tengo forma de renderizar Flutter aquí) -- pruébalo y si"
echo " sigue viéndose desalineado, mándame otra captura de cerca y"
echo " ajusto el número exacto."
echo ""
echo " Siguiente paso: flutter pub get && flutter run -d R9PT415VJQV"
echo "============================================================"
