#!/usr/bin/env bash
# ============================================================
# ADRI SPEED SPEECH — v9
# ============================================================
# Ejecutar desde la raíz del proyecto:
#   chmod +x fix_adri_speed_speech_v9.sh
#   ./fix_adri_speed_speech_v9.sh
#
# Corrige, cada uno verificado por separado:
#
#  1. La franja amarilla/negra en el selector de idioma ES el aviso
#     de overflow de Flutter ("BOTTOM OVERFLOWED"): la lista de 10
#     idiomas no cabía en pantalla y no tenía scroll, por eso árabe,
#     portugués y alemán quedaban tapados. Se hace scrollable con
#     altura máxima (70% de la pantalla).
#
#  2. Cejas rediseñadas: antes eran una línea recta gruesa pegada
#     encima de la foto (se veía postiza). Ahora es un arco sutil
#     más angosto (imita la curva natural de una ceja) y más fino.
#     Además, el movimiento entre expresiones se TRIPLICA: al
#     apagar los ojos, las cejas quedaron como el único canal visual
#     de expresión aparte de la boca, y el movimiento anterior (unos
#     pocos píxeles) era casi imperceptible.
#
#  3. Se intenta fijar explícitamente el motor "Google Text-to-
#     Speech" (com.google.android.tts) en vez del que Android haya
#     elegido por defecto. Causa probable de "voz metálica": si el
#     teléfono tiene más de un motor TTS instalado (ej. el del
#     fabricante, Samsung/Xiaomi/etc.), Android puede estar usando
#     uno de menor calidad en vez de Google. Si el teléfono no tiene
#     Google TTS instalado, esto no falla — sigue con el que haya,
#     silenciosamente.
#
#  4. Cada expresión se queda en pantalla un poco más de tiempo
#     mínimo (180ms -> 350ms) para que alcance a notarse el cambio
#     en vez de sucederse demasiado rápido.
#
# NO TOCA nada más de lo que ya funciona -- cada paso verifica el
# texto exacto antes de cambiarlo, y si no lo encuentra, avisa y
# sigue sin romper nada (no se detiene a mitad de camino).
# ============================================================
set -euo pipefail

LIB="lib"
BACKUP_SUFFIX=".bak9_$(date +%Y%m%d_%H%M%S)"
backup() { cp "$1" "$1$BACKUP_SUFFIX"; }

# ------------------------------------------------------------
# 1) chat_screen.dart — selector de idioma con scroll (fix overflow)
# ------------------------------------------------------------
echo "==> 1/3  chat_screen.dart — selector de idioma con scroll (fix del overflow)"
FILE="$LIB/features/vocabulary/presentation/screens/chat_screen.dart"
backup "$FILE"
python3 - "$FILE" << 'PYEOF'
import sys
path = sys.argv[1]
s = open(path, encoding='utf-8').read()

old = """  void _showLanguageSelector() {
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
  }"""

new = """  void _showLanguageSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        // FIX: antes esta lista de 10 idiomas iba dentro de un Column
        // sin scroll -- en pantallas más chicas se salía por abajo
        // (el aviso amarillo/negro de Flutter, "BOTTOM OVERFLOWED"),
        // tapando árabe/portugués/alemán. Ahora tiene altura máxima
        // y scroll propio, así siempre caben los 10 sin importar el
        // tamaño de pantalla.
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
  }"""

if old in s:
    s = s.replace(old, new)
    print("chat_screen.dart: selector de idioma ahora es scrollable.")
elif "isScrollControlled: true" in s and "ConstrainedBox" in s:
    print("chat_screen.dart: el selector ya era scrollable, sin cambios.")
else:
    print("AVISO: no se encontró _showLanguageSelector en el formato esperado; revisar a mano.", file=sys.stderr)

open(path, 'w', encoding='utf-8').write(s)
PYEOF

# ------------------------------------------------------------
# 2) chat_screen.dart — duración mínima por expresión (180ms -> 350ms)
# ------------------------------------------------------------
echo "==> 2/3  chat_screen.dart — más tiempo mínimo por expresión (se note el cambio)"
FILE="$LIB/features/vocabulary/presentation/screens/chat_screen.dart"
python3 - "$FILE" << 'PYEOF'
import sys
path = sys.argv[1]
s = open(path, encoding='utf-8').read()

old = "final ms = (cue.text.length / charsPerSecond * 1000).clamp(180, 4000).toInt();"
new = "final ms = (cue.text.length / charsPerSecond * 1000).clamp(350, 4000).toInt();"

if old in s:
    s = s.replace(old, new)
    print("chat_screen.dart: duración mínima por expresión subida a 350ms.")
elif "clamp(350, 4000)" in s:
    print("chat_screen.dart: ya estaba en 350ms, sin cambios.")
else:
    print("AVISO: no se encontró el clamp(180, 4000) esperado; revisar a mano.", file=sys.stderr)

open(path, 'w', encoding='utf-8').write(s)
PYEOF

# ------------------------------------------------------------
# 3) adri_avatar_widget.dart — cejas más pequeñas/naturales +
#    movimiento de expresión más visible + intento de motor TTS
#    en hybrid_tts_service.dart
# ------------------------------------------------------------
echo "==> 3/3  adri_avatar_widget.dart — cejas rediseñadas + hybrid_tts_service.dart — motor Google TTS"
FILE="$LIB/core/services/avatar/adri_avatar_widget.dart"
backup "$FILE"
python3 - "$FILE" << 'PYEOF'
import sys
path = sys.argv[1]
s = open(path, encoding='utf-8').read()
changes = []

old_fn = """  void _drawEyebrow(
      Canvas canvas, Offset center, double scale, double rx, double ry) {
    final paint = Paint()
      ..color = _browColor.withOpacity(0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final liftNorm = browLift / 120.0 * scale;
    final pos = Offset(
      center.dx + (rx - 0.5) * scale,
      center.dy + (ry - 0.5) * scale + liftNorm,
    );

    canvas.drawLine(
      Offset(pos.dx - 0.05 * scale, pos.dy),
      Offset(pos.dx + 0.05 * scale, pos.dy),
      paint,
    );
  }"""

new_fn = """  void _drawEyebrow(
      Canvas canvas, Offset center, double scale, double rx, double ry) {
    final paint = Paint()
      ..color = _browColor.withOpacity(0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    // Movimiento x3 más visible que antes: al no dibujar los ojos,
    // la ceja quedó como el único canal (junto a la boca) para que
    // se note el cambio de expresión, así que el desplazamiento
    // tenía que ser más notorio (antes: 120.0, casi imperceptible).
    final liftNorm = browLift / 40.0 * scale;
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
  }"""

if old_fn in s:
    s = s.replace(old_fn, new_fn)
    changes.append("cejas rediseñadas (arco natural, más angostas, movimiento x3)")
elif "quadraticBezierTo" in s and "halfWidth = 0.036" in s:
    changes.append("cejas ya estaban rediseñadas, sin cambios")
else:
    print("AVISO: no se encontró _drawEyebrow en el formato esperado; revisar a mano.", file=sys.stderr)

open(path, 'w', encoding='utf-8').write(s)
print("adri_avatar_widget.dart: " + ("; ".join(changes) + "." if changes else "sin cambios."))
PYEOF

FILE="$LIB/core/services/hybrid_tts_service.dart"
backup "$FILE"
python3 - "$FILE" << 'PYEOF'
import sys
path = sys.argv[1]
s = open(path, encoding='utf-8').read()

old = """  Future<void> initialize() async {
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
    await _flutterTts.awaitSpeakCompletion(true);"""

new = """  Future<void> initialize() async {
    // Intenta forzar el motor "Google Text-to-Speech" en vez del
    // que Android haya elegido por defecto -- causa probable de la
    // voz "metálica": si el teléfono tiene más de un motor TTS
    // instalado (el del fabricante, p.ej.), puede estar usando uno
    // de menor calidad. Si el teléfono no tiene Google TTS
    // instalado o el plugin no soporta setEngine (iOS no lo tiene),
    // esto no rompe nada -- sigue con el motor que ya estaba.
    try {
      final engines = await _flutterTts.getEngines;
      if (engines is List && engines.contains('com.google.android.tts')) {
        await _flutterTts.setEngine('com.google.android.tts');
        Logger.log('TTS: motor fijado a Google Text-to-Speech.');
      } else {
        Logger.log('TTS: Google Text-to-Speech no está instalado en este '
            'dispositivo; usando el motor por defecto ($engines).');
      }
    } catch (e) {
      Logger.log('TTS: no se pudo listar/fijar el motor ($e); usando el default.');
    }

    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
    await _flutterTts.awaitSpeakCompletion(true);"""

if old in s:
    s = s.replace(old, new)
    print("hybrid_tts_service.dart: intento de fijar motor Google TTS agregado.")
elif "com.google.android.tts" in s:
    print("hybrid_tts_service.dart: ya intentaba fijar el motor, sin cambios.")
else:
    print("AVISO: no se encontró initialize() en el formato esperado; revisar a mano.", file=sys.stderr)

open(path, 'w', encoding='utf-8').write(s)
PYEOF

echo ""
echo "============================================================"
echo " v9 aplicado. Copias de seguridad con sufijo $BACKUP_SUFFIX"
echo ""
echo " Sobre la voz \"metálica\": si sigue igual después de esto, ya"
echo " no es algo que el código pueda arreglar -- corre 'flutter"
echo " logs' mientras habla Adri y busca líneas que empiecen con"
echo " \"TTS:\" — te van a decir exactamente qué motor y qué idiomas"
echo " tiene disponibles el teléfono. Desde ahí, en Ajustes >"
echo " Accesibilidad (o Administración general) > Texto a voz, se"
echo " puede cambiar el motor preferido e instalar/descargar voces"
echo " de mejor calidad por idioma."
echo ""
echo " Siguiente paso: flutter run -d R9PT415VJQV"
echo "============================================================"
