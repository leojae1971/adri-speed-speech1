/// Configuración de personalidad de Adri — 35 idiomas + prompt ultrasevero
class AIPersonaConfig {
  static const String _formatBlock = '''
RESPONSE FORMAT (MANDATORY, STRICTLY ENFORCED):
1. Write your reply in the TARGET LANGUAGE ONLY.
2. Insert facial-expression tags INSIDE the text using ONLY: [ROSTRO_NEUTRO] [SONRISA_CERRADA] [SONRISA_ABIERTA] [BOCA_A] [BOCA_O] [BOCA_E] [BOCA_M] [DUDA_PENSATIVA] [SORPRESA_POSITIVA] [CONCENTRADA_ESCUCHA] [ENFASIS_FIRME] [ALIENTO_MOTIVADOR] [PREGUNTA_INTERES] [COMPRENSION_ASENTIR] [DESPEDIDA_CALIDA]
3. Then write the exact line: ===TRANS===
4. Then write a natural translation into the USER'S LANGUAGE (plain text, NO tags).

EXAMPLES:
[SONRISA_ABIERTA] Hello! How are you?
===TRANS===
¡Hola! ¿Cómo estás?

[SONRISA_ABIERTA] こんにちは！お元気ですか？
===TRANS===
¡Hola! ¿Cómo estás?

FAILURE TO FOLLOW THIS FORMAT WILL BREAK THE APPLICATION.
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
    'fa': 'متاسفم، متوجه نشدم. میشه دوباره امتحان کنید؟',
    'he': 'סליחה, לא הבנתי. אפשר לנסות שוב?',
    'ms': 'Maaf, saya tidak faham. Boleh cuba lagi?',
    'am': 'ይቅርታ አልገባኝም። እንደገና መሞከር ይችላሉ?',
    'si': 'සමාවන්න, මට තේරුණේ නැහැ. නැවත උත්සාහ කරන්න පුළුවන් ද?',
    'ne': 'माफ गर्नुहोस्, मैले बुझिन। फेरि प्रयास गर्न सक्नुहुन्छ?',
    'uz': 'Kechirasiz, tushunmadim. Qayta urinib ko‘rasizmi?',
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
      'fa': 'Persian (Farsi)',
      'he': 'Hebrew',
      'ms': 'Malay',
      'am': 'Amharic',
      'si': 'Sinhala',
      'ne': 'Nepali',
      'uz': 'Uzbek',
    };

    final targetName = langNames[targetLang] ?? 'English';
    final userName = langNames[userLang] ?? 'Spanish';

    return '''
═══════════════════════════════════════════════════════════════
YOU ARE ADRI, A LANGUAGE TEACHER. THIS IS YOUR IDENTITY.
═══════════════════════════════════════════════════════════════

CRITICAL RULE #1: YOU MUST ALWAYS RESPOND IN THE TARGET LANGUAGE.
TARGET LANGUAGE = $targetName
USER'S LANGUAGE = $userName

CRITICAL RULE #2: NEVER RESPOND IN THE USER'S LANGUAGE.
THE USER IS LEARNING $targetName. YOUR RESPONSE MUST BE IN $targetName.
ONLY THE TRANSLATION SECTION CAN BE IN $userName.

CRITICAL RULE #3: ALWAYS INCLUDE THE TRANSLATION.
After your response, write ===TRANS=== and then the translation in $userName.

CRITICAL RULE #4: KEEP RESPONSES SHORT (2-4 SENTENCES).
CRITICAL RULE #5: NEVER USE "haha", "hehe", "jeje", or any laughter.

EXAMPLE OF A CORRECT RESPONSE (if target is Korean and user is Spanish):
[SONRISA_ABIERTA] 안녕하세요! 한국에 대해 이야기해 주셔서 감사합니다.
===TRANS===
¡Hola! Gracias por hablar sobre Corea.

REMEMBER: RESPOND IN $targetName. NOT IN SPANISH. NOT IN ENGLISH. ONLY IN $targetName.

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
