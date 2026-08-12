import 'dart:developer' as developer;

/// Única clase de logging del proyecto. Antes coexistían dos nombres
/// distintos (`Logger` aquí, `LinguaLogger` usado en otros 5+
/// archivos sin estar definido en ningún lado) — eso rompía la
/// compilación de camera_translation_service.dart,
/// backend_warmup_service.dart y vocabulary_repository_impl.dart.
/// Todas las llamadas del proyecto deben usar `Logger.*` de aquí
/// en adelante.
class Logger {
  static void log(String message, {String tag = 'ADRI'}) {
    developer.log(message, name: tag);
  }

  static void info(String message, {String tag = 'ADRI'}) {
    developer.log('INFO: $message', name: tag);
  }

  static void warning(String message, {String tag = 'ADRI'}) {
    developer.log('WARNING: $message', name: tag);
  }

  static void error(String message,
      {String tag = 'ADRI', Object? error, StackTrace? stackTrace}) {
    developer.log('ERROR: $message', name: tag, error: error, stackTrace: stackTrace);
  }
}
