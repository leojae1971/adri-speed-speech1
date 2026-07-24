import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../config/ai_persona_config.dart';
import '../utils/logger.dart';

/// Respuesta de Adri con texto y audio generado por el backend.
class AdriResponse {
  final String taggedText;
  final String cleanText;
  final String spanishTranslation;
  final String providerUsed;
  final String? audioBase64;   // audio en base64 desde el backend
  final List<dynamic>? visemes;
  const AdriResponse({
    required this.taggedText,
    required this.cleanText,
    required this.spanishTranslation,
    this.providerUsed = 'unknown',
    this.audioBase64,
    this.visemes,
  });
}

const String _kSpanishFallback =
    'Lo siento, no pude entender eso. ¿Puedes intentarlo de nuevo?';

class AIService {
  final String _baseUrl;
  final Map<String, AdriResponse> _cache = {};

  AIService({String apiKey = '', String? baseUrl})
      : _baseUrl = baseUrl ?? ApiConfig.backendBaseUrl;

  String _cacheKey(String prompt, String lang) =>
      '$lang::${prompt.trim().toLowerCase()}';

  /// Envía el mensaje al backend incluyendo el idioma y la voz deseada.
  Future<AdriResponse> sendMessage(
    String prompt, {
    String? lang,
    String? voiceId,
  }) async {
    final effectiveLang = lang ?? 'en';
    final key = _cacheKey(prompt, effectiveLang);

    final cached = _cache[key];
    if (cached != null) {
      Logger.log('AI Service: respuesta desde caché ("$prompt", $effectiveLang)');
      return cached;
    }

    try {
      final systemPrompt = AIPersonaConfig.systemPromptFor(effectiveLang);

      final response = await http
          .post(
            Uri.parse('$_baseUrl/chat'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'messages': [
                {'role': 'system', 'content': systemPrompt},
                {'role': 'user', 'content': prompt}
              ],
              'lang': effectiveLang,
              'voice_id': voiceId ?? '',
            }),
          )
          .timeout(Duration(seconds: ApiConfig.requestTimeoutSeconds));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final raw = data['text']?.toString() ??
            AIPersonaConfig.fallbackMessageFor(effectiveLang);
        final providerUsed = data['provider_used']?.toString() ?? 'unknown';
        final audioBase64 = data['audio_base64'] as String?;
        final visemes = data['visemes'] as List?;
        final parsed = _parseDualLanguage(raw, effectiveLang, providerUsed,
            audioBase64: audioBase64, visemes: visemes);
        _cache[key] = parsed;
        return parsed;
      } else {
        Logger.error('AI Service error: ${response.statusCode}');
        return _fallbackResponse(effectiveLang);
      }
    } catch (e, st) {
      Logger.error('AI Service exception', error: e, stackTrace: st);
      return _fallbackResponse(effectiveLang);
    }
  }

  AdriResponse _parseDualLanguage(
    String raw,
    String lang,
    String providerUsed, {
    String? audioBase64,
    List? visemes,
  }) {
    const delimiter = '===ES===';
    final idx = raw.indexOf(delimiter);

    String taggedPart;
    String spanishPart;
    if (idx == -1) {
      Logger.error(
          'AI Service: el modelo no devolvió el separador $delimiter (idioma=$lang). '
          'Revisar el prompt o el proveedor LLM en uso.');
      taggedPart = raw;
      spanishPart = '';
    } else {
      taggedPart = raw.substring(0, idx);
      spanishPart = raw.substring(idx + delimiter.length);
    }

    final cleanTagged = AIPersonaConfig.filterResponse(taggedPart);
    final cleanSpanish = AIPersonaConfig.filterResponse(spanishPart);

    return AdriResponse(
      taggedText: cleanTagged,
      cleanText: _stripTags(cleanTagged),
      spanishTranslation: cleanSpanish,
      providerUsed: providerUsed,
      audioBase64: audioBase64,
      visemes: visemes,
    );
  }

  AdriResponse _fallbackResponse(String lang) {
    final msg = AIPersonaConfig.fallbackMessageFor(lang);
    return AdriResponse(
      taggedText: msg,
      cleanText: msg,
      spanishTranslation: _kSpanishFallback,
      providerUsed: 'fallback',
    );
  }

  static final RegExp _tagRe = RegExp(r'\[([A-ZÁÉÍÓÚÑ_]+)\]');
  String _stripTags(String raw) =>
      raw.replaceAll(_tagRe, ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

  void clearCache() => _cache.clear();
}