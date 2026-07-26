import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import '../../../../core/services/ai_service.dart';
import '../../../../core/services/hybrid_tts_service.dart';
import '../../../../core/services/speech_service.dart';
import '../../../../core/services/avatar/adri_avatar_widget.dart';
import '../../../../core/services/avatar/dialogue_script_parser.dart';
import '../../../../main.dart';
import '../../../../core/utils/language_detector.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/config/api_config.dart';
import 'image_translation_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AudioPlayer _audioPlayer = AudioPlayer();

  final Map<String, List<Map<String, dynamic>>> _messagesByLanguage = {};
  List<Map<String, dynamic>> get _messages =>
      _messagesByLanguage.putIfAbsent(_currentLanguage, () => []);

  late AIService _aiService;
  late HybridTtsService _ttsService;
  late SpeechService _speechService;
  late AdriSpeechState _speechState;

  String _currentLanguage = 'en';
  String _detectedUserLanguage = 'es';
  bool _isProcessing = false;
  bool _isWaitingForResponse = false;
  AvatarExpression? _currentAvatarExpression;
  Timer? _waitingTimer;

  static const List<Map<String, String>> _languages = [
    {'code': 'en', 'flag': '🇬🇧', 'label': 'English'},
    {'code': 'es', 'flag': '🇪🇸', 'label': 'Español'},
    {'code': 'sw', 'flag': '🇹🇿', 'label': 'Swahili'},
    {'code': 'zh', 'flag': '🇨🇳', 'label': 'Mandarin'},
    {'code': 'hi', 'flag': '🇮🇳', 'label': 'Hindi'},
    {'code': 'fr', 'flag': '🇫🇷', 'label': 'Français'},
    {'code': 'ru', 'flag': '🇷🇺', 'label': 'Русский'},
    {'code': 'pt', 'flag': '🇵🇹', 'label': 'Português'},
    {'code': 'de', 'flag': '🇩🇪', 'label': 'Deutsch'},
    {'code': 'ar', 'flag': '🇸🇦', 'label': 'العربية'},
  ];

  static const Map<String, String> _welcomeMessages = {
    'en': "[SONRISA_ABIERTA] Hello! [BOCA_A] I'm Adri, your English "
        "teacher. [PREGUNTA_INTERES] Ready to practice a bit?",
    'es': "[SONRISA_ABIERTA] ¡Hola! [BOCA_A] Soy Adri. "
        "[PREGUNTA_INTERES] ¿Charlamos un rato?",
    'sw': "[SONRISA_ABIERTA] Habari! [BOCA_A] Mimi ni Adri, mwalimu "
        "wako wa Kiswahili. [PREGUNTA_INTERES] Tuanze?",
    'zh': "[SONRISA_ABIERTA] 你好！[BOCA_A] 我是Adri，你的中文老师。"
        "[PREGUNTA_INTERES] 我们开始练习吧？",
    'hi': "[SONRISA_ABIERTA] नमस्ते! [BOCA_A] मैं Adri हूं, आपकी "
        "हिंदी शिक्षिका। [PREGUNTA_INTERES] क्या हम शुरू करें?",
    'fr': "[SONRISA_ABIERTA] Bonjour ! [BOCA_A] Je suis Adri, ta prof "
        "de français. [PREGUNTA_INTERES] On commence ?",
    'ru': "[SONRISA_ABIERTA] Привет! [BOCA_A] Я Адри, твоя "
        "учительница русского. [PREGUNTA_INTERES] Начнём?",
    'pt': "[SONRISA_ABIERTA] Olá! [BOCA_A] Eu sou a Adri, sua "
        "professora de português. [PREGUNTA_INTERES] Vamos começar?",
    'de': "[SONRISA_ABIERTA] Hallo! [BOCA_A] Ich bin Adri, deine "
        "Deutschlehrerin. [PREGUNTA_INTERES] Sollen wir anfangen?",
    'ar': "[SONRISA_ABIERTA] مرحبا! [BOCA_A] أنا Adri، معلمتك "
        "للعربية. [PREGUNTA_INTERES] هل نبدأ؟",
  };

  static const Map<String, String> _welcomeTranslations = {
    'en': '¡Hola! Soy Adri, tu profesora de inglés. ¿Listo para practicar un poco?',
    'es': '',
    'sw': '¡Hola! Soy Adri, tu profesora de swahili. ¿Empezamos?',
    'zh': '¡Hola! Soy Adri, tu profesora de mandarín. ¿Empezamos a practicar?',
    'hi': '¡Hola! Soy Adri, tu profesora de hindi. ¿Empezamos?',
    'fr': '¡Hola! Soy Adri, tu profesora de francés. ¿Empezamos?',
    'ru': '¡Hola! Soy Adri, tu profesora de ruso. ¿Empezamos?',
    'pt': '¡Hola! Soy Adri, tu profesora de portugués. ¿Empezamos?',
    'de': '¡Hola! Soy Adri, tu profesora de alemán. ¿Empezamos?',
    'ar': '¡Hola! Soy Adri, tu profesora de árabe. ¿Empezamos?',
  };

  static const Map<String, String> _waitingPhrases = {
    'en': '[DUDA_PENSATIVA] Just a moment...',
    'es': '[DUDA_PENSATIVA] Un momento...',
    'sw': '[DUDA_PENSATIVA] Subiri kidogo...',
    'zh': '[DUDA_PENSATIVA] 请稍等...',
    'hi': '[DUDA_PENSATIVA] एक क्षण रुकिए...',
    'fr': '[DUDA_PENSATIVA] Un instant...',
    'ru': '[DUDA_PENSATIVA] Секунду...',
    'pt': '[DUDA_PENSATIVA] Um momento...',
    'de': '[DUDA_PENSATIVA] Einen Moment...',
    'ar': '[DUDA_PENSATIVA] لحظة من فضلك...',
  };

  String _voiceIdForLanguage(String lang) {
    const map = {
      'en': 'en-US-JennyNeural',
      'es': 'es-ES-ElviraNeural',
      'sw': 'sw-KE-ZuriNeural',
      'zh': 'zh-CN-XiaoxiaoNeural',
      'hi': 'hi-IN-SwaraNeural',
      'fr': 'fr-FR-DeniseNeural',
      'ru': 'ru-RU-SvetlanaNeural',
      'pt': 'pt-PT-RaquelNeural',
      'de': 'de-DE-KatjaNeural',
      'ar': 'ar-SA-ZariyahNeural',
    };
    return map[lang] ?? 'en-US-JennyNeural';
  }

  @override
  void initState() {
    super.initState();
    _aiService = context.read<AIService>();
    _ttsService = context.read<HybridTtsService>();
    _speechService = context.read<SpeechService>();
    _speechState = context.read<AdriSpeechState>();

    _ttsService.initialize();
    _ttsService.setLanguage(_currentLanguage);
    _loadAllHistories().then((_) => _maybeShowWelcomeForCurrentLanguage());
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _audioPlayer.dispose();
    _waitingTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAllHistories() async {
    final prefs = await SharedPreferences.getInstance();
    for (final lang in _languages) {
      final code = lang['code']!;
      final raw = prefs.getString('chat_history_$code');
      if (raw == null || raw.isEmpty) continue;
      try {
        final decoded = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
        _messagesByLanguage[code] = decoded;
      } catch (_) {}
    }
    if (mounted) setState(() {});
    _scrollToBottom();
  }

  Future<void> _persistCurrentHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _messages;
    final toSave = list.length > 200 ? list.sublist(list.length - 200) : list;
    await prefs.setString('chat_history_$_currentLanguage', jsonEncode(toSave));
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _maybeShowWelcomeForCurrentLanguage() async {
    if (_messages.isNotEmpty) return;
    final tagged = _welcomeMessages[_currentLanguage];
    if (tagged == null) return;
    final clean = DialogueScriptParser.stripTags(tagged);
    final translation = _welcomeTranslations[_currentLanguage] ?? '';

    setState(() {
      _messages.add({
        'role': 'adri',
        'text': clean,
        'translation': translation,
        'tagged': tagged,
        'provider': null,
        'audio_base64': null,
        'visemes': null,
      });
    });
    _scrollToBottom();
    unawaited(_persistCurrentHistory());

    _speechState.setState_(AdriState.speaking);
    await _ttsService.precache(clean);
    await Future.delayed(const Duration(milliseconds: 150));
    await _ttsService.speakResponse(clean);
    if (translation.isNotEmpty && _currentLanguage != 'es') {
      await Future.delayed(const Duration(milliseconds: 500));
      await _ttsService.speakTranslation(translation);
    }
    _speechState.setState_(AdriState.idle);
  }

  void _changeLanguage(String code) {
    setState(() => _currentLanguage = code);
    _ttsService.setLanguage(code);
    Navigator.of(context).pop();
    _scrollToBottom();
    _maybeShowWelcomeForCurrentLanguage();
  }

  void _showLanguageSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Elige un idioma',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: _languages.map((lang) {
                      final isSelected = _currentLanguage == lang['code'];
                      return ListTile(
                        leading: Text(lang['flag']!, style: const TextStyle(fontSize: 22)),
                        title: Text(
                          lang['label']!,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check, color: Color(0xFF7C3AED))
                            : null,
                        onTap: () => _changeLanguage(lang['code']!),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _sendMessage([String? spokenText]) async {
    final text = (spokenText ?? _controller.text).trim();
    if (text.isEmpty || _isProcessing) return;

    _controller.clear();

    final detectedLang = LanguageDetector.detect(text);
    if (detectedLang != null) {
      _detectedUserLanguage = detectedLang;
      Logger.log('Idioma del usuario detectado: $_detectedUserLanguage');
    }

    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _isProcessing = true;
      _isWaitingForResponse = true;
    });
    _scrollToBottom();
    unawaited(_persistCurrentHistory());

    _speechState.setState_(AdriState.waiting);

    _waitingTimer = Timer(const Duration(seconds: 4), () {
      final phrase = _waitingPhrases[_currentLanguage];
      if (phrase == null || !mounted) return;
      setState(() => _currentAvatarExpression = AvatarExpression.dudaPensativa);
      _ttsService.speakResponse(DialogueScriptParser.stripTags(phrase));
    });

    final voiceId = _voiceIdForLanguage(_currentLanguage);
    final adriResponse = await _aiService.sendMessage(
      text,
      targetLang: _currentLanguage,
      userLang: _detectedUserLanguage,
      voiceId: voiceId,
      rate: -10,
    );

    _waitingTimer?.cancel();

    setState(() {
      _isWaitingForResponse = false;
      _messages.add({
        'role': 'adri',
        'text': adriResponse.cleanText,
        'translation': adriResponse.userTranslation,
        'tagged': adriResponse.taggedText,
        'provider': adriResponse.providerUsed,
        'audio_base64': adriResponse.audioBase64,
        'visemes': adriResponse.visemes,
      });
    });
    _scrollToBottom();
    unawaited(_persistCurrentHistory());

    if (adriResponse.audioBase64 != null && adriResponse.audioBase64!.isNotEmpty) {
      _speechState.setState_(AdriState.speaking);
      await _playAudioFromBase64(adriResponse.audioBase64!, adriResponse.visemes);
      _speechState.setState_(AdriState.idle);
    } else {
      final cleanText = adriResponse.cleanText.trim();
      if (cleanText.isNotEmpty) {
        await _ttsService.precache(cleanText);
        await Future.delayed(const Duration(milliseconds: 150));
        _speechState.setState_(AdriState.speaking);
        await _ttsService.speakResponse(cleanText);
        _speechState.setState_(AdriState.idle);
      }
    }

    final translation = adriResponse.userTranslation.trim();
    if (translation.isNotEmpty && _detectedUserLanguage != _currentLanguage) {
      await Future.delayed(const Duration(milliseconds: 500));
      await _playTranslationAudio(translation, _detectedUserLanguage);
    } else if (translation.isNotEmpty) {
      Logger.log('Traducción omitida porque el idioma del usuario coincide con el avatar');
    }

    if (mounted) setState(() => _isProcessing = false);
  }

  Future<void> _playAudioFromBase64(String base64, List? visemes) async {
    try {
      final bytes = base64Decode(base64);
      if (bytes.isEmpty) return;
      final source = BytesSource(bytes);
      await _audioPlayer.play(source);
      await _audioPlayer.onPlayerComplete.first;

      if (visemes != null && visemes.isNotEmpty) {
        setState(() {
          _currentAvatarExpression = AvatarExpression.sonrisaAbierta;
        });
        await Future.delayed(const Duration(seconds: 2));
        setState(() {
          _currentAvatarExpression = null;
        });
      } else {
        setState(() {
          _currentAvatarExpression = AvatarExpression.sonrisaAbierta;
        });
        await Future.delayed(const Duration(seconds: 2));
        setState(() {
          _currentAvatarExpression = null;
        });
      }
    } catch (e) {
      Logger.error('Error reproduciendo audio del backend: $e');
    }
  }

  Future<void> _playTranslationAudio(String translationText, String userLang) async {
    if (translationText.trim().isEmpty) return;
    try {
      final voiceId = _voiceIdForLanguage(userLang);
      final response = await http.post(
        Uri.parse('${ApiConfig.backendBaseUrl}/tts'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'text': translationText,
          'voice_id': voiceId,
          'lang': userLang,
          'rate': -10,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final audioBase64 = data['audio_base64'] as String?;
        if (audioBase64 != null && audioBase64.isNotEmpty) {
          final bytes = base64Decode(audioBase64);
          if (bytes.isNotEmpty) {
            final source = BytesSource(bytes);
            await _audioPlayer.play(source);
            await _audioPlayer.onPlayerComplete.first;
            return;
          }
        }
      }
      if (translationText.trim().isNotEmpty) {
        await _ttsService.speakTranslation(translationText);
      }
    } catch (e) {
      Logger.error('Error reproduciendo traducción: $e');
      if (translationText.trim().isNotEmpty) {
        await _ttsService.speakTranslation(translationText);
      }
    }
  }

  Future<void> _replayMessage(Map<String, dynamic> msg) async {
    if (_isProcessing) return;
    final audioBase64 = msg['audio_base64'] as String?;
    if (audioBase64 != null && audioBase64.isNotEmpty) {
      setState(() => _isProcessing = true);
      _speechState.setState_(AdriState.speaking);
      await _playAudioFromBase64(audioBase64, msg['visemes']);
      _speechState.setState_(AdriState.idle);
      if (mounted) setState(() => _isProcessing = false);
    } else {
      final clean = msg['text'] as String;
      final translation = (msg['translation'] as String?) ?? '';
      setState(() => _isProcessing = true);
      _speechState.setState_(AdriState.speaking);
      if (clean.trim().isNotEmpty) {
        await _ttsService.speakResponse(clean);
      }
      if (translation.trim().isNotEmpty) {
        await _ttsService.speakTranslation(translation);
      }
      _speechState.setState_(AdriState.idle);
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _onMicPressed() async {
    if (_speechState.state == AdriState.listening) {
      await _speechService.stop();
      _speechState.setState_(AdriState.idle);
      return;
    }
    _speechState.setState_(AdriState.listening);
    final micLocale = await _speechService.systemLocaleOrSpanish();
    final started = await _speechService.listen(
      localeId: micLocale,
      onLanguageDetected: (_) {},
      onResult: (text) {
        _speechState.setState_(AdriState.idle);
        if (text.trim().isNotEmpty) {
          setState(() => _controller.text = text);
        }
      },
    );
    if (!started) {
      _speechState.setState_(AdriState.idle);
      if (mounted) {
        final detail = _speechService.lastError;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              detail != null
                  ? 'Micrófono: $detail'
                  : 'No se pudo activar el micrófono. Revisa el permiso en Ajustes.',
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _openCamera() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ImageTranslationScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final speechState = context.watch<AdriSpeechState>();
    final currentLangMeta = _languages.firstWhere(
      (l) => l['code'] == _currentLanguage,
      orElse: () => _languages.first,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Adri Speed Speech'),
        actions: [
          IconButton(
            tooltip: 'Traducir con la cámara',
            icon: const Icon(Icons.camera_alt_outlined),
            onPressed: _openCamera,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: AdriAvatarWidget(
              key: ValueKey(_currentLanguage),
              isSpeaking: speechState.state == AdriState.speaking,
              amplitude: speechState.amplitude,
              language: _currentLanguage,
              onLanguageTap: _showLanguageSelector,
              expressionOverride: _currentAvatarExpression,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              switch (speechState.state) {
                AdriState.listening => 'Escuchando…',
                AdriState.waiting => 'Esperando…',
                AdriState.speaking => 'Hablando…',
                AdriState.idle => '${currentLangMeta['flag']} ${currentLangMeta['label']} Voice',
              },
              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
            ),
          ),
          const SizedBox(height: 8),
          Container(height: 1, color: const Color(0xFF7C3AED).withOpacity(0.3)),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isWaitingForResponse ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length) {
                  return const _TypingIndicator();
                }
                final msg = _messages[index];
                final isUser = msg['role'] == 'user';
                return _ChatBubble(
                  text: msg['text'],
                  isUser: isUser,
                  translation: msg['translation'],
                  providerUsed: msg['provider'],
                  onReplay: isUser ? null : () => _replayMessage(msg),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      speechState.state == AdriState.listening
                          ? Icons.mic
                          : Icons.mic_none,
                      color: speechState.state == AdriState.listening
                          ? const Color(0xFFEC4899)
                          : Colors.white70,
                    ),
                    onPressed: _isProcessing ? null : _onMicPressed,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Type or speak...',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                        filled: true,
                        fillColor: const Color(0xFF1A1A2E),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: const Color(0xFFEC4899),
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white, size: 20),
                      onPressed: _isProcessing ? null : () => _sendMessage(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final String text;
  final bool isUser;
  final String? translation;
  final String? providerUsed;
  final VoidCallback? onReplay;

  const _ChatBubble({
    required this.text,
    required this.isUser,
    this.translation,
    this.providerUsed,
    this.onReplay,
  });

  @override
  Widget build(BuildContext context) {
    final hasTranslation =
        !isUser && translation != null && translation!.trim().isNotEmpty;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF1E3A5F) : const Color(0xFF7C3AED),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    text,
                    style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.4),
                  ),
                ),
                if (onReplay != null)
                  InkWell(
                    onTap: onReplay,
                    borderRadius: BorderRadius.circular(16),
                    child: const Padding(
                      padding: EdgeInsets.only(left: 6, top: 1),
                      child: Icon(Icons.volume_up_rounded, size: 18, color: Colors.white70),
                    ),
                  ),
              ],
            ),
            if (hasTranslation) ...[
              const SizedBox(height: 6),
              Container(height: 1, color: Colors.white.withOpacity(0.2)),
              const SizedBox(height: 6),
              Text(
                translation!,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.75),
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  height: 1.3,
                ),
              ),
            ],
            if (providerUsed != null && providerUsed!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'vía $providerUsed',
                style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 10),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF7C3AED),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
          ),
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                final t = (_controller.value - i * 0.2) % 1.0;
                final opacity = (t < 0.5) ? (0.3 + t) : (1.3 - t);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Opacity(
                    opacity: opacity.clamp(0.3, 1.0),
                    child: const CircleAvatar(
                      radius: 3.5,
                      backgroundColor: Colors.white,
                    ),
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }
}
