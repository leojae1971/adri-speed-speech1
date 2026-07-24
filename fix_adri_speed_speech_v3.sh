#!/usr/bin/env bash
# ============================================================
# ADRI SPEED SPEECH — v3: mejoras (caché, "escribiendo...",
# historial persistente, métrica de proveedor, repetir audio)
# ============================================================
# REQUIERE haber corrido antes v1 y v2. Ejecutar desde la raíz:
#
#   chmod +x fix_adri_speed_speech_v3.sh
#   ./fix_adri_speed_speech_v3.sh
#
# ATENCIÓN — único paso manual obligatorio de este script:
#   Se agrega una tabla nueva a la base de datos (Drift). Drift
#   genera código (database.g.dart) con build_runner; yo no tengo
#   forma de ejecutar ese generador aquí, así que DESPUÉS de correr
#   este script hace falta correr, una sola vez:
#
#     flutter pub run build_runner build --delete-conflicting-outputs
#
#   Si no se corre, el proyecto no compila (database.g.dart quedará
#   desactualizado respecto a database.dart). Te lo recuerdo también
#   al final del script.
# ============================================================
set -euo pipefail

LIB="lib"
BACKUP_SUFFIX=".bak3_$(date +%Y%m%d_%H%M%S)"
backup() { cp "$1" "$1$BACKUP_SUFFIX"; }

echo "==> 1/5  ai_service.dart — caché en memoria + métrica de proveedor LLM"
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
///  - spanishTranslation: traducción al español, siempre presente.
///  - providerUsed: qué proveedor LLM respondió realmente
///    (groq/cerebras/gemini/deepseek/cache/fallback) — útil para
///    diagnosticar cuál se está agotando o fallando más seguido.
class AdriResponse {
  final String taggedText;
  final String cleanText;
  final String spanishTranslation;
  final String providerUsed;
  const AdriResponse({
    required this.taggedText,
    required this.cleanText,
    required this.spanishTranslation,
    this.providerUsed = 'unknown',
  });
}

const String _kSpanishFallback =
    'Lo siento, no pude entender eso. ¿Puedes intentarlo de nuevo?';

class AIService {
  final String _baseUrl;

  /// Caché en memoria (se pierde al cerrar la app, no persiste a
  /// disco a propósito: las respuestas de Adri pueden variar con el
  /// contexto de la lección, así que solo evita repetir la MISMA
  /// pregunta dos veces dentro de la misma sesión).
  final Map<String, AdriResponse> _cache = {};

  AIService({String apiKey = '', String? baseUrl})
      : _baseUrl = baseUrl ?? ApiConfig.backendBaseUrl;

  String _cacheKey(String prompt, String lang) =>
      '$lang::${prompt.trim().toLowerCase()}';

  Future<AdriResponse> sendMessage(String prompt, {String? lang}) async {
    final effectiveLang = lang ?? 'en';
    final key = _cacheKey(prompt, effectiveLang);

    final cached = _cache[key];
    if (cached != null) {
      Logger.log('AI Service: respuesta desde caché ("$prompt", $effectiveLang)');
      return cached;
    }

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
        final providerUsed = data['provider_used']?.toString() ?? 'unknown';
        final parsed = _parseDualLanguage(raw, effectiveLang, providerUsed);
        _cache[key] = parsed; // solo se cachean respuestas reales, no fallbacks
        return parsed;
      } else {
        Logger.error('AI Service error: ${response.statusCode}');
        return _fallbackResponse(effectiveLang);
      }
    } catch (e, st) {
      Logger.error('AI Service exception', error: e, stackTrace: st);
      return _fallbackResponse(effectiveLang);
    }
  }

  AdriResponse _parseDualLanguage(
      String raw, String lang, String providerUsed) {
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
      providerUsed: providerUsed,
    );
  }

  AdriResponse _fallbackResponse(String lang) {
    final msg = AIPersonaConfig.fallbackMessageFor(lang);
    return AdriResponse(
      taggedText: msg,
      cleanText: msg,
      spanishTranslation: _kSpanishFallback,
      providerUsed: 'fallback',
    );
  }

  static final RegExp _tagRe = RegExp(r'\[([A-ZÁÉÍÓÚÑ_]+)\]');
  String _stripTags(String raw) =>
      raw.replaceAll(_tagRe, ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

  /// Por si en algún momento se quiere forzar una respuesta nueva
  /// (ej. botón "regenerar respuesta" a futuro).
  void clearCache() => _cache.clear();
}
EOF

echo "==> 2/5  database.dart — tabla ChatMessages (historial persistente)"
backup "$LIB/core/services/database.dart"
python3 - "$LIB/core/services/database.dart" << 'PYEOF'
import sys
path = sys.argv[1]
s = open(path, encoding='utf-8').read()

# 1) nueva tabla, insertada antes de @DriftDatabase
old_marker = "@DriftDatabase(tables: [VocabularyItems, SessionSnapshots])"
new_table_and_marker = '''class ChatMessages extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get role => text()(); // 'user' | 'adri'
  TextColumn get text => text()();
  TextColumn get translation => text().nullable()();
  TextColumn get taggedText => text().nullable()();
  TextColumn get providerUsed => text().nullable()();
  TextColumn get language => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DriftDatabase(tables: [VocabularyItems, SessionSnapshots, ChatMessages])'''
assert old_marker in s, "no se encontró @DriftDatabase(...) para insertar la tabla nueva"
s = s.replace(old_marker, new_table_and_marker)

# 2) schemaVersion 1 -> 2 + estrategia de migración (crea la tabla
#    nueva para quien actualiza desde una versión ya instalada; en
#    instalación limpia Drift crea todo directamente).
old_version = '''  @override
  int get schemaVersion => 1;'''
new_version = '''  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(chatMessages);
          }
        },
      );'''
assert old_version in s, "no se encontró schemaVersion => 1"
s = s.replace(old_version, new_version)

# 3) DAO: insertar/leer/limpiar historial de chat
old_close = '''  Future<SessionSnapshot?> getLastSessionSnapshot(String sessionId) {
    return (select(sessionSnapshots)
          ..where((tbl) => tbl.sessionId.equals(sessionId))
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.createdAt, mode: OrderingMode.desc)])
          ..limit(1))
        .getSingleOrNull();
  }
}'''
new_close = '''  Future<SessionSnapshot?> getLastSessionSnapshot(String sessionId) {
    return (select(sessionSnapshots)
          ..where((tbl) => tbl.sessionId.equals(sessionId))
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.createdAt, mode: OrderingMode.desc)])
          ..limit(1))
        .getSingleOrNull();
  }

  // --- Historial de chat (persistente entre sesiones) ---
  Future<int> insertChatMessage(ChatMessagesCompanion message) {
    return into(chatMessages).insert(message);
  }

  Future<List<ChatMessage>> getRecentChatMessages(String language,
      {int limit = 100}) {
    return (select(chatMessages)
          ..where((tbl) => tbl.language.equals(language))
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.createdAt)])
          ..limit(limit))
        .get();
  }

  Future<int> clearChatHistory(String language) {
    return (delete(chatMessages)..where((tbl) => tbl.language.equals(language)))
        .go();
  }
}'''
assert old_close in s, "no se encontró getLastSessionSnapshot(...) para agregar el DAO de chat"
s = s.replace(old_close, new_close)

open(path, 'w', encoding='utf-8').write(s)
print("database.dart actualizado (tabla ChatMessages + migración + DAO).")
PYEOF

echo "==> 3/5  main.dart — registra AppDatabase como Provider"
backup "$LIB/main.dart"
python3 - "$LIB/main.dart" << 'PYEOF'
import sys
path = sys.argv[1]
s = open(path, encoding='utf-8').read()

s = s.replace(
    "import 'core/services/backend_warmup_service.dart';",
    "import 'core/services/backend_warmup_service.dart';\nimport 'core/services/database.dart';",
    1,
)

old_providers = '''      providers: [
        ChangeNotifierProvider(create: (_) => AdriSpeechState()),
        Provider(create: (_) => AIService()),
        Provider(create: (_) => HybridTtsService()),
        Provider(create: (_) => SpeechService()),
      ],'''
new_providers = '''      providers: [
        ChangeNotifierProvider(create: (_) => AdriSpeechState()),
        Provider(create: (_) => AIService()),
        Provider(create: (_) => HybridTtsService()),
        Provider(create: (_) => SpeechService()),
        Provider<AppDatabase>(
          create: (_) => AppDatabase(),
          dispose: (_, db) => db.close(),
        ),
      ],'''
assert old_providers in s, "no se encontró la lista de providers en main.dart"
s = s.replace(old_providers, new_providers)

open(path, 'w', encoding='utf-8').write(s)
print("main.dart actualizado (AppDatabase disponible vía Provider).")
PYEOF

echo "==> 4/5  chat_screen.dart — historial persistente + indicador 'escribiendo' + proveedor + repetir audio"
backup "$LIB/features/vocabulary/presentation/screens/chat_screen.dart"
python3 - "$LIB/features/vocabulary/presentation/screens/chat_screen.dart" << 'PYEOF'
import sys
path = sys.argv[1]
s = open(path, encoding='utf-8').read()

# 1) imports nuevos
s = s.replace(
    "import '../../../../main.dart';",
    "import '../../../../main.dart';\n"
    "import '../../../../core/services/database.dart';\n"
    "import 'package:drift/drift.dart' show Value;",
    1,
)

# 2) flag de debug + campo de estado para "escribiendo" + AppDatabase
old_field = '''  String _currentLanguage = 'en';
  bool _isProcessing = false;
  AvatarExpression? _currentAvatarExpression;'''
new_field = '''  String _currentLanguage = 'en';
  bool _isProcessing = false;
  bool _isWaitingForResponse = false;
  AvatarExpression? _currentAvatarExpression;

  late AppDatabase _db;

  /// Mostrar de qué proveedor LLM vino cada respuesta (groq/cerebras/
  /// gemini/...) debajo de la burbuja. Poner en false para producción
  /// si no se quiere ese detalle visible al usuario final.
  static const bool kShowProviderDebug = true;'''
assert old_field in s, "no se encontró el bloque de campos de estado"
s = s.replace(old_field, new_field)

# 3) initState: obtener AppDatabase + cargar historial persistido
old_initstate = '''    _ttsService.initialize();
    _speechService.initialize();
    _ttsService.setLanguage(_currentLanguage);
  }'''
new_initstate = '''    _db = context.read<AppDatabase>();

    _ttsService.initialize();
    _speechService.initialize();
    _ttsService.setLanguage(_currentLanguage);

    _loadHistory();
  }

  Future<void> _loadHistory() async {
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
assert old_initstate in s, "no se encontró el final de initState()"
s = s.replace(old_initstate, new_initstate)

# 4) _sendMessage: persistir cada mensaje + controlar indicador de escritura
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
  }'''

new_send = '''  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isProcessing) return;

    _clearInputCompletely();

    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _isProcessing = true;
      _isWaitingForResponse = true;
    });
    _scrollToBottom();
    unawaited(_db.insertChatMessage(ChatMessagesCompanion.insert(
      role: 'user',
      text: text,
      language: _currentLanguage,
    )));

    _speechState.setState_(AdriState.waiting);

    final adriResponse = await _aiService.sendMessage(text, lang: _currentLanguage);

    setState(() {
      _isWaitingForResponse = false;
      _messages.add({
        'role': 'adri',
        'text': adriResponse.cleanText,
        'translation': adriResponse.spanishTranslation,
        'tagged': adriResponse.taggedText,
        'provider': adriResponse.providerUsed,
      });
    });
    _scrollToBottom();
    unawaited(_db.insertChatMessage(ChatMessagesCompanion.insert(
      role: 'adri',
      text: adriResponse.cleanText,
      translation: Value(adriResponse.spanishTranslation),
      taggedText: Value(adriResponse.taggedText),
      providerUsed: Value(adriResponse.providerUsed),
      language: _currentLanguage,
    )));

    await _ttsService.precache(adriResponse.cleanText);
    await Future.delayed(const Duration(milliseconds: 200));

    _speechState.setState_(AdriState.speaking);
    await _playTaggedResponse(adriResponse);
    _speechState.setState_(AdriState.idle);

    setState(() => _isProcessing = false);
  }

  /// Repite el audio (y la animación del avatar) de un mensaje de Adri
  /// ya mostrado en pantalla, sin volver a llamar al LLM.
  Future<void> _replayMessage(Map<String, dynamic> msg) async {
    if (_isProcessing) return;
    final tagged = (msg['tagged'] as String?) ?? (msg['text'] as String);
    final clean = msg['text'] as String;
    setState(() => _isProcessing = true);
    _speechState.setState_(AdriState.speaking);
    await _playTaggedResponse(
      AdriResponse(taggedText: tagged, cleanText: clean, spanishTranslation: ''),
    );
    _speechState.setState_(AdriState.idle);
    setState(() => _isProcessing = false);
  }'''

assert old_send in s, "no se encontró _sendMessage en el formato esperado"
s = s.replace(old_send, new_send)

# 5) import 'dart:async' ya existe (unawaited requiere dart:async) -> confirmar
assert "import 'dart:async';" in s, "falta import 'dart:async' (necesario para unawaited)"

# 6) ListView.builder: agregar el indicador de "escribiendo..." como
#    último ítem mientras se espera la respuesta.
old_listview = '''            child: ListView.builder(
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
            ),'''
new_listview = '''            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isWaitingForResponse ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length) {
                  return const _TypingIndicator();
                }
                final msg = _messages[index];
                final isUser = msg['role'] == 'user';
                return _ChatBubble(
                  text: msg['text'],
                  isUser: isUser,
                  translation: msg['translation'],
                  providerUsed: kShowProviderDebug ? msg['provider'] : null,
                  onReplay: isUser ? null : () => _replayMessage(msg),
                );
              },
            ),'''
assert old_listview in s, "no se encontró el ListView.builder de mensajes"
s = s.replace(old_listview, new_listview)

# 7) _ChatBubble: aceptar providerUsed + onReplay y mostrarlos
old_bubble_class = '''class _ChatBubble extends StatelessWidget {
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
        ),
      ),
    );
  }
}'''
new_bubble_class = '''class _ChatBubble extends StatelessWidget {
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                ),
                if (onReplay != null)
                  InkWell(
                    onTap: onReplay,
                    borderRadius: BorderRadius.circular(16),
                    child: const Padding(
                      padding: EdgeInsets.only(left: 6),
                      child: Icon(Icons.volume_up_rounded,
                          size: 18, color: Colors.white70),
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
                style: TextStyle(
                  color: Colors.white.withOpacity(0.35),
                  fontSize: 10,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Burbuja "escribiendo..." con 3 puntos animados, mientras se espera
/// la respuesta del backend.
class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF7C3AED),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
          ),
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                final t = (_controller.value - i * 0.2) % 1.0;
                final opacity = (t < 0.5) ? (0.3 + t) : (1.3 - t);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Opacity(
                    opacity: opacity.clamp(0.3, 1.0),
                    child: const CircleAvatar(
                      radius: 3.5,
                      backgroundColor: Colors.white,
                    ),
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }
}'''
assert old_bubble_class in s, "no se encontró la clase _ChatBubble en el formato esperado"
s = s.replace(old_bubble_class, new_bubble_class)

open(path, 'w', encoding='utf-8').write(s)
print("chat_screen.dart actualizado (historial, escribiendo..., proveedor, repetir audio).")
PYEOF

echo "==> 5/5  pubspec.yaml — confirmar dependencias de Drift (ya deberían estar si usas vocabulario)"
if ! grep -q "^  drift:" pubspec.yaml; then
  backup "pubspec.yaml"
  python3 - "pubspec.yaml" << 'PYEOF'
import sys
path = sys.argv[1]
s = open(path, encoding='utf-8').read()
s = s.replace(
    "  cupertino_icons: ^1.0.6\n",
    "  cupertino_icons: ^1.0.6\n"
    "  drift: ^2.20.0\n"
    "  path_provider: ^2.1.4\n"
    "  path: ^1.9.0\n",
    1,
)
open(path, 'w', encoding='utf-8').write(s)
print("pubspec.yaml: agregadas dependencias de Drift (no estaban listadas).")
PYEOF
  if ! grep -q "^dev_dependencies:" pubspec.yaml; then
    echo "" >> pubspec.yaml
  fi
  python3 - "pubspec.yaml" << 'PYEOF'
import sys
path = sys.argv[1]
s = open(path, encoding='utf-8').read()
if "drift_dev:" not in s:
    if "dev_dependencies:" in s:
        s = s.replace("dev_dependencies:\n", "dev_dependencies:\n  drift_dev: ^2.20.0\n  build_runner: ^2.4.11\n", 1)
    else:
        s += "\ndev_dependencies:\n  drift_dev: ^2.20.0\n  build_runner: ^2.4.11\n"
open(path, 'w', encoding='utf-8').write(s)
PYEOF
else
  echo "   drift ya estaba en pubspec.yaml, no se toca."
fi

echo ""
echo "============================================================"
echo " v3 aplicado. Copias de seguridad con sufijo $BACKUP_SUFFIX"
echo ""
echo " PASO MANUAL OBLIGATORIO (no lo puedo hacer yo por ti):"
echo "   flutter pub get"
echo "   flutter pub run build_runner build --delete-conflicting-outputs"
echo ""
echo " Ese comando regenera database.g.dart con la tabla ChatMessages"
echo " nueva. Sin correrlo, el proyecto NO compila."
echo "============================================================"
