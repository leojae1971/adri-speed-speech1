import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../config/locale_map.dart';
import '../utils/logger.dart';

class SpeechService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String? lastError;

  bool get isListening => _isListening;

  Future<String> systemLocaleOrSpanish() async {
    try {
      final locale = await _speech.systemLocale();
      if (locale != null && locale.localeId.isNotEmpty) {
        return locale.localeId;
      }
    } catch (_) {}
    return 'es-ES';
  }

  Future<bool> initialize() async {
    lastError = null;
    final available = await _speech.initialize(
      onError: (error) {
        lastError = error.errorMsg;
        Logger.error('STT Error: ${error.errorMsg} (permanente: ${error.permanent})');
      },
      onStatus: (status) => Logger.log('STT Status: $status'),
    );
    if (!available) {
      lastError ??= 'El reconocimiento de voz no está disponible en este dispositivo.';
    }
    return available;
  }

  Future<bool> listen({
    required String localeId,
    required Function(String locale) onLanguageDetected,
    required Function(String text) onResult,
  }) async {
    lastError = null;
    if (!_speech.isAvailable) {
      final ok = await initialize();
      if (!ok) return false;
    }

    _isListening = true;

    try {
      await _speech.listen(
        onResult: (result) {
          Logger.log('STT resultado parcial="${result.recognizedWords}" final=${result.finalResult}');
          if (result.finalResult) {
            final text = result.recognizedWords;
            onLanguageDetected(localeId);
            onResult(text);
            _isListening = false;
          }
        },
        localeId: localeId,
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
