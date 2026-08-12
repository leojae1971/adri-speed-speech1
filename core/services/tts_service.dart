import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  final FlutterTts _tts = FlutterTts();

  TtsService() {
    _initTts();
  }

  Future<void> _initTts() async {
    // 0.35 hace que hable mucho más lento y se entienda perfecto
    await _tts.setSpeechRate(0.35); 
    await _tts.setVolume(1.0);
    // 1.1 da un tono femenino elegante y natural (sin sonar robótica)
    await _tts.setPitch(1.1); 
  }

  Future<void> speakResponse(String fullResponse, {Function(String)? onSpeaking}) async {
    final parts = fullResponse.split('|');
    
    if (parts.isNotEmpty) {
      if (onSpeaking != null) onSpeaking(parts[0].trim());
      await _tts.setLanguage("en-US");
      await _tts.speak(parts[0].trim());
      await _tts.awaitSpeakCompletion(true);

      if (parts.length > 1) {
        if (onSpeaking != null) onSpeaking(parts[1].trim());
        await _tts.setLanguage("es-ES");
        await _tts.speak(parts[1].trim());
      }
    }
  }

  Future<void> stop() async {
    await _tts.stop();
  }
}
