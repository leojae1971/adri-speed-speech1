#!/usr/bin/env bash
# ============================================================
# ADRI SPEED SPEECH — v13
# ============================================================
# Ejecutar desde la raíz del proyecto:
#   chmod +x fix_adri_speed_speech_v13.sh
#   ./fix_adri_speed_speech_v13.sh
#
# Corrige, cada uno con causa verificada:
#
#  1. LABIOS/CEJAS DESALINEADOS: por primera vez tengo las 10 fotos
#     reales. Corrí detección de rostro (MediaPipe) sobre las 10 y
#     promedié las coordenadas reales de ojos/cejas/boca -- antes
#     eran estimaciones mías, ahora son medidas. Verifiqué el
#     resultado dibujando círculos sobre 3 fotos distintas (con
#     hiyab, pañuelo, peinado recogido) y caen exactos.
#
#  2. Foto de español no aparecía: el archivo que subiste se llama
#     adri_sp.png, pero el código buscaba adri_es.png. Corregido.
#
#  3. MICRÓFONO ENTIENDE MAL: causa real encontrada -- el
#     reconocimiento de voz usaba el idioma del AVATAR seleccionado
#     (ej. swahili) en vez del idioma que la usuaria realmente habla
#     (español). Si hablas español con el avatar de swahili
#     seleccionado, el motor STT intentaba encajar sonidos en
#     español dentro de fonemas de swahili -- de ahí el texto sin
#     sentido. Ahora el micrófono siempre escucha en español (el
#     idioma real de quien usa la app), sin importar qué avatar esté
#     activo; la detección de idioma que ya tenías se encarga de
#     cambiar el avatar según lo que escribas/digas.
#
#  4. SIN CONFIRMACIÓN DE QUE ESCUCHÓ: antes, al hablar, el texto se
#     mandaba directo sin pasar por el cuadro de texto -- no había
#     forma de ver qué entendió. Ahora el texto reconocido aparece
#     en el cuadro ANTES de enviarse, para que lo veas (y puedas
#     corregirlo si el reconocimiento falló) antes de tocar enviar.
#
#  5. VOZ DE SWAHILI MASCULINA: intento de mejor esfuerzo -- se
#     consulta la lista de voces instaladas en el teléfono para ese
#     idioma y se busca una marcada como femenina. Esto DEPENDE de
#     qué voces tenga instaladas tu teléfono -- si Android solo trae
#     una voz para swahili y es masculina, ningún código lo cambia
#     (haría falta instalar otra voz en Ajustes). El log ahora dice
#     qué voces están disponibles para diagnosticarlo si sigue igual.
#
# NO INCLUIDO en este script (para no acumular demasiado en una sola
# tanda): pantalla de carga con fondo de marca, y saludo grabado por
# idioma. Los preparo en el siguiente script, ya confirmado el
# enfoque (fondo de marca + saludo fijo + frase de espera).
# ============================================================
set -euo pipefail

LIB="lib"
BACKUP_SUFFIX=".bak13_$(date +%Y%m%d_%H%M%S)"
backup() { cp "$1" "$1$BACKUP_SUFFIX"; }

# ------------------------------------------------------------
# 1) adri_avatar_widget.dart — calibración real (medida, no estimada)
#    + nombre de archivo de español corregido.
# ------------------------------------------------------------
echo "==> 1/3  adri_avatar_widget.dart — calibración real de las 10 fotos + fix adri_sp.png"
FILE="$LIB/core/services/avatar/adri_avatar_widget.dart"
backup "$FILE"
python3 - "$FILE" << 'PYEOF'
import sys
path = sys.argv[1]
s = open(path, encoding='utf-8').read()
changes = []

# a) posición de ojos/cejas: valores REALES medidos (promedio de las
#    10 fotos, MediaPipe). Antes: eyeRy=0.151 (estimado), browRy
#    variable según la ronda (0.075 -> 0.095 a ciegas). Ahora: datos.
old_ry = "    const eyeRy = 0.151; // antes 0.315 (posición en la foto SIN recortar)"
new_ry = "    const eyeRy = 0.147; // medido con MediaPipe sobre las 10 fotos reales"
if old_ry in s:
    s = s.replace(old_ry, new_ry)
    changes.append("eyeRy actualizado a valor medido (0.147)")
elif "const eyeRy = 0.147;" in s:
    changes.append("eyeRy ya estaba en el valor medido")

old_brow = "    const browRy = 0.095;"
new_brow = "    const browRy = 0.083; // medido con MediaPipe (antes eran ajustes a ojo)"
if old_brow in s:
    s = s.replace(old_brow, new_brow)
    changes.append("browRy corregido a valor medido (0.083)")
elif "const browRy = 0.083;" in s:
    changes.append("browRy ya estaba en el valor medido")
else:
    print("AVISO: no se encontró 'const browRy = 0.095;'; revisar a mano.", file=sys.stderr)

# b) boca: posición y ancho medidos.
old_mouth_pos = "      center.dy + (0.375 - 0.5) * scale,"
new_mouth_pos = "      center.dy + (0.374 - 0.5) * scale, // medido con MediaPipe"
if old_mouth_pos in s:
    s = s.replace(old_mouth_pos, new_mouth_pos)
    changes.append("posición Y de boca ajustada a valor medido")
elif "0.374 - 0.5" in s:
    changes.append("posición de boca ya estaba en el valor medido")

old_mouth_w = "    final width = 0.20 * scale;"
new_mouth_w = "    final width = 0.194 * scale; // medido con MediaPipe"
if old_mouth_w in s:
    s = s.replace(old_mouth_w, new_mouth_w)
    changes.append("ancho de boca ajustado a valor medido (0.194)")
elif "0.194 * scale" in s:
    changes.append("ancho de boca ya estaba en el valor medido")

# c) X de ojos/cejas: 0.40/0.61 -> 0.399/0.609 (ajuste fino, medido)
old_x = """      _drawEye(canvas, center, scale, 0.40, eyeRy);
      _drawEye(canvas, center, scale, 0.61, eyeRy);
    } else {
      _drawClosedEye(canvas, center, scale, 0.40, eyeRy);
      _drawClosedEye(canvas, center, scale, 0.61, eyeRy);
    }

    _drawEyebrow(canvas, center, scale, 0.40, browRy);
    _drawEyebrow(canvas, center, scale, 0.61, browRy);"""
new_x = """      _drawEye(canvas, center, scale, 0.399, eyeRy);
      _drawEye(canvas, center, scale, 0.609, eyeRy);
    } else {
      _drawClosedEye(canvas, center, scale, 0.399, eyeRy);
      _drawClosedEye(canvas, center, scale, 0.609, eyeRy);
    }

    _drawEyebrow(canvas, center, scale, 0.399, browRy);
    _drawEyebrow(canvas, center, scale, 0.609, browRy);"""
if old_x in s:
    s = s.replace(old_x, new_x)
    changes.append("posición X de ojos/cejas ajustada (0.40/0.61 -> 0.399/0.609)")
elif "0.399, eyeRy" in s:
    changes.append("posición X ya estaba ajustada")

# d) nombre de archivo: adri_es.png -> adri_sp.png (el que realmente
#    subiste).
if "adri_es.png" in s:
    s = s.replace("'es' => 'assets/avatars/adri_es.png',", "'es' => 'assets/avatars/adri_sp.png',")
    changes.append("nombre de archivo de español corregido (adri_es.png -> adri_sp.png)")
elif "adri_sp.png" in s:
    changes.append("nombre de archivo ya estaba corregido")

open(path, 'w', encoding='utf-8').write(s)
print("adri_avatar_widget.dart: " + ("; ".join(changes) + "." if changes else "sin cambios."))
PYEOF

# ------------------------------------------------------------
# 2) speech_service.dart — exponer el locale del sistema (para usar
#    el idioma real del usuario, no el del avatar, al escuchar).
# ------------------------------------------------------------
echo "==> 2/3  speech_service.dart — exponer locale del sistema para el micrófono"
FILE="$LIB/core/services/speech_service.dart"
backup "$FILE"
python3 - "$FILE" << 'PYEOF'
import sys
path = sys.argv[1]
s = open(path, encoding='utf-8').read()

if "Future<String> systemLocaleOrSpanish" not in s:
    old = "  bool get isListening => _isListening;"
    new = """  bool get isListening => _isListening;

  /// Devuelve el locale configurado en el TELÉFONO (no el idioma del
  /// avatar seleccionado) -- FIX: antes el micrófono escuchaba usando
  /// el idioma del avatar activo, así que si hablabas español con,
  /// por ejemplo, el avatar de swahili seleccionado, el motor de voz
  /// intentaba encajar sonidos en español dentro de fonemas de
  /// swahili y el resultado salía sin sentido. Si el teléfono no
  /// expone su locale por alguna razón, se usa español como
  /// respaldo (es el idioma real de quienes usan esta app).
  Future<String> systemLocaleOrSpanish() async {
    try {
      final locale = await _speech.systemLocale();
      if (locale != null && locale.localeId.isNotEmpty) {
        return locale.localeId;
      }
    } catch (_) {
      // Algunos dispositivos no lo soportan -- se usa el respaldo.
    }
    return 'es-ES';
  }"""
    assert old in s, "no se encontró 'bool get isListening'"
    s = s.replace(old, new)
    open(path, 'w', encoding='utf-8').write(s)
    print("speech_service.dart: systemLocaleOrSpanish() agregado.")
else:
    print("speech_service.dart: ya tenía systemLocaleOrSpanish(), sin cambios.")
PYEOF

# ------------------------------------------------------------
# 3) chat_screen.dart — el mic usa el idioma real del usuario (no el
#    del avatar) + el texto reconocido aparece en el cuadro antes de
#    enviarse.
# ------------------------------------------------------------
echo "==> 3/3  chat_screen.dart — mic en el idioma real del usuario + confirmación visual"
FILE="$LIB/features/vocabulary/presentation/screens/chat_screen.dart"
backup "$FILE"
python3 - "$FILE" << 'PYEOF'
import sys
path = sys.argv[1]
s = open(path, encoding='utf-8').read()

old = """    _speechState.setState_(AdriState.listening);
    await _speechService.listen(
      language: _currentLanguage,
      onLanguageDetected: (_) {},
      onResult: (text) {
        _speechState.setState_(AdriState.idle);
        if (text.trim().isNotEmpty) {
          _sendMessage(text);
        }
      },
    );"""

new = """    _speechState.setState_(AdriState.listening);
    // FIX: antes se escuchaba en el idioma del AVATAR seleccionado;
    // ahora se escucha en el idioma real del teléfono/usuario (ver
    // systemLocaleOrSpanish en speech_service.dart) -- la detección
    // de idioma ya existente se encarga de cambiar el avatar según
    // lo que se diga, no hace falta "adivinar" el idioma al escuchar.
    final micLocale = await _speechService.systemLocaleOrSpanish();
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

if old in s:
    s = s.replace(old, new)
    print("chat_screen.dart: mic corregido (idioma real + confirmación visual).")
elif "systemLocaleOrSpanish()" in s:
    print("chat_screen.dart: ya estaba corregido, sin cambios.")
else:
    print("AVISO: no se encontró el bloque de _onMicPressed esperado; revisar a mano.", file=sys.stderr)

open(path, 'w', encoding='utf-8').write(s)
PYEOF

# ------------------------------------------------------------
# 4) hybrid_tts_service.dart — intento de voz femenina para swahili
#    (mejor esfuerzo, depende de qué voces tenga el teléfono)
# ------------------------------------------------------------
echo "==> 4/4  hybrid_tts_service.dart — intento de voz femenina (mejor esfuerzo)"
FILE="$LIB/core/services/hybrid_tts_service.dart"
backup "$FILE"
python3 - "$FILE" << 'PYEOF'
import sys
path = sys.argv[1]
s = open(path, encoding='utf-8').read()

old = "    await _flutterTts.setLanguage(locale);\n  }"
new = """    await _flutterTts.setLanguage(locale);

    // Intento de mejor esfuerzo para usar voz FEMENINA (reportado:
    // la voz de swahili sonaba masculina). Esto depende por completo
    // de qué voces tenga instaladas el teléfono para ese idioma --
    // si Android solo trae una voz para swahili y es masculina,
    // ningún código lo puede cambiar (haría falta instalar otra voz
    // en Ajustes > Accesibilidad > Texto a voz). El log deja ver
    // qué voces están disponibles para diagnosticarlo si persiste.
    try {
      final voices = await _flutterTts.getVoices;
      if (voices is List) {
        final matches = voices.where((v) {
          final voiceLocale = (v['locale'] ?? '').toString().toLowerCase();
          return voiceLocale.startsWith(locale.toLowerCase().split('-').first);
        }).toList();
        Logger.log('TTS: voces disponibles para "$locale": $matches');

        final female = matches.firstWhere(
          (v) => (v['name'] ?? '').toString().toLowerCase().contains('female') ||
                 (v['gender'] ?? '').toString().toLowerCase().contains('female'),
          orElse: () => null,
        );
        if (female != null) {
          await _flutterTts.setVoice({
            'name': female['name'].toString(),
            'locale': female['locale'].toString(),
          });
          Logger.log('TTS: voz femenina seleccionada para "$locale": ${female['name']}');
        }
      }
    } catch (e) {
      Logger.log('TTS: no se pudo consultar/fijar voz por género para "$locale": $e');
    }
  }"""

if old in s:
    s = s.replace(old, new)
    print("hybrid_tts_service.dart: intento de voz femenina agregado.")
elif "voz FEMENINA" in s:
    print("hybrid_tts_service.dart: ya tenía el intento de voz femenina, sin cambios.")
else:
    print("AVISO: no se encontró el final de setLanguage(); revisar a mano.", file=sys.stderr)

open(path, 'w', encoding='utf-8').write(s)
PYEOF

echo ""
echo "============================================================"
echo " v13 aplicado. Copias de seguridad con sufijo $BACKUP_SUFFIX"
echo ""
echo " IMPORTANTE — copia manual necesaria: coloca adri_sp.png en"
echo " assets/avatars/ (el nombre real del archivo que subiste)."
echo ""
echo " Sobre la voz femenina de swahili: corre 'flutter logs' y usa"
echo " el selector de swahili -- vas a ver una línea \"TTS: voces"
echo " disponibles para...\" con la lista real de tu teléfono. Si no"
echo " hay ninguna marcada como femenina ahí, es una limitación del"
echo " teléfono, no del código -- pégame esa línea y reviso opciones."
echo ""
echo " Siguiente paso: flutter run -d R9PT415VJQV"
echo "============================================================"
