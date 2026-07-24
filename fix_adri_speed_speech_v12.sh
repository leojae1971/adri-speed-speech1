#!/usr/bin/env bash
# ============================================================
# ADRI SPEED SPEECH — v12 (indicador de "escribiendo...")
# ============================================================
# Ejecutar desde la raíz del proyecto:
#   chmod +x fix_adri_speed_speech_v12.sh
#   ./fix_adri_speed_speech_v12.sh
#
# No reduce la latencia real -- la hace más llevadera: mientras se
# espera al backend, aparece una burbuja con 3 puntitos animados en
# vez de dejar la pantalla en silencio total (que se siente como que
# la app se colgó). Existía antes, se perdió al reconstruir
# chat_screen.dart en una ronda anterior.
# ============================================================
set -euo pipefail

LIB="lib"
FILE="$LIB/features/vocabulary/presentation/screens/chat_screen.dart"
BACKUP_SUFFIX=".bak12_$(date +%Y%m%d_%H%M%S)"
cp "$FILE" "$FILE$BACKUP_SUFFIX"

python3 - "$FILE" << 'PYEOF'
import sys
path = sys.argv[1]
s = open(path, encoding='utf-8').read()
changes = []

# a) campo de estado -- si ya existe, no se toca (idempotente).
if "_isWaitingForResponse" not in s:
    old = "  bool _isProcessing = false;\n  AvatarExpression? _currentAvatarExpression;"
    new = "  bool _isProcessing = false;\n  bool _isWaitingForResponse = false;\n  AvatarExpression? _currentAvatarExpression;"
    if old in s:
        s = s.replace(old, new)
        changes.append("campo _isWaitingForResponse agregado")
    else:
        print("AVISO: no se encontró el bloque de campos de estado; revisar a mano.", file=sys.stderr)
else:
    changes.append("campo _isWaitingForResponse ya existía")

# b) prender el flag justo antes de llamar al backend, apagarlo en
#    cuanto llega la respuesta de Adri (antes de armar su burbuja).
if "_isWaitingForResponse = true" not in s:
    old = """    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _isProcessing = true;
    });
    _scrollToBottom();
    unawaited(_persistCurrentHistory());

    _speechState.setState_(AdriState.waiting);

    final adriResponse = await _aiService.sendMessage(text, lang: _currentLanguage);

    setState(() {
      _messages.add({"""
    new = """    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _isProcessing = true;
      _isWaitingForResponse = true;
    });
    _scrollToBottom();
    unawaited(_persistCurrentHistory());

    _speechState.setState_(AdriState.waiting);

    final adriResponse = await _aiService.sendMessage(text, lang: _currentLanguage);

    setState(() {
      _isWaitingForResponse = false;
      _messages.add({"""
    if old in s:
        s = s.replace(old, new)
        changes.append("flag conectado en _sendMessage")
    else:
        print("AVISO: no se encontró el bloque de _sendMessage esperado; revisar a mano.", file=sys.stderr)
else:
    changes.append("flag ya estaba conectado")

# c) mostrar la burbuja de "escribiendo..." como último ítem del
#    ListView mientras se espera.
if "_TypingIndicator()" not in s:
    old = """              itemCount: _messages.length,
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
              },"""
    new = """              itemCount: _messages.length + (_isWaitingForResponse ? 1 : 0),
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
                  providerUsed: msg['provider'],
                  onReplay: isUser ? null : () => _replayMessage(msg),
                );
              },"""
    if old in s:
        s = s.replace(old, new)
        changes.append("ListView muestra el indicador mientras espera")
    else:
        print("AVISO: no se encontró el ListView.builder esperado; revisar a mano.", file=sys.stderr)
else:
    changes.append("ListView ya mostraba el indicador")

# d) agregar la clase _TypingIndicator al final del archivo (una
#    sola vez).
if "class _TypingIndicator" not in s:
    s += '''
/// Burbuja "escribiendo..." con 3 puntos animados, mientras se
/// espera la respuesta del backend.
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
}
'''
    changes.append("clase _TypingIndicator agregada")
else:
    changes.append("clase _TypingIndicator ya existía")

open(path, 'w', encoding='utf-8').write(s)
print("chat_screen.dart: " + "; ".join(changes) + ".")
PYEOF

echo ""
echo "============================================================"
echo " v12 aplicado. Backup: $FILE$BACKUP_SUFFIX"
echo " Siguiente paso: flutter run -d R9PT415VJQV"
echo "============================================================"
