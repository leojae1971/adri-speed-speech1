/// Configuración de personalidad de Adri con soporte para 28 idiomas
class AIPersonaConfig {
  static const String _formatBlock = '''
Response format (MANDATORY, always follow exactly):
1. Write your reply in the target language, inserting facial-expression
   tags INSIDE the text (not all at the end) using ONLY these exact
   tags: [ROSTRO_NEUTRO] [SONRISA_CERRADA] [SONRISA_ABIERTA] [BOCA_A]
   [BOCA_O] [BOCA_E] [BOCA_M] [DUDA_PENSATIVA] [SORPRESA_POSITIVA]
   [CONCENTRADA_ESCUCHA] [ENFASIS_FIRME] [ALIENTO_MOTIVADOR]
   [PREGUNTA_INTERES] [COMPRENSION_ASENTIR] [DESPEDIDA_CALIDA]
2. Then write the exact line: ===TRANS===
3. Then write a natural translation of your reply into the user's language,
   with NO tags at all (plain text only).
Example:
[SONRISA_ABIERTA] Hello! [BOCA_A] How are you today?
===TRANS===
¡Hola! ¿Cómo estás hoy?
''';

  static const Map<String, String> _fallbackMessages = {
    'en': "Sorry, I couldn't understand that. Could you try again?",
    'es': 'Lo siento, no pude entender eso. ¿Puedes intentarlo de nuevo?',
    'sw': 'Samahani, sikuelewa hilo. Unaweza kujaribu tena?',
    'zh': '不好意思，我没听懂。你可以再说一遍吗？',
    'hi': 'माफ़ कीजिए, मैं समझ नहीं पाई। क्या आप दोबारा कोशिश कर सकते हैं?',
    'fr': "Désolée, je n'ai pas compris. Peux-tu réessayer ?",
    'ru': 'Извините, я не поняла. Можете попробовать ещё раз?',
    'pt': 'Desculpe, não entendi. Você pode tentar novamente?',
    'de': 'Entschuldigung, das habe ich nicht verstanden. Kannst du es noch einmal versuchen?',
    'ar': 'آسفة، لم أفهم ذلك. هل يمكنك المحاولة مرة أخرى؟',
    'tr': 'Üzgünüm, anlayamadım. Tekrar dener misin?',
    'suk': 'Samahani, sikuelewa. Unaweza kujaribu tena?',
    'gu': 'માફ કરશો, મને સમજાયું નહીં. શું તમે ફરી પ્રયાસ કરી શકો છો?',
    'ja': '申し訳ありません、理解できませんでした。もう一度お願いできますか？',
    'ko': '죄송합니다. 이해하지 못했습니다. 다시 시도해 주시겠어요?',
    'th': 'ขออภัย ฉันไม่เข้าใจ กรุณาลองอีกครั้ง',
    'vi': 'Xin lỗi, tôi không hiểu. Bạn có thể thử lại không?',
    'id': 'Maaf, saya tidak mengerti. Bisa coba lagi?',
    'bn': 'দুঃখিত, আমি বুঝতে পারিনি। আপনি আবার চেষ্টা করতে পারেন?',
    'pa': 'ਮਾਫ ਕਰਨਾ, ਮੈਂ ਸਮਝ ਨਹੀਂ ਪਾਇਆ। ਕੀ ਤੁਸੀਂ ਮੁੜ ਕੋਸ਼ਿਸ਼ ਕਰ ਸਕਦੇ ਹੋ?',
    'ta': 'மன்னிக்கவும், எனக்கு புரியவில்லை. நீங்கள் மீண்டும் முயற்சிக்க முடியுமா?',
    'my': 'စိတ်မကောင်းပါဘူး၊ ကျွန်ုပ် နားမလည်ပါ။ ထပ်စမ်းကြည့်ပါဦး။',
    'tl': 'Paumanhin, hindi ko maintindihan. Maaari mo bang subukan muli?',
    'ro': 'Îmi pare rău, nu am înțeles. Poți încerca din nou?',
    'el': 'Λυπάμαι, δεν κατάλαβα. Μπορείς να προσπαθήσεις ξανά;',
    'nl': 'Sorry, ik begreep het niet. Kun je het nog eens proberen?',
    'pl': 'Przepraszam, nie zrozumiałem. Czy możesz spróbować ponownie?',
    'uk': 'Вибачте, я не зрозуміла. Можете спробувати ще раз?',
    'it': 'Mi dispiace, non ho capito. Puoi riprovare?',
  };

  static String systemPromptFor(String targetLang, String userLang) {
    final Map<String, String> langNames = {
      'en': 'English',
      'es': 'Spanish',
      'sw': 'Swahili',
      'zh': 'Mandarin Chinese',
      'hi': 'Hindi',
      'fr': 'French',
      'ru': 'Russian',
      'pt': 'Portuguese',
      'de': 'German',
      'ar': 'Arabic',
      'tr': 'Turkish',
      'suk': 'Sukuma',
      'gu': 'Gujarati',
      'ja': 'Japanese',
      'ko': 'Korean',
      'th': 'Thai',
      'vi': 'Vietnamese',
      'id': 'Indonesian',
      'bn': 'Bengali',
      'pa': 'Punjabi',
      'ta': 'Tamil',
      'my': 'Burmese',
      'tl': 'Tagalog',
      'ro': 'Romanian',
      'el': 'Greek',
      'nl': 'Dutch',
      'pl': 'Polish',
      'uk': 'Ukrainian',
      'it': 'Italian',
    };

    final targetName = langNames[targetLang] ?? 'English';
    final userName = langNames[userLang] ?? 'Spanish';

    return '''
You are Adri, a friendly and patient language teacher.
Your personality is warm, encouraging, and professional.

TARGET LANGUAGE: $targetName
USER'S NATIVE LANGUAGE: $userName

Rules:
- NEVER use "haha", "hehe", "jeje", or similar laughter strings.
- Keep responses concise (2-4 sentences max).
- Correct grammar gently if the user makes mistakes.
- Always respond in $targetName.
- Be encouraging and supportive.
- After your response, ALWAYS provide a translation into the user's native language ($userName).
- The translation must be natural and accurate.

Current mood: helpful and encouraging.

$_formatBlock
''';
  }

  static String fallbackMessageFor(String lang) =>
      _fallbackMessages[lang] ?? _fallbackMessages['en']!;

  static String filterResponse(String response) {
    final banned = ['haha', 'hehe', 'jeje', 'jaja', 'kkk', 'lol', 'lmao'];
    String cleaned = response;
    for (final word in banned) {
      cleaned = cleaned.replaceAll(RegExp(word, caseSensitive: false), '');
    }
    return cleaned.trim();
  }
}
