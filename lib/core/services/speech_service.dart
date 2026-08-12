import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../utils/logger.dart';

class SpeechService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String? lastError;
  bool _isInitialized = false;

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

  Future<bool> hasPermission() async {
    try {
      if (!_isInitialized) {
        final ok = await initialize();
        return ok;
      }
      return await _speech.hasPermission;
    } catch (e) {
      Logger.error('Error al verificar permiso: $e');
      return false;
    }
  }

  Future<bool> initialize() async {
    if (_isInitialized) {
      return await _speech.hasPermission;
    }
    lastError = null;
    try {
      final available = await _speech.initialize(
        onError: (error) {
          lastError = error.errorMsg;
          Logger.error('STT Error: ${error.errorMsg}');
        },
        onStatus: (status) {
          Logger.log('STT Status: $status');
          if (status == 'notListening' || status == 'done') {
            _isListening = false;
          }
        },
      );
      _isInitialized = available;
      if (!available) {
        lastError ??= 'El reconocimiento de voz no está disponible.';
        Logger.error('STT initialization failed: $lastError');
      } else {
        Logger.log('✅ STT initialized successfully');
      }
      return available;
    } catch (e) {
      lastError = 'Error al inicializar: $e';
      Logger.error(lastError!);
      return false;
    }
  }

  Future<bool> listen({
    required String localeId,
    required Function(String locale) onLanguageDetected,
    required Function(String text) onResult,
  }) async {
    lastError = null;
    print('🔵 SpeechService.listen() llamado');
    if (!_isInitialized) {
      final ok = await initialize();
      if (!ok) {
        lastError = 'El STT no se pudo inicializar.';
        print('❌ STT no inicializado');
        return false;
      }
    }

    final hasPerm = await _speech.hasPermission;
    print('🔵 Permiso en listen: $hasPerm');
    if (!hasPerm) {
      lastError = 'Permiso de micrófono denegado.';
      Logger.error(lastError!);
      return false;
    }

    if (!_speech.isAvailable) {
      lastError = 'STT no disponible ahora.';
      print('❌ STT no disponible');
      return false;
    }

    _isListening = true;

    try {
      print('🎤 Iniciando escucha con locale: $localeId');
      await _speech.listen(
        onResult: (result) {
          print('📝 STT resultado: "${result.recognizedWords}" (final=${result.finalResult})');
          if (result.finalResult) {
            final text = result.recognizedWords;
            if (text.isNotEmpty) {
              onLanguageDetected(localeId);
              onResult(text);
              _isListening = false;
            }
          }
        },
        localeId: localeId,
        listenMode: stt.ListenMode.dictation,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 4),
        partialResults: true,
      );
      print('✅ Escucha iniciada correctamente');
      return true;
    } catch (e) {
      _isListening = false;
      lastError = 'Error al escuchar: $e';
      print('❌ Excepción en listen: $e');
      Logger.error(lastError!);
      return false;
    }
  }

  Future<void> stop() async {
    _isListening = false;
    await _speech.stop();
    Logger.log('⏹️ STT detenido');
  }
}
