/// Único mapa idioma -> locale del proyecto. hybrid_tts_service tenía
/// su propio switch de 9 idiomas y speech_service ni siquiera tenía
/// uno (usaba 'en_US' fijo siempre, sin importar el idioma
/// seleccionado). Ahora los dos leen de aquí.
class LocaleMap {
  static const Map<String, String> _map = {
    'en': 'en-US',
    'es': 'es-ES',
    'sw': 'sw-KE',
    'zh': 'zh-CN',
    'hi': 'hi-IN',
    'fr': 'fr-FR',
    'ru': 'ru-RU',
    'pt': 'pt-PT',
    'de': 'de-DE',
    'ar': 'ar-SA',
  };

  static String forLanguage(String lang) => _map[lang] ?? 'en-US';
}
