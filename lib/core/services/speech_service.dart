import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../config/locale_map.dart';
import '../utils/logger.dart';

class SpeechService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;

  /// Último error reportado por el motor de voz (inicialización O
  /// durante la escucha) -- antes solo quedaba en el log, invisible
  /// para quien usa la app. null si el último intento no tuvo error.
  String? lastError;

  bool get isListening => _isListening;

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
  }

  Future<bool> initialize() async {
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
  }

  /// [localeId] debe venir YA RESUELTO (ej. 'es-ES'), no un código de
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
    lastError = null;
    if (!_speech.isAvailable) {
      final ok = await initialize();
      if (!ok) return false; // permiso denegado o motor no disponible
    }

    _isListening = true;

    try {
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
    } catch (e) {
      _isListening = false;
      lastError = 'Error al iniciar la escucha: $e';
      Logger.error('STT listen exception', error: e);
      return false;
    }
  }

  Future<void> stop() async {
    _isListening = false;
    await _speech.stop();
  }
}