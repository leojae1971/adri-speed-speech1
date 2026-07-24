#!/usr/bin/env bash
# ============================================================
# ADRI SPEED SPEECH — v8
# ============================================================
# Ejecutar desde la raíz del proyecto:
#   chmod +x fix_adri_speed_speech_v8.sh
#   ./fix_adri_speed_speech_v8.sh
#
# Corrige:
#  1. Avatar: se quita el overlay de ojos (pediste no usarlo por
#     ahora) — se conservan cejas y boca, que sí estaban bien.
#  2. Avatar: las fotos de los 6 idiomas nuevos ya existen en
#     assets/avatars/ — se actualiza el mapeo para usar cada foto
#     real en vez de reusar las 3 originales como placeholder.
#     SUPUESTO que estoy asumiendo (avísame si el nombre real es
#     distinto): adri_hi.png, adri_fr.png, adri_ru.png, adri_pt.png,
#     adri_de.png, adri_ar.png, adri_es.png — mismo patrón que las
#     3 que ya funcionan.
#  3. TTS: se re-fija el idioma justo antes de cada _flutterTts.speak()
#     (en Android, el motor de TTS a veces "olvida" el idioma entre
#     llamadas) + se agrega un chequeo de disponibilidad de voz que
#     deja aviso en el log si el dispositivo NO tiene instalado el
#     paquete de voz de ese idioma (causa más probable del acento en
#     inglés: si el idioma no está descargado en el teléfono, Android
#     reproduce con la voz por defecto SIN dar error).
#  4. Se agrega audio de la traducción al español después de la
#     respuesta en el idioma seleccionado (antes solo se mostraba
#     el texto). OJO: esto añade tiempo real de espera (una segunda
#     locución) — si prefieres que sea opcional en vez de automático,
#     dímelo y lo cambio a un botón en vez de reproducción automática.
#
# NO TOCA (fuera de lo que puedo arreglar por código): si el
# dispositivo no tiene el paquete de voz de un idioma descargado,
# ningún código lo puede forzar — hay que instalarlo a mano en
# Ajustes > Accesibilidad > Texto a voz > tu motor > Instalar datos
# de voz, o revisar el log (con `flutter logs`) para ver el aviso
# "TTS: voz de <idioma> no disponible en este dispositivo".
# ============================================================
set -euo pipefail

LIB="lib"
BACKUP_SUFFIX=".bak8_$(date +%Y%m%d_%H%M%S)"
backup() { cp "$1" "$1$BACKUP_SUFFIX"; }

# ------------------------------------------------------------
# 1) avatar/adri_avatar_widget.dart — quitar overlay de ojos,
#    mapear las 6 fotos nuevas reales.
# ------------------------------------------------------------
echo "==> 1/2  adri_avatar_widget.dart — quitar ojos + fotos reales de los 6 idiomas nuevos"
FILE="$LIB/core/services/avatar/adri_avatar_widget.dart"
backup "$FILE"
python3 - "$FILE" << 'PYEOF'
import sys
path = sys.argv[1]
s = open(path, encoding='utf-8').read()
changes = []

# --- a) quitar el overlay de ojos (dejar cejas y boca) ---
old_eyes = """    const eyeRy = 0.151; // antes 0.315 (posición en la foto SIN recortar)
    const browRy = 0.075;
    final effectivelyBlinking = isBlinking && eyeOpen < 0.75;
    if (!effectivelyBlinking) {
      _drawEye(canvas, center, scale, 0.40, eyeRy);
      _drawEye(canvas, center, scale, 0.61, eyeRy);
    } else {
      _drawClosedEye(canvas, center, scale, 0.40, eyeRy);
      _drawClosedEye(canvas, center, scale, 0.61, eyeRy);
    }

    _drawEyebrow(canvas, center, scale, 0.40, browRy);
    _drawEyebrow(canvas, center, scale, 0.61, browRy);"""
new_eyes = """    const browRy = 0.075;
    // Overlay de ojos desactivado a pedido: la foto ya trae los ojos
    // reales, y el dibujo procedural encima se veía desalineado.
    // Se conservan cejas y boca (mueve bien y sí se ve correcto).
    _drawEyebrow(canvas, center, scale, 0.40, browRy);
    _drawEyebrow(canvas, center, scale, 0.61, browRy);"""

if old_eyes in s:
    s = s.replace(old_eyes, new_eyes)
    changes.append("overlay de ojos desactivado")
elif "Overlay de ojos desactivado a pedido" in s:
    changes.append("overlay de ojos ya estaba desactivado")
else:
    print("AVISO: no se encontró el bloque de ojos esperado; revisar a mano.", file=sys.stderr)

# --- b) mapear las 6 fotos nuevas reales (ya no reusar placeholders) ---
old_asset_block = """      // TODO: reemplazar por fotos reales cuando existan (por ahora
      // reusan las 3 fotos ya disponibles como placeholder temporal).
      'hi' => 'assets/avatars/adri_en.png',
      'fr' => 'assets/avatars/adri_sw.png',
      'ru' => 'assets/avatars/adri_zh.png',
      'pt' => 'assets/avatars/adri_en.png',
      'de' => 'assets/avatars/adri_sw.png',
      'ar' => 'assets/avatars/adri_zh.png',
      'es' => 'assets/avatars/adri_en.png',"""
new_asset_block = """      // Fotos reales (ya en assets/avatars/) — si alguno de estos
      // nombres no coincide con el archivo real, avisar para
      // corregirlo aquí.
      'hi' => 'assets/avatars/adri_hi.png',
      'fr' => 'assets/avatars/adri_fr.png',
      'ru' => 'assets/avatars/adri_ru.png',
      'pt' => 'assets/avatars/adri_pt.png',
      'de' => 'assets/avatars/adri_de.png',
      'ar' => 'assets/avatars/adri_ar.png',
      'es' => 'assets/avatars/adri_es.png',"""
if old_asset_block in s:
    s = s.replace(old_asset_block, new_asset_block)
    changes.append("mapeo de fotos actualizado a los 6 archivos reales")
elif "'hi' => 'assets/avatars/adri_hi.png'" in s:
    changes.append("mapeo de fotos ya apuntaba a los archivos reales")
else:
    print("AVISO: no se encontró el bloque de mapeo de fotos esperado; revisar a mano.", file=sys.stderr)

open(path, 'w', encoding='utf-8').write(s)
print("adri_avatar_widget.dart: " + "; ".join(changes) + "." if changes else "sin cambios.")
PYEOF

# ------------------------------------------------------------
# 2) hybrid_tts_service.dart — reescritura completa: re-fija idioma
#    antes de hablar, chequea disponibilidad, agrega speakTranslation
# ------------------------------------------------------------
echo "==> 2/2  hybrid_tts_service.dart — re-fijar idioma + chequeo de voz + audio en español"
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
  String _currentLangCode = 'en';

  bool get isSpeaking => _isSpeaking;

  Future<void> initialize() async {
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
    await _flutterTts.awaitSpeakCompletion(true);

    _flutterTts.setCompletionHandler(() {
      _isSpeaking = false;
    });

    _flutterTts.setErrorHandler((msg) {
      Logger.error('TTS Error: $msg');
      _isSpeaking = false;
    });
  }

  Future<void> setLanguage(String langCode) async {
    _currentLangCode = langCode;
    final locale = LocaleMap.forLanguage(langCode);

    // Diagnóstico: si el dispositivo NO tiene el paquete de voz de
    // este idioma instalado, Android suele usar la voz por defecto
    // SIN avisar (se percibe como "acento en inglés" o "lee como si
    // fuera inglés"). Esto no lo puede forzar el código — hay que
    // instalar el paquete de voz en Ajustes del teléfono — pero al
    // menos queda registrado en el log para saber que es la causa.
    try {
      final available = await _flutterTts.isLanguageAvailable(locale);
      if (available != true) {
        Logger.error(
            'TTS: voz de "$locale" ($langCode) NO disponible en este '
            'dispositivo. Instalar el paquete de voz en Ajustes > '
            'Accesibilidad > Texto a voz, o el audio sonará con la '
            'voz/acento por defecto del teléfono.');
      }
    } catch (e) {
      // Algunos motores TTS en Android no implementan isLanguageAvailable.
      Logger.log('TTS: no se pudo verificar disponibilidad de "$locale": $e');
    }

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

    // FIX: en algunos motores TTS de Android, el idioma "se olvida"
    // entre llamadas a speak() si hubo un stop() de por medio o pasó
    // tiempo. Re-fijarlo justo antes reduce el riesgo de que hable
    // con la voz/acento equivocado.
    await _flutterTts.setLanguage(LocaleMap.forLanguage(_currentLangCode));
    await _flutterTts.speak(text);
    _precachedText = null;
  }

  /// Habla la traducción al ESPAÑOL (el idioma del usuario),
  /// independientemente de cuál sea el idioma actualmente
  /// seleccionado para la lección — y restaura ese idioma al
  /// terminar, para que el siguiente turno hable bien de nuevo.
  /// Si el idioma actual YA es español, no hace nada (evita repetir
  /// el mismo audio dos veces).
  Future<void> speakTranslation(String spanishText) async {
    if (spanishText.isEmpty || _currentLangCode == 'es') return;
    final previousLang = _currentLangCode;

    _isSpeaking = true;
    await _flutterTts.setLanguage(LocaleMap.forLanguage('es'));
    await _flutterTts.speak(spanishText);

    // Restaurar el idioma de la lección para el próximo turno.
    await _flutterTts.setLanguage(LocaleMap.forLanguage(previousLang));
    _currentLangCode = previousLang;
    _isSpeaking = false;
  }

  Future<void> stop() async {
    _isSpeaking = false;
    await _flutterTts.stop();
  }
}
EOF

# ------------------------------------------------------------
# 3) chat_screen.dart — llamar a speakTranslation después de la
#    respuesta principal.
# ------------------------------------------------------------
echo "==> 3/3  chat_screen.dart — reproducir también la traducción al español"
FILE="$LIB/features/vocabulary/presentation/screens/chat_screen.dart"
backup "$FILE"
python3 - "$FILE" << 'PYEOF'
import sys
path = sys.argv[1]
s = open(path, encoding='utf-8').read()
before = s

old = """    await ttsFuture;
    if (mounted) setState(() => _currentAvatarExpression = null);
  }"""
new = """    await ttsFuture;
    if (mounted) setState(() => _currentAvatarExpression = null);

    // Después de la respuesta en el idioma de la lección, se habla
    // también la traducción al español (el idioma del usuario).
    // Esto añade tiempo real de espera -- si se prefiere que sea
    // opcional en vez de automático, quitar estas 2 líneas y agregar
    // un botón en la burbuja en su lugar.
    await _ttsService.speakTranslation(response.spanishTranslation);
  }"""

if old in s:
    s = s.replace(old, new)
    print("chat_screen.dart: audio de traducción al español agregado.")
elif "speakTranslation" in s:
    print("chat_screen.dart: ya estaba agregado, sin cambios.")
else:
    print("AVISO: no se encontró el final de _playTaggedResponse; revisar a mano.", file=sys.stderr)

open(path, 'w', encoding='utf-8').write(s)
PYEOF

echo ""
echo "============================================================"
echo " v8 aplicado. Copias de seguridad con sufijo $BACKUP_SUFFIX"
echo ""
echo " RECORDATORIO sobre la latencia: los fixes de timeout y de la"
echo " llamada bloqueante a Gemini que te di antes viven en el"
echo " REPOSITORIO DEL BACKEND, no en este proyecto Flutter. Si no"
echo " has hecho 'git push' / redeploy en Render desde entonces, esa"
echo " parte del arreglo todavía no está en producción — confírmalo."
echo ""
echo " Siguiente paso: flutter run -d R9PT415VJQV"
echo "============================================================"
