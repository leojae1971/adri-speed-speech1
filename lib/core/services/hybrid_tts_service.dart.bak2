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
  Future<void> speakTranslation(String text, {String lang = 'es'}) async {
    if (text.isEmpty || _currentLangCode == lang) return;
    final previousLang = _currentLangCode;

    _isSpeaking = true;
    await _flutterTts.setLanguage(LocaleMap.forLanguage(lang));
    await _flutterTts.speak(text);

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
