#!/usr/bin/env bash
# ============================================================
# ADRI SPEED SPEECH — v14
# ============================================================
# Ejecutar desde la raíz del proyecto:
#   chmod +x fix_adri_speed_speech_v14.sh
#   ./fix_adri_speed_speech_v14.sh
#
# Corrige:
#
#  1. BUG REAL DEL MICRÓFONO (la causa de "no funciona"): el fix de
#     idioma que apliqué en v13 (escuchar en el idioma real del
#     usuario) quedaba PISADO por un segundo mapeo dentro de
#     speech_service.dart -- se buscaba el locale ya resuelto
#     ('es-ES') como si fuera un código de idioma de 2 letras, no lo
#     encontraba, y caía siempre a inglés por defecto. El micrófono
#     nunca escuchó en español -- escuchaba en inglés siempre, sin
#     importar el idioma real ni el del avatar. Corregido de raíz.
#     Además: si el micrófono no puede inicializar (permiso negado,
#     etc.), ahora se ve un aviso en pantalla en vez de fallar en
#     silencio.
#
#  2. LABIOS: rediseñados con los colores REALES de cada una de tus
#     10 fotos (medidos con reconocimiento facial, no inventados).
#     Cuando la boca está cerrada, YA NO se dibuja nada encima --
#     se deja ver la boca real de la foto (siempre más fiel que
#     cualquier forma dibujada). Cuando habla, se dibuja con el
#     color de labio real de ESE avatar (antes era un solo rosado
#     fijo para los 10) más una apertura oscura adentro que simula
#     dientes/sombra -- ya no es una línea ni un bloque plano.
#
#  3. CEJAS: color real de cada avatar (10 tonos distintos, medidos
#     buscando el clúster de píxeles más oscuro en la zona de la
#     ceja de cada foto -- no piel, pelo real). Posición bajada un
#     poco más (0.083 -> 0.090) según tu último ajuste.
#
# Verificación hecha ANTES de tocar código: dibujé los puntos y
# colores medidos sobre 3 fotos distintas para confirmar que caían
# donde debían -- te las adjunto en el mensaje.
# ============================================================
set -euo pipefail

LIB="lib"
BACKUP_SUFFIX=".bak14_$(date +%Y%m%d_%H%M%S)"
backup() { cp "$1" "$1$BACKUP_SUFFIX"; }

# ------------------------------------------------------------
# 1) speech_service.dart — FIX del bug real (doble mapeo de locale)
#    + aviso visible si no puede inicializar.
# ------------------------------------------------------------
echo "==> 1/3  speech_service.dart — fix del bug que forzaba inglés siempre"
FILE="$LIB/core/services/speech_service.dart"
backup "$FILE"
python3 - "$FILE" << 'PYEOF'
import sys
path = sys.argv[1]
s = open(path, encoding='utf-8').read()

old = """  Future<void> listen({
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
  }"""

new = """  /// [localeId] debe venir YA RESUELTO (ej. 'es-ES'), no un código de
  /// 2 letras -- FIX de un bug real: antes este método volvía a pasar
  /// el valor por LocaleMap.forLanguage(), que espera un código como
  /// 'es', no un locale como 'es-ES'. Como 'es-ES' no existe como
  /// CLAVE en ese mapa, siempre caía al valor por defecto ('en-US') y
  /// el micrófono terminaba escuchando en inglés sin importar nada
  /// -- ni el idioma real del usuario ni el del avatar seleccionado.
  Future<bool> listen({
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

if old in s:
    s = s.replace(old, new)
    print("speech_service.dart: bug del doble mapeo corregido, listen() ahora devuelve bool.")
elif "[localeId] debe venir YA RESUELTO" in s:
    print("speech_service.dart: ya estaba corregido, sin cambios.")
else:
    print("AVISO: no se encontró listen() en el formato esperado; revisar a mano.", file=sys.stderr)

open(path, 'w', encoding='utf-8').write(s)
PYEOF

# ------------------------------------------------------------
# 2) chat_screen.dart — usar `localeId:` (ya no `language:`) +
#    aviso visible si el micrófono no pudo inicializar.
# ------------------------------------------------------------
echo "==> 2/3  chat_screen.dart — conectar el parámetro corregido + aviso si falla el mic"
FILE="$LIB/features/vocabulary/presentation/screens/chat_screen.dart"
backup "$FILE"
python3 - "$FILE" << 'PYEOF'
import sys
path = sys.argv[1]
s = open(path, encoding='utf-8').read()

old = """    final micLocale = await _speechService.systemLocaleOrSpanish();
    await _speechService.listen(
      language: micLocale,
      onLanguageDetected: (_) {},
      onResult: (text) {
        _speechState.setState_(AdriState.idle);
        if (text.trim().isNotEmpty) {
          // FIX: antes se enviaba directo sin pasar por el cuadro de
          // texto -- no había forma de confirmar qué se entendió. Se
          // muestra primero, así se puede ver (o corregir) antes de
          // enviar.
          setState(() => _controller.text = text);
        }
      },
    );"""

new = """    final micLocale = await _speechService.systemLocaleOrSpanish();
    final started = await _speechService.listen(
      localeId: micLocale,
      onLanguageDetected: (_) {},
      onResult: (text) {
        _speechState.setState_(AdriState.idle);
        if (text.trim().isNotEmpty) {
          // FIX: antes se enviaba directo sin pasar por el cuadro de
          // texto -- no había forma de confirmar qué se entendió. Se
          // muestra primero, así se puede ver (o corregir) antes de
          // enviar.
          setState(() => _controller.text = text);
        }
      },
    );
    if (!started) {
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

if old in s:
    s = s.replace(old, new)
    print("chat_screen.dart: parámetro corregido a localeId + aviso visible si falla.")
elif "localeId: micLocale" in s:
    print("chat_screen.dart: ya estaba corregido, sin cambios.")
else:
    print("AVISO: no se encontró el bloque de _onMicPressed esperado; revisar a mano.", file=sys.stderr)

open(path, 'w', encoding='utf-8').write(s)
PYEOF

# ------------------------------------------------------------
# 3) adri_avatar_widget.dart — labios y cejas con color real por
#    avatar (10), boca rediseñada, ajuste fino de posición de cejas.
# ------------------------------------------------------------
echo "==> 3/3  adri_avatar_widget.dart — labios/cejas reales + boca rediseñada"
FILE="$LIB/core/services/avatar/adri_avatar_widget.dart"
backup "$FILE"
python3 - "$FILE" << 'PYEOF'
import sys
path = sys.argv[1]
s = open(path, encoding='utf-8').read()
changes = []

# a) _browColorForLanguage: de 4 entradas (en/sw/zh/default) a 10
#    reales, medidas sobre las fotos (clúster más oscuro = pelo real
#    de la ceja, no piel).
old_brow_getter = """  Color get _browColorForLanguage {
    return switch (widget.language) {
      'en' => const Color(0xFF6B4423), // castaño medio (rubia)
      'sw' => const Color(0xFF1A1210), // casi negro
      'zh' => const Color(0xFF1F1B18), // negro azabache
      _    => const Color(0xFF2A211C), // neutro oscuro (resto de avatares)
    };
  }"""
new_brow_getter = """  // Medido con reconocimiento facial sobre las 10 fotos reales
  // (clúster de píxeles más oscuros en la zona de la ceja de cada
  // una -- no un promedio con la piel, que daba tonos muy claros).
  Color get _browColorForLanguage {
    return switch (widget.language) {
      'en' => const Color(0xFF46312B), // rubia -- ceja castaño medio
      'es' => const Color(0xFF3F281F), // castaño oscuro
      'sw' => const Color(0xFF342216), // casi negro
      'zh' => const Color(0xFF56392F), // castaño oscuro cálido
      'hi' => const Color(0xFF261C1C), // negro
      'fr' => const Color(0xFF2C2121), // negro-castaño
      'ru' => const Color(0xFF2C2020), // negro-castaño
      'pt' => const Color(0xFF221919), // negro
      'de' => const Color(0xFF3E261D), // castaño medio
      'ar' => const Color(0xFF23191B), // negro
      _    => const Color(0xFF2A211C),
    };
  }"""
if old_brow_getter in s:
    s = s.replace(old_brow_getter, new_brow_getter)
    changes.append("colores de cejas: 10 tonos reales medidos")
elif "'hi' => const Color(0xFF261C1C)" in s:
    changes.append("colores de cejas ya estaban actualizados")
else:
    print("AVISO: no se encontró _browColorForLanguage en el formato esperado; revisar a mano.", file=sys.stderr)

# b) nueva: _lipColorForLanguage (getter hermano del de cejas)
if "_lipColorForLanguage" not in s:
    anchor = "  double _getMouthHeight() {"
    lip_getter = """  // Medido con reconocimiento facial sobre las 10 fotos reales
  // (color promedio de la zona rellena del labio de cada avatar).
  Color get _lipColorForLanguage {
    return switch (widget.language) {
      'en' => const Color(0xFF9A7361),
      'es' => const Color(0xFFAB7363),
      'sw' => const Color(0xFF7B5747),
      'zh' => const Color(0xFF926B58),
      'hi' => const Color(0xFF865350),
      'fr' => const Color(0xFF95635E),
      'ru' => const Color(0xFF9B6763),
      'pt' => const Color(0xFF97615D),
      'de' => const Color(0xFFAA6B65),
      'ar' => const Color(0xFF9B6763),
      _    => const Color(0xFF9A7361),
    };
  }

  """
    if anchor in s:
        s = s.replace(anchor, lip_getter + anchor)
        changes.append("getter _lipColorForLanguage agregado (10 tonos reales)")
    else:
        print("AVISO: no se encontró el ancla para _lipColorForLanguage; revisar a mano.", file=sys.stderr)
else:
    changes.append("_lipColorForLanguage ya existía")

# c) browRy: ajuste fino final (0.083 -> 0.090)
old_browry = "    const browRy = 0.083; // medido con MediaPipe (antes eran ajustes a ojo)"
new_browry = "    const browRy = 0.090; // medido + ajuste fino según feedback visual"
if old_browry in s:
    s = s.replace(old_browry, new_browry)
    changes.append("browRy ajustado a 0.090")
elif "const browRy = 0.090;" in s:
    changes.append("browRy ya estaba en 0.090")

# d) _FacePainter: agregar campo lipColor (constructor)
old_ctor = """  final Color browColor;

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
new_ctor = """  final Color browColor;
  final Color lipColor;

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
    this.lipColor = const Color(0xFF9A7361),
  });

  static const Color _eyeColor = Color(0xFF2D1B4E);"""
if old_ctor in s:
    s = s.replace(old_ctor, new_ctor)
    changes.append("campo lipColor agregado a _FacePainter")
elif "final Color lipColor;" in s:
    changes.append("_FacePainter ya tenía lipColor")
else:
    print("AVISO: no se encontró el constructor de _FacePainter esperado; revisar a mano.", file=sys.stderr)

# e) pasar el color calculado al instanciar el painter
old_call = "                  browColor: _browColorForLanguage,\n                ),"
new_call = "                  browColor: _browColorForLanguage,\n                  lipColor: _lipColorForLanguage,\n                ),"
if old_call in s:
    s = s.replace(old_call, new_call)
    changes.append("lipColor conectado en la instanciación")
elif "lipColor: _lipColorForLanguage," in s:
    changes.append("ya estaba conectado")
else:
    print("AVISO: no se encontró la instanciación de _FacePainter esperada; revisar a mano.", file=sys.stderr)

# f) _drawMouth: rediseño completo -- nada si está cerrada, labios
#    reales + apertura oscura si está hablando.
old_mouth = """  void _drawMouth(Canvas canvas, Offset center, double scale) {
    final mouthPaint = Paint()
      ..color = _lipColor
      ..style = PaintingStyle.fill;

    // Recalibrado: 0.430 es la posición real de la boca medida con
    // MediaPipe sobre la foto SIN recortar; 0.375 es esa misma
    // posición ya transformada al recorte cuadrado (ver nota en
    // paint() sobre BoxFit.cover). Ancho real medido: 0.20 (antes
    // 0.16, la boca se dibujaba visiblemente más angosta que la real).
    final mouthCenter = Offset(
      center.dx,
      center.dy + (0.374 - 0.5) * scale, // medido con MediaPipe
    );

    final width = 0.194 * scale; // medido con MediaPipe
    final height = _getMouthHeight() * scale;

    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: mouthCenter, width: width, height: height),
      Radius.circular(height / 2),
    );

    canvas.drawRRect(rect, mouthPaint);

    final innerPaint = Paint()
      ..color = const Color(0xFFAA6E6E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawLine(
      Offset(mouthCenter.dx - width * 0.3, mouthCenter.dy),
      Offset(mouthCenter.dx + width * 0.3, mouthCenter.dy),
      innerPaint,
    );
  }"""
new_mouth = """  void _drawMouth(Canvas canvas, Offset center, double scale) {
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
if old_mouth in s:
    s = s.replace(old_mouth, new_mouth)
    changes.append("_drawMouth rediseñado (labios reales + apertura, nada si está cerrada)")
elif "Rediseño: con la boca CERRADA no se dibuja nada" in s:
    changes.append("_drawMouth ya estaba rediseñado")
else:
    print("AVISO: no se encontró _drawMouth en el formato esperado; revisar a mano.", file=sys.stderr)

open(path, 'w', encoding='utf-8').write(s)
print("adri_avatar_widget.dart: " + ("; ".join(changes) + "." if changes else "sin cambios."))
PYEOF

echo ""
echo "============================================================"
echo " v14 aplicado. Copias de seguridad con sufijo $BACKUP_SUFFIX"
echo ""
echo " El bug del micrófono (siempre en inglés) tenía una causa real"
echo " y verificable en el código -- alta confianza de que esto"
echo " resuelve el problema. Pruébalo primero."
echo ""
echo " Siguiente paso: flutter run -d R9PT415VJQV"
echo "============================================================"
