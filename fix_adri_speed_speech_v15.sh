#!/usr/bin/env bash
# ============================================================
# ADRI SPEED SPEECH — v15
# ============================================================
# Ejecutar desde la raíz del proyecto:
#   chmod +x fix_adri_speed_speech_v15.sh
#   ./fix_adri_speed_speech_v15.sh
#
# Corrige:
#
#  1. MICRÓFONO -- causa adicional encontrada: el modo de
#     reconocimiento usado (`ListenMode.confirmation`) está pensado
#     para respuestas cortas tipo sí/no, y corta el reconocimiento
#     agresivamente ante cualquier silencio breve -- una frase
#     conversacional normal puede no alcanzar a generar un resultado
#     "final" antes de que el motor la dé por terminada. Se cambia a
#     `ListenMode.dictation` (pensado para frases largas) y se fijan
#     tiempos explícitos de escucha/pausa. Además, ahora CUALQUIER
#     error del motor de voz (no solo el de inicialización) se
#     guarda y se puede mostrar en pantalla -- antes solo quedaba en
#     el log, invisible para ti.
#
#     IMPORTANTE, lo repito porque sigue siendo mi sospecha más
#     fuerte para "se activa pero no pasa nada": si
#     android/app/src/main/AndroidManifest.xml no tiene el permiso
#     de micrófono declarado, Android puede dejar que la app
#     *parezca* escuchar sin generar ningún resultado, sin ningún
#     error visible tampoco. Ver el aviso al final del script.
#
#  2. BOCA -- rediseño completo: ya no es un solo bloque de color
#     (la "mancha" que reportaste). Ahora se dibujan labio superior
#     e inferior como dos formas FINAS y separadas (el inferior algo
#     más lleno que el superior, como en una boca real), con el
#     color real de labio de cada avatar. Al hablar, se separan un
#     poco (sutil, no exagerado) dejando ver un interior oscuro
#     entre ellos -- movimiento pequeño y perceptible, no un cambio
#     brusco.
#
#  3. EXPRESIONES -- se sube más la sensibilidad del movimiento de
#     cejas (ya se había subido una vez; con la boca rediseñada
#     ahora también contribuye más al conjunto) para que el cambio
#     entre las 15 expresiones se note, sin llegar a verse exagerado.
# ============================================================
set -euo pipefail

LIB="lib"
BACKUP_SUFFIX=".bak15_$(date +%Y%m%d_%H%M%S)"
backup() { cp "$1" "$1$BACKUP_SUFFIX"; }

# ------------------------------------------------------------
# 1) speech_service.dart — modo dictation + duraciones + errores
#    visibles.
# ------------------------------------------------------------
echo "==> 1/2  speech_service.dart — modo de reconocimiento correcto + errores visibles"
FILE="$LIB/core/services/speech_service.dart"
backup "$FILE"
python3 - "$FILE" << 'PYEOF'
import sys
path = sys.argv[1]
s = open(path, encoding='utf-8').read()

if "lastError" in s:
    print("speech_service.dart: ya tenía el rediseño de errores/modo, sin cambios.")
else:
    old_class_head = """class SpeechService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;

  bool get isListening => _isListening;"""
    new_class_head = """class SpeechService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;

  /// Último error reportado por el motor de voz (inicialización O
  /// durante la escucha) -- antes solo quedaba en el log, invisible
  /// para quien usa la app. null si el último intento no tuvo error.
  String? lastError;

  bool get isListening => _isListening;"""
    assert old_class_head in s, "no se encontró el inicio de la clase SpeechService"
    s = s.replace(old_class_head, new_class_head)

    old_init = """  Future<bool> initialize() async {
    final available = await _speech.initialize(
      onError: (error) => Logger.error('STT Error: $error'),
      onStatus: (status) => Logger.log('STT Status: $status'),
    );
    return available;
  }"""
    new_init = """  Future<bool> initialize() async {
    lastError = null;
    final available = await _speech.initialize(
      onError: (error) {
        lastError = error.errorMsg;
        Logger.error(
            'STT Error: ${error.errorMsg} (permanente: ${error.permanent})');
      },
      onStatus: (status) => Logger.log('STT Status: $status'),
    );
    if (!available) {
      lastError ??= 'El reconocimiento de voz no está disponible en este '
          'dispositivo (revisa el permiso de micrófono en Ajustes).';
    }
    return available;
  }"""
    assert old_init in s, "no se encontró initialize() en el formato esperado"
    s = s.replace(old_init, new_init)

    old_listen = """  Future<bool> listen({
    required String localeId,
    required Function(String locale) onLanguageDetected,
    required Function(String text) onResult,
  }) async {
    if (!_speech.isAvailable) {
      final ok = await initialize();
      if (!ok) return false; // permiso denegado o motor no disponible
    }

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
    return true;
  }"""
    new_listen = """  Future<bool> listen({
    required String localeId,
    required Function(String locale) onLanguageDetected,
    required Function(String text) onResult,
  }) async {
    lastError = null;
    if (!_speech.isAvailable) {
      final ok = await initialize();
      if (!ok) return false; // permiso denegado o motor no disponible
    }

    _isListening = true;

    await _speech.listen(
      onResult: (result) {
        Logger.log('STT resultado parcial="${result.recognizedWords}" '
            'final=${result.finalResult}');
        if (result.finalResult) {
          final text = result.recognizedWords;
          onLanguageDetected(localeId);
          onResult(text);
          _isListening = false;
        }
      },
      localeId: localeId,
      // FIX: 'confirmation' está pensado para respuestas cortas tipo
      // sí/no y corta el reconocimiento ante cualquier silencio breve
      // -- una frase conversacional normal puede no alcanzar a
      // generar resultado "final" antes de que el motor la corte.
      // 'dictation' está pensado para frases largas, como esta app
      // necesita.
      listenMode: stt.ListenMode.dictation,
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 4),
      partialResults: true,
    );
    return true;
  }"""
    assert old_listen in s, "no se encontró listen() en el formato esperado"
    s = s.replace(old_listen, new_listen)

    open(path, 'w', encoding='utf-8').write(s)
    print("speech_service.dart: modo dictation + duraciones + errores visibles agregados.")
PYEOF

# ------------------------------------------------------------
# 2) chat_screen.dart — mostrar el error real (lastError) si el
#    micrófono falla, no un mensaje genérico.
# ------------------------------------------------------------
FILE="$LIB/features/vocabulary/presentation/screens/chat_screen.dart"
backup "$FILE"
python3 - "$FILE" << 'PYEOF'
import sys
path = sys.argv[1]
s = open(path, encoding='utf-8').read()

old = """    if (!started) {
      _speechState.setState_(AdriState.idle);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo activar el micrófono. Revisa que la app tenga '
              'permiso de micrófono en Ajustes del teléfono.',
            ),
            duration: Duration(seconds: 4),
          ),
        );
      }
    }"""
new = """    if (!started) {
      _speechState.setState_(AdriState.idle);
      if (mounted) {
        final detail = _speechService.lastError;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              detail != null
                  ? 'Micrófono: $detail'
                  : 'No se pudo activar el micrófono. Revisa que la app '
                      'tenga permiso de micrófono en Ajustes del teléfono.',
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }"""
if old in s:
    s = s.replace(old, new)
    print("chat_screen.dart: SnackBar ahora muestra el error real del micrófono.")
elif "final detail = _speechService.lastError;" in s:
    print("chat_screen.dart: ya mostraba el error real, sin cambios.")
else:
    print("AVISO: no se encontró el bloque de SnackBar esperado; revisar a mano.", file=sys.stderr)

open(path, 'w', encoding='utf-8').write(s)
PYEOF

# ------------------------------------------------------------
# 3) adri_avatar_widget.dart — boca rediseñada (labio superior +
#    inferior separados, sutiles) + cejas más perceptibles.
# ------------------------------------------------------------
echo "==> 2/2  adri_avatar_widget.dart — boca con labios reales separados + expresiones más notorias"
FILE="$LIB/core/services/avatar/adri_avatar_widget.dart"
backup "$FILE"
python3 - "$FILE" << 'PYEOF'
import sys
path = sys.argv[1]
s = open(path, encoding='utf-8').read()
changes = []

# a) _drawMouth: rediseño completo. Único en el archivo (verificado:
#    "void _drawMouth(Canvas canvas" aparece 1 sola vez).
assert s.count("void _drawMouth(Canvas canvas") == 1, \
    "se esperaba encontrar _drawMouth una sola vez; revisar a mano antes de continuar"

old_mouth = """  void _drawMouth(Canvas canvas, Offset center, double scale) {
    // Rediseño: con la boca CERRADA no se dibuja nada -- se deja ver
    // la boca real de la foto, que siempre es más fiel que cualquier
    // forma pintada encima (antes se pintaba un bloque rosado fijo
    // incluso en reposo, por eso "no tenía nada que ver" con labios
    // reales).
    if (viseme == Viseme.closed) return;

    // Posición y ancho medidos con MediaPipe sobre las 10 fotos
    // reales (promedio), transformados al recorte cuadrado de
    // BoxFit.cover (ver nota en paint()).
    final mouthCenter = Offset(
      center.dx,
      center.dy + (0.374 - 0.5) * scale,
    );
    final width = 0.194 * scale;
    final height = _getMouthHeight() * scale;

    // Forma exterior con el color de labio REAL de este avatar (antes
    // era un rosado único para los 10) -- da sensación de labios
    // abriéndose en vez de un bloque de color plano.
    final outerPaint = Paint()
      ..color = lipColor
      ..style = PaintingStyle.fill;
    final outerRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: mouthCenter, width: width, height: height),
      Radius.circular(height / 2),
    );
    canvas.drawRRect(outerRect, outerPaint);

    // Apertura interior más oscura -- simula dientes/sombra de una
    // boca realmente abierta. No se dibuja en "smile" (sonrisa
    // cerrada, sin apertura visible).
    if (viseme != Viseme.smile) {
      final innerPaint = Paint()
        ..color = const Color(0xFF3A2020)
        ..style = PaintingStyle.fill;
      final innerRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: mouthCenter,
          width: width * 0.72,
          height: height * 0.55,
        ),
        Radius.circular(height * 0.3),
      );
      canvas.drawRRect(innerRect, innerPaint);
    }
  }"""

new_mouth = """  void _drawMouth(Canvas canvas, Offset center, double scale) {
    // Con la boca CERRADA no se dibuja nada -- se deja ver la boca
    // real de la foto (siempre más fiel que cualquier forma pintada).
    if (viseme == Viseme.closed) return;

    // Posición y ancho medidos con MediaPipe sobre las 10 fotos
    // reales (promedio), transformados al recorte cuadrado de
    // BoxFit.cover (ver nota en paint()).
    final mouthCenter = Offset(
      center.dx,
      center.dy + (0.374 - 0.5) * scale,
    );
    final width = 0.194 * scale;

    // Rediseño: en vez de UN bloque de color (la "mancha" reportada),
    // se dibujan labio SUPERIOR e INFERIOR como dos formas finas y
    // SEPARADAS por un hueco pequeño -- el inferior un poco más
    // lleno que el superior, como en una boca real. El hueco crece
    // sutilmente según cuánto está "hablando" ese fragmento.
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

    // Interior visible solo si de verdad hay separación entre los
    // labios (evita un hueco oscuro visible en aperturas mínimas).
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
  }"""

if old_mouth in s:
    s = s.replace(old_mouth, new_mouth)
    changes.append("_drawMouth rediseñado (labio superior/inferior separados)")
elif "_getMouthGap()" in s and "upperThickness" in s:
    changes.append("_drawMouth ya estaba rediseñado")
else:
    print("AVISO: no se encontró _drawMouth en el formato esperado; revisar a mano.", file=sys.stderr)

# b) _getMouthHeight (dentro de _FacePainter, identificado por
#    "switch (viseme)" -- el de _AdriAvatarWidgetState usa
#    "switch (_currentViseme)", así que no hay ambigüedad) se
#    renombra/redefine como _getMouthGap con valores más sutiles.
old_height_fn = """    double _getMouthHeight() {
    return switch (viseme) {
      Viseme.closed => 0.03,
      Viseme.half   => 0.06,
      Viseme.open   => 0.09,
      Viseme.wide   => 0.12,
      Viseme.round  => 0.10,
      Viseme.smile  => 0.045,
    };
  }"""
new_height_fn = """    double _getMouthGap() {
    // Valores pequeños y sutiles a propósito -- el hueco entre labio
    // superior e inferior, no la altura de un bloque completo.
    return switch (viseme) {
      Viseme.closed => 0.0,
      Viseme.half   => 0.014,
      Viseme.open   => 0.028,
      Viseme.wide   => 0.038,
      Viseme.round  => 0.032,
      Viseme.smile  => 0.006,
    };
  }"""
if old_height_fn in s:
    s = s.replace(old_height_fn, new_height_fn)
    changes.append("_getMouthHeight -> _getMouthGap con valores sutiles")
elif "_getMouthGap() {" in s and "Viseme.wide   => 0.038," in s:
    changes.append("_getMouthGap ya existía")
else:
    print("AVISO: no se encontró _getMouthHeight (en _FacePainter) esperado; revisar a mano.", file=sys.stderr)

# c) cejas: más sensibilidad de movimiento (para que las 15
#    expresiones se noten más).
old_lift = "    final liftNorm = browLift / 40.0 * scale;"
new_lift = "    final liftNorm = browLift / 28.0 * scale; // más sensible -- las expresiones no se notaban"
if old_lift in s:
    s = s.replace(old_lift, new_lift)
    changes.append("sensibilidad de cejas subida (/40.0 -> /28.0)")
elif "/ 28.0 * scale" in s:
    changes.append("sensibilidad de cejas ya estaba subida")

open(path, 'w', encoding='utf-8').write(s)
print("adri_avatar_widget.dart: " + ("; ".join(changes) + "." if changes else "sin cambios."))
PYEOF

echo ""
echo "============================================================"
echo " v15 aplicado. Copias de seguridad con sufijo $BACKUP_SUFFIX"
echo ""
echo " SOBRE EL MICRÓFONO -- si sigue sin funcionar después de esto,"
echo " el sospechoso número uno sigue siendo el mismo de varias"
echo " rondas atrás y que no he podido confirmar: revisa que"
echo " android/app/src/main/AndroidManifest.xml tenga, dentro de"
echo " <manifest ...>:"
echo ""
echo '   <uses-permission android:name="android.permission.RECORD_AUDIO"/>'
echo ""
echo " Si no está, Android puede dejar que la app 'parezca' escuchar"
echo " sin generar ningún resultado NI ningún error visible. Pégame"
echo " el contenido de ese archivo si no estás segura -- con eso sí"
echo " puedo confirmarlo en vez de seguir sospechando."
echo ""
echo " Siguiente paso: flutter run -d R9PT415VJQV"
echo "============================================================"
