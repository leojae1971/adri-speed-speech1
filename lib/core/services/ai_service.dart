import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../config/ai_persona_config.dart';
import '../utils/logger.dart';

class AdriResponse {
  final String taggedText;
  final String cleanText;
  final String userTranslation;
  final String providerUsed;
  final String? audioBase64;
  final List? visemes;

  const AdriResponse({
    required this.taggedText,
    required this.cleanText,
    required this.userTranslation,
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

  String _cacheKey(String prompt, String targetLang, String userLang) =>
      '$targetLang::$userLang::${prompt.trim().toLowerCase()}';

  Future<AdriResponse> sendMessage(String prompt,
      {required String targetLang,
      required String userLang,
      String? voiceId,
      int rate = -10}) async {
    final key = _cacheKey(prompt, targetLang, userLang);

    final cached = _cache[key];
    if (cached != null) {
      Logger.log('AI Service: respuesta desde caché ("$prompt", $targetLang, $userLang)');
      return cached;
    }

    try {
      final systemPrompt = AIPersonaConfig.systemPromptFor(targetLang, userLang);

      final response = await http
          .post(
            Uri.parse('$_baseUrl/chat'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'messages': [
                {'role': 'system', 'content': systemPrompt},
                {'role': 'user', 'content': prompt}
              ],
              'lang': targetLang,
              'voice_id': voiceId ?? '',
              'rate': rate,
            }),
          )
          .timeout(Duration(seconds: ApiConfig.requestTimeoutSeconds));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final raw = data['text']?.toString() ??
            AIPersonaConfig.fallbackMessageFor(targetLang);
        final providerUsed = data['provider_used']?.toString() ?? 'unknown';
        final audioBase64 = data['audio_base64'] as String?;
        final visemes = data['visemes'] as List?;
        final parsed = _parseDualLanguage(raw, targetLang, userLang, providerUsed,
            audioBase64: audioBase64, visemes: visemes);
        _cache[key] = parsed;
        return parsed;
      } else {
        Logger.error('AI Service error: ${response.statusCode}');
        return _fallbackResponse(targetLang, userLang);
      }
    } catch (e, st) {
      Logger.error('AI Service exception', error: e, stackTrace: st);
      return _fallbackResponse(targetLang, userLang);
    }
  }

  AdriResponse _parseDualLanguage(
      String raw,
      String targetLang,
      String userLang,
      String providerUsed, {
        String? audioBase64,
        List? visemes,
      }) {
    const delimiter = '===TRANS===';
    final idx = raw.indexOf(delimiter);

    String taggedPart;
    String translationPart;
    if (idx == -1) {
      Logger.error(
          'AI Service: el modelo no devolvió el separador $delimiter (target=$targetLang, user=$userLang). '
          'Revisar el prompt o el proveedor LLM en uso.');
      taggedPart = raw;
      translationPart = '';
    } else {
      taggedPart = raw.substring(0, idx);
      translationPart = raw.substring(idx + delimiter.length);
    }

    final cleanTagged = AIPersonaConfig.filterResponse(taggedPart);
    final cleanTranslation = AIPersonaConfig.filterResponse(translationPart);

    return AdriResponse(
      taggedText: cleanTagged,
      cleanText: _stripTags(cleanTagged),
      userTranslation: cleanTranslation,
      providerUsed: providerUsed,
      audioBase64: audioBase64,
      visemes: visemes,
    );
  }

  AdriResponse _fallbackResponse(String targetLang, String userLang) {
    final msg = AIPersonaConfig.fallbackMessageFor(targetLang);
    return AdriResponse(
      taggedText: msg,
      cleanText: msg,
      userTranslation: AIPersonaConfig.fallbackMessageFor(userLang),
      providerUsed: 'fallback',
    );
  }

  static final RegExp _tagRe = RegExp(r'\[([A-ZÁÉÍÓÚÑ_]+)\]');
  String _stripTags(String raw) =>
      raw.replaceAll(_tagRe, ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

  void clearCache() => _cache.clear();
}
