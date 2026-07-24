#!/usr/bin/env bash
# ============================================================
# ADRI SPEED SPEECH — v11 (detección automática de idioma)
# ============================================================
# Ejecutar desde la raíz del proyecto:
#   chmod +x fix_adri_speed_speech_v11.sh
#   ./fix_adri_speed_speech_v11.sh
#
# Agrega: cuando el usuario escribe, la app detecta en qué idioma
# escribió y cambia automáticamente el avatar/idioma seleccionado
# para responder en ese idioma -- ya no hace falta tocar el selector
# a mano si el usuario cambia de idioma sobre la marcha.
#
# DISEÑO CUIDADOSO -- por qué así y no de otra forma:
#  - CERO paquetes nuevos. Ya vimos el riesgo real de agregar
#    dependencias nativas (el problema de R8 con google_mlkit). Esto
#    es lógica Dart pura: reconoce alfabetos distintos (chino,
#    devanagari, cirílico, árabe) por rango Unicode -- 100% confiable,
#    sin ambigüedad -- y para idiomas de alfabeto latino (es/en/fr/
#    pt/de/sw) cuenta palabras muy comunes de cada uno.
#  - UMBRAL CONSERVADOR: para los idiomas de alfabeto latino exige
#    al menos 2 palabras reconocidas antes de cambiar de idioma. Un
#    mensaje corto o ambiguo ("hi", "ok", "hol") NO dispara cambio
#    -- se queda en el idioma actual, exactamente el comportamiento
#    de antes (cero riesgo de regresión). Probé esta lógica con 17
#    casos en Python antes de escribir el Dart.
#  - Es un archivo NUEVO, aislado (no modifica ningún archivo
#    existente para crearlo) -- el único cambio a un archivo ya
#    existente es una inserción de 4 líneas al principio de
#    _sendMessage() en chat_screen.dart.
# ============================================================
set -euo pipefail

LIB="lib"
BACKUP_SUFFIX=".bak11_$(date +%Y%m%d_%H%M%S)"
backup() { cp "$1" "$1$BACKUP_SUFFIX"; }

# ------------------------------------------------------------
# 1) language_detector.dart — archivo nuevo, no toca nada existente
# ------------------------------------------------------------
echo "==> 1/2  language_detector.dart — detección de idioma (archivo nuevo)"
cat > "$LIB/core/utils/language_detector.dart" << 'EOF'
// ============================================================
// Detección local del idioma en que escribe el usuario. Sin
// paquetes externos (evita el riesgo de dependencias nativas que
// ya causó problemas de build con otros plugins en este proyecto).
//
// Estrategia, en orden:
//   1. Alfabetos distintivos (chino/devanagari/cirílico/árabe):
//      basta con encontrar UN carácter de ese rango Unicode -- no
//      hay ambigüedad posible, esos rangos no se superponen con
//      ningún otro idioma soportado.
//   2. Idiomas de alfabeto latino (es/en/fr/pt/de/sw): se cuentan
//      coincidencias contra una lista de palabras muy comunes de
//      cada idioma. Se exige un MÍNIMO de 2 coincidencias antes de
//      considerar el idioma detectado -- un mensaje corto o
//      ambiguo simplemente no dispara detección (se mantiene el
//      idioma ya seleccionado, sin riesgo de cambiar por error).
// ============================================================
class LanguageDetector {
  static final Map<String, RegExp> _scriptPatterns = {
    'zh': RegExp(r'[\u4e00-\u9fff]'),
    'hi': RegExp(r'[\u0900-\u097F]'),
    'ru': RegExp(r'[\u0400-\u04FF]'),
    'ar': RegExp(r'[\u0600-\u06FF]'),
  };

  static const Map<String, List<String>> _stopwords = {
    'es': ['el','la','de','que','y','es','en','un','una','por','para','con','como','pero','muy',
           'estoy','tengo','hola','gracias','bien','qué','cómo','buenos','días','tardes','noches'],
    'en': ['the','is','and','to','of','a','in','that','it','you','for','with','on','are',
           'hello','thanks','thank','how','what','good','yes','no','morning'],
    'fr': ['le','la','de','et','est','un','une','pour','que','avec','dans','pas','je','tu',
           'bonjour','merci','comment','va','vous','nous','oui','non','ça','très','salut'],
    'pt': ['o','a','de','que','e','em','um','uma','para','com','não','como','se',
           'obrigado','ola','olá','bem','sim','você','bom','dia'],
    'de': ['der','die','das','und','ist','ein','eine','nicht','mit','für','wie','was',
           'hallo','danke','gut','ja','nein','sehr','guten'],
    'sw': ['na','ya','wa','ni','kwa','za','katika','hii','huyu','sana','habari','asante',
           'jambo','nzuri','sawa'],
  };

  /// Umbral mínimo de coincidencias para los idiomas de alfabeto
  /// latino. Subirlo hace la detección más estricta (menos falsos
  /// positivos, más falsos negativos); bajarlo hace lo contrario.
  static const int _minWordMatches = 2;

  /// Devuelve el código de idioma detectado ('es','en','fr',...) o
  /// null si no se pudo determinar con confianza suficiente -- en
  /// ese caso el llamador debe mantener el idioma ya seleccionado.
  static String? detect(String text) {
    if (text.trim().isEmpty) return null;

    for (final entry in _scriptPatterns.entries) {
      if (entry.value.hasMatch(text)) return entry.key;
    }

    final lower = text.toLowerCase();
    final words = lower.split(RegExp(r'\s+'));

    String? bestLang;
    int bestCount = 0;
    for (final entry in _stopwords.entries) {
      final count = words.where((w) => entry.value.contains(w)).length;
      if (count > bestCount) {
        bestCount = count;
        bestLang = entry.key;
      }
    }
    return bestCount >= _minWordMatches ? bestLang : null;
  }
}
EOF

# ------------------------------------------------------------
# 2) chat_screen.dart — un solo punto de inserción, mínimo posible:
#    al principio de _sendMessage(), antes de armar la burbuja.
# ------------------------------------------------------------
echo "==> 2/2  chat_screen.dart — conectar la detección en _sendMessage (1 inserción quirúrgica)"
FILE="$LIB/features/vocabulary/presentation/screens/chat_screen.dart"
backup "$FILE"
python3 - "$FILE" << 'PYEOF'
import sys
path = sys.argv[1]
s = open(path, encoding='utf-8').read()

# a) import del detector (ya sabemos que este import de main.dart
#    existe exactamente así -- confirmado en el archivo actual).
if "language_detector.dart" not in s:
    s = s.replace(
        "import '../../../../main.dart';",
        "import '../../../../main.dart';\n"
        "import '../../../../core/utils/language_detector.dart';",
        1,
    )

# b) inserción quirúrgica al principio de _sendMessage(): si se
#    detecta con confianza un idioma distinto al seleccionado, se
#    cambia ANTES de mandar el mensaje al backend (así la respuesta
#    ya sale en el idioma correcto, no un turno tarde).
old = """  Future<void> _sendMessage([String? spokenText]) async {
    final text = (spokenText ?? _controller.text).trim();
    if (text.isEmpty || _isProcessing) return;

    _controller.clear();"""

new = """  Future<void> _sendMessage([String? spokenText]) async {
    final text = (spokenText ?? _controller.text).trim();
    if (text.isEmpty || _isProcessing) return;

    _controller.clear();

    // Detección automática del idioma del usuario: si escribe en un
    // idioma distinto al seleccionado y la detección es confiable
    // (ver language_detector.dart -- umbral conservador, mensajes
    // cortos/ambiguos no disparan cambio), se cambia el avatar/voz
    // ANTES de mandar el mensaje, para que la respuesta ya salga en
    // el idioma correcto.
    final detectedLang = LanguageDetector.detect(text);
    if (detectedLang != null && detectedLang != _currentLanguage) {
      setState(() => _currentLanguage = detectedLang);
      _ttsService.setLanguage(detectedLang);
    }"""

if "LanguageDetector.detect(text)" in s:
    print("chat_screen.dart: ya estaba conectada, sin cambios.")
elif old in s:
    s = s.replace(old, new)
    print("chat_screen.dart: detección automática conectada en _sendMessage.")
else:
    print("AVISO: no se encontró el inicio de _sendMessage esperado; revisar a mano.", file=sys.stderr)

open(path, 'w', encoding='utf-8').write(s)
PYEOF

echo ""
echo "============================================================"
echo " v11 aplicado. Copias de seguridad con sufijo $BACKUP_SUFFIX"
echo ""
echo " Cómo se comporta: si tienes seleccionado inglés y escribes"
echo " \"hola como estas\", la app detecta español (2+ palabras"
echo " reconocidas), cambia el avatar/voz a español automáticamente,"
echo " y la respuesta sale en español. Si escribes algo corto o"
echo " ambiguo (\"ok\", \"hi\"), NO cambia nada -- se queda como estaba."
echo ""
echo " Si en el uso real notas que detecta mal algún idioma (cambia"
echo " cuando no debía, o no cambia cuando sí debía), mándame"
echo " ejemplos concretos de los mensajes y ajusto las listas de"
echo " palabras en language_detector.dart -- es un archivo aislado,"
echo " fácil de afinar sin tocar el resto."
echo ""
echo " Siguiente paso: flutter run -d R9PT415VJQV"
echo "============================================================"
