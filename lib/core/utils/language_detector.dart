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
