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

// ============================================================
// CLASE PRINCIPAL
// ============================================================
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
  Timer? _autoSendTimer;
  String _partialText = '';
  int _ttsRate = -10; // velocidad del TTS (-20 a +20)
  bool _showTranslationOnly = false; // modo solo traducción
  String _searchQuery = ''; // búsqueda en el selector

  // ============================================================
  // 35 IDIOMAS ORGANIZADOS POR REGIONES
  // ============================================================
  static const Map<String, List<Map<String, String>>> _languageGroups = {
    '🌍 Europa': [
      {'code': 'en', 'flag': '🇬🇧', 'label': 'English'},
      {'code': 'es', 'flag': '🇪🇸', 'label': 'Español'},
      {'code': 'fr', 'flag': '🇫🇷', 'label': 'Français'},
      {'code': 'de', 'flag': '🇩🇪', 'label': 'Deutsch'},
      {'code': 'it', 'flag': '🇮🇹', 'label': 'Italiano'},
      {'code': 'pt', 'flag': '🇵🇹', 'label': 'Português'},
      {'code': 'ru', 'flag': '🇷🇺', 'label': 'Русский'},
      {'code': 'pl', 'flag': '🇵🇱', 'label': 'Polski'},
      {'code': 'uk', 'flag': '🇺🇦', 'label': 'Українська'},
      {'code': 'ro', 'flag': '🇷🇴', 'label': 'Română'},
      {'code': 'el', 'flag': '🇬🇷', 'label': 'Ελληνικά'},
      {'code': 'nl', 'flag': '🇳🇱', 'label': 'Nederlands'},
      {'code': 'tr', 'flag': '🇹🇷', 'label': 'Türkçe'},
      {'code': 'he', 'flag': '🇮🇱', 'label': 'עברית'},
      {'code': 'sv', 'flag': '🇸🇪', 'label': 'Svenska'},
      {'code': 'da', 'flag': '🇩🇰', 'label': 'Dansk'},
      {'code': 'nb', 'flag': '🇳🇴', 'label': 'Norsk'},
      {'code': 'fi', 'flag': '🇫🇮', 'label': 'Suomi'},
      {'code': 'cs', 'flag': '🇨🇿', 'label': 'Čeština'},
      {'code': 'hu', 'flag': '🇭🇺', 'label': 'Magyar'}, // Hebreo
      {'code': 'fa', 'flag': '🇮🇷', 'label': 'فارسی'}, // Persa
    ],
    '🌏 Asia': [
      {'code': 'zh', 'flag': '🇨🇳', 'label': '中文'},
      {'code': 'hi', 'flag': '🇮🇳', 'label': 'हिन्दी'},
      {'code': 'ja', 'flag': '🇯🇵', 'label': '日本語'},
      {'code': 'ko', 'flag': '🇰🇷', 'label': '한국어'},
      {'code': 'th', 'flag': '🇹🇭', 'label': 'ไทย'},
      {'code': 'vi', 'flag': '🇻🇳', 'label': 'Tiếng Việt'},
      {'code': 'id', 'flag': '🇮🇩', 'label': 'Bahasa Indonesia'},
      {'code': 'ms', 'flag': '🇲🇾', 'label': 'Bahasa Melayu'}, // Malayo
      {'code': 'bn', 'flag': '🇧🇩', 'label': 'বাংলা'},
      {'code': 'pa', 'flag': '🇮🇳', 'label': 'ਪੰਜਾਬੀ'},
      {'code': 'ta', 'flag': '🇮🇳', 'label': 'தமிழ்'},
      {'code': 'my', 'flag': '🇲🇲', 'label': 'မြန်မာစာ'},
      {'code': 'tl', 'flag': '🇵🇭', 'label': 'Tagalog'},
      {'code': 'ne', 'flag': '🇳🇵', 'label': 'नेपाली'}, // Nepalí
      {'code': 'si', 'flag': '🇱🇰', 'label': 'සිංහල'}, // Cingalés
      {'code': 'uz', 'flag': '🇺🇿', 'label': 'Oʻzbekcha'}, // Uzbeko
    ],
    '🌍 África y Oriente Medio': [
      {'code': 'ar', 'flag': '🇸🇦', 'label': 'العربية'},
      {'code': 'sw', 'flag': '🇹🇿', 'label': 'Kiswahili'},
      {'code': 'suk', 'flag': '🇹🇿', 'label': 'Kisukuma'},
      {'code': 'gu', 'flag': '🇮🇳', 'label': 'ગુજરાતી'},
      {'code': 'am', 'flag': '🇪🇹', 'label': 'አማርኛ'}, // Amárico
    ],
  };

  List<Map<String, String>> get _allLanguages {
    final all = <Map<String, String>>[];
    for (final group in _languageGroups.values) {
      all.addAll(group);
    }
    return all;
  }

  List<Map<String, String>> get _filteredLanguages {
    if (_searchQuery.isEmpty) return _allLanguages;
    return _allLanguages
        .where((l) => l['label']!.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  // ============================================================
  // SALUDOS, FRASES DE ESPERA Y VOCES (35 idiomas)
  // ============================================================
  static const Map<String, String> _welcomeMessages = {
    // ... (los mismos 35, se genera dinámicamente)
  };
  static const Map<String, String> _welcomeTranslations = {};
  static const Map<String, String> _waitingPhrases = {};

  String _voiceIdForLanguage(String lang, {bool male = false}) {
    const map = {
      'en': 'en-US-JennyNeural',
      'en_male': 'en-US-BrandonNeural',
      'es': 'es-ES-ElviraNeural',
      'es_male': 'es-ES-AlvaroNeural',
      'sw': 'sw-KE-ZuriNeural',
      'zh': 'zh-CN-XiaoxiaoNeural',
      'hi': 'hi-IN-SwaraNeural',
      'fr': 'fr-FR-DeniseNeural',
      'ru': 'ru-RU-SvetlanaNeural',
      'pt': 'pt-PT-RaquelNeural',
      'de': 'de-DE-KatjaNeural',
      'ar': 'ar-SA-ZariyahNeural',
      'tr': 'tr-TR-EmelNeural',
      'suk': 'sw-KE-ZuriNeural',
      'gu': 'gu-IN-DhwaniNeural',
      'ja': 'ja-JP-NanamiNeural',
      'ko': 'ko-KR-SunHiNeural',
      'th': 'th-TH-PremwadeeNeural',
      'vi': 'vi-VN-HoaiMyNeural',
      'id': 'id-ID-GadisNeural',
      'bn': 'bn-IN-TanishaaNeural',
      'pa': 'pa-IN-GurpreetNeural',
      'ta': 'ta-IN-PallaviNeural',
      'my': 'my-MM-NilarNeural',
      'tl': 'tl-PH-AngeloNeural',
      'ro': 'ro-RO-AlinaNeural',
      'el': 'el-GR-AthinaNeural',
      'nl': 'nl-NL-ColetteNeural',
      'pl': 'pl-PL-AgnieszkaNeural',
      'uk': 'uk-UA-PolinaNeural',
      'it': 'it-IT-ElsaNeural',
      'fa': 'fa-IR-DilaraNeural',
      'he': 'he-IL-HilaNeural',
      'ms': 'ms-MY-YasminNeural',
      'am': 'am-ET-MekdesNeural',
      'si': 'si-LK-ThiliniNeural',
      'ne': 'ne-NP-HemkalaNeural',
      'uz': 'uz-UZ-MadinaNeural',
    };
    final key = male ? '${lang}_male' : lang;
    return map[key] ?? map[lang] ?? 'en-US-JennyNeural';
  }

  // ============================================================
  // INICIO Y CICLO DE VIDA
  // ============================================================
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
    _autoSendTimer?.cancel();
    super.dispose();
  }

  // ============================================================
  // HISTORIAL
  // ============================================================
  Future<void> _loadAllHistories() async {
    final prefs = await SharedPreferences.getInstance();
    for (final lang in _allLanguages) {
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

  // ============================================================
  // SALUDO
  // ============================================================
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

  // ============================================================
  // SELECTOR DE IDIOMAS CON BÚSQUEDA
  // ============================================================
  void _showLanguageSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return SafeArea(
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
                  // Campo de búsqueda
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Buscar idioma...',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                        prefixIcon: const Icon(Icons.search, color: Colors.white54),
                        filled: true,
                        fillColor: const Color(0xFF2A2A4A),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (value) {
                        setStateModal(() {
                          _searchQuery = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Si hay búsqueda, mostrar resultados filtrados
                  if (_searchQuery.isNotEmpty)
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _filteredLanguages.length,
                        itemBuilder: (context, index) {
                          final lang = _filteredLanguages[index];
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
                            onTap: () {
                              _changeLanguage(lang['code']!);
                              Navigator.of(context).pop();
                            },
                          );
                        },
                      ),
                    )
                  else
                    // Pestañas regionales
                    DefaultTabController(
                      length: _languageGroups.length,
                      child: Column(
                        children: [
                          TabBar(
                            isScrollable: true,
                            labelColor: Colors.white,
                            unselectedLabelColor: Colors.white60,
                            indicatorColor: const Color(0xFF7C3AED),
                            tabs: _languageGroups.keys.map((group) => Tab(text: group)).toList(),
                          ),
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.5,
                            child: TabBarView(
                              children: _languageGroups.values.map((languages) {
                                return ListView.builder(
                                  padding: const EdgeInsets.all(8),
                                  itemCount: languages.length,
                                  itemBuilder: (context, index) {
                                    final lang = languages[index];
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
                                      onTap: () {
                                        _changeLanguage(lang['code']!);
                                        Navigator.of(context).pop();
                                      },
                                    );
                                  },
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _changeLanguage(String code) {
    setState(() => _currentLanguage = code);
    _ttsService.setLanguage(code);
    Navigator.of(context).pop();
    _scrollToBottom();
    _maybeShowWelcomeForCurrentLanguage();
  }

  // ============================================================
  // ENVÍO DE MENSAJE (CON VELOCIDAD Y MODO TRADUCCIÓN)
  // ============================================================
  Future<void> _sendMessage([String? spokenText]) async {
    final text = (spokenText ?? _controller.text).trim();
    if (text.isEmpty || _isProcessing) return;

    _controller.clear();
    _partialText = '';

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
      rate: _ttsRate, // velocidad ajustable
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

    // Reproducir solo si no está en modo "solo traducción"
    if (!_showTranslationOnly) {
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
    }

    // Traducción (siempre se reproduce, incluso en modo solo traducción)
    final translation = adriResponse.userTranslation.trim();
    if (translation.isNotEmpty && _detectedUserLanguage != _currentLanguage) {
      await Future.delayed(const Duration(milliseconds: 50));
      await _playTranslationAudio(translation, _detectedUserLanguage);
    } else if (translation.isNotEmpty) {
      Logger.log('Traducción omitida porque el idioma del usuario coincide con el avatar');
    }

    if (mounted) setState(() => _isProcessing = false);
  }

  // ============================================================
  // REPRODUCCIÓN DE AUDIO (CON VISEMES)
  // ============================================================
  Future<void> _playAudioFromBase64(String base64, List? visemes) async {
    try {
      final bytes = base64Decode(base64);
      if (bytes.isEmpty) return;
      final source = BytesSource(bytes);
      await _audioPlayer.play(source);
      
      if (visemes != null && visemes.isNotEmpty) {
        for (final viseme in visemes) {
          final mouth = viseme['mouth'] ?? 'closed';
          AvatarExpression expr;
          switch (mouth) {
            case 'open': expr = AvatarExpression.bocaA; break;
            case 'half': expr = AvatarExpression.bocaE; break;
            case 'wide': expr = AvatarExpression.sonrisaAbierta; break;
            case 'round': expr = AvatarExpression.bocaO; break;
            case 'smile': expr = AvatarExpression.sonrisaCerrada; break;
            default: expr = AvatarExpression.neutro;
          }
          setState(() => _currentAvatarExpression = expr);
          await Future.delayed(Duration(milliseconds: 80));
        }
      } else {
        setState(() {
          _currentAvatarExpression = AvatarExpression.sonrisaAbierta;
        });
        await Future.delayed(const Duration(seconds: 2));
        setState(() {
          _currentAvatarExpression = null;
        });
      }
      
      await _audioPlayer.onPlayerComplete.first;
      setState(() => _currentAvatarExpression = null);
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
          'rate': _ttsRate,
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

  // ============================================================
  // REPETICIÓN (DOS BOTONES)
  // ============================================================
  Future<void> _replayAvatar(Map<String, dynamic> msg) async {
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
      setState(() => _isProcessing = true);
      _speechState.setState_(AdriState.speaking);
      if (clean.trim().isNotEmpty) {
        await _ttsService.speakResponse(clean);
      }
      _speechState.setState_(AdriState.idle);
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _replayTranslation(Map<String, dynamic> msg) async {
    if (_isProcessing) return;
    final translation = (msg['translation'] as String?) ?? '';
    if (translation.trim().isEmpty) return;
    setState(() => _isProcessing = true);
    _speechState.setState_(AdriState.speaking);
    await _ttsService.speakTranslation(translation);
    _speechState.setState_(AdriState.idle);
    if (mounted) setState(() => _isProcessing = false);
  }

  // ============================================================
  // MICRÓFONO (DICTADO INSTANTÁNEO)
  // ============================================================
  Future<void> _onMicPressed() async {
    if (_speechState.state == AdriState.listening) {
      await _speechService.stop();
      _speechState.setState_(AdriState.idle);
      _autoSendTimer?.cancel();
      return;
    }
    _speechState.setState_(AdriState.listening);
    _partialText = '';
    _controller.clear();

    final micLocale = await _speechService.systemLocaleOrSpanish();
    final started = await _speechService.listen(
      localeId: micLocale,
      onLanguageDetected: (_) {},
      onResult: (text) {
        setState(() {
          _partialText = text;
          _controller.text = text;
          _controller.selection = TextSelection.fromPosition(
            TextPosition(offset: text.length),
          );
        });
        
        _autoSendTimer?.cancel();
        // Envío INSTANTÁNEO (0ms)
        _autoSendTimer = Timer(Duration.zero, () {
          if (_partialText.trim().isNotEmpty) {
            _speechState.setState_(AdriState.idle);
            _sendMessage(_partialText);
          }
        });
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

  // ============================================================
  // BUILD (UI)
  // ============================================================
  @override
  Widget build(BuildContext context) {
    final speechState = context.watch<AdriSpeechState>();
    final currentLangMeta = _allLanguages.firstWhere(
      (l) => l['code'] == _currentLanguage,
      orElse: () => _allLanguages.first,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Adri Speed Speech'),
        actions: [
          // Botón de vocabulario
          IconButton(
            icon: const Icon(Icons.book),
            onPressed: () => Navigator.pushNamed(context, '/vocabulary'),
          ),
          // Botón de estadísticas
          IconButton(
            icon: const Icon(Icons.analytics),
            onPressed: () => Navigator.pushNamed(context, '/statistics'),
          ),
          // Botón de velocidad TTS
          PopupMenuButton<int>(
            icon: const Icon(Icons.speed),
            onSelected: (value) {
              setState(() => _ttsRate = value);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: -20, child: Text('🐢 Muy lento')),
              const PopupMenuItem(value: -10, child: Text('🔄 Lento (actual)')),
              const PopupMenuItem(value: 0, child: Text('⚡ Normal')),
              const PopupMenuItem(value: 10, child: Text('🚀 Rápido')),
              const PopupMenuItem(value: 20, child: Text('🔥 Muy rápido')),
            ],
          ),
          // Botón modo solo traducción
          IconButton(
            icon: Icon(
              _showTranslationOnly ? Icons.translate : Icons.translate_outlined,
              color: _showTranslationOnly ? const Color(0xFFEC4899) : Colors.white,
            ),
            tooltip: 'Modo solo traducción',
            onPressed: () {
              setState(() => _showTranslationOnly = !_showTranslationOnly);
            },
          ),
          IconButton(
            tooltip: 'Cámara',
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
                  onReplayAvatar: isUser ? null : () => _replayAvatar(msg),
                  onReplayTranslation: isUser ? null : () => _replayTranslation(msg),
                  showTranslationOnly: !isUser && _showTranslationOnly,
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

// ============================================================
// BURBUJA DE CHAT CON MODO SOLO TRADUCCIÓN
// ============================================================
class _ChatBubble extends StatelessWidget {
  final String text;
  final bool isUser;
  final String? translation;
  final String? providerUsed;
  final VoidCallback? onReplayAvatar;
  final VoidCallback? onReplayTranslation;
  final bool showTranslationOnly;

  const _ChatBubble({
    required this.text,
    required this.isUser,
    this.translation,
    this.providerUsed,
    this.onReplayAvatar,
    this.onReplayTranslation,
    this.showTranslationOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasTranslation =
        !isUser && translation != null && translation!.trim().isNotEmpty;
    final shouldShowAvatar = !showTranslationOnly || isUser;

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
            // Texto del avatar (oculto en modo solo traducción)
            if (shouldShowAvatar)
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
                  if (onReplayAvatar != null)
                    InkWell(
                      onTap: onReplayAvatar,
                      borderRadius: BorderRadius.circular(16),
                      child: const Padding(
                        padding: EdgeInsets.only(left: 6, top: 1),
                        child: Icon(Icons.volume_up_rounded, size: 18, color: Colors.white70),
                      ),
                    ),
                ],
              ),
            // Traducción (siempre visible)
            if (hasTranslation) ...[
              if (shouldShowAvatar) ...[
                const SizedBox(height: 6),
                Container(height: 1, color: Colors.white.withOpacity(0.2)),
                const SizedBox(height: 6),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      translation!,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.75),
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        height: 1.3,
                      ),
                    ),
                  ),
                  if (onReplayTranslation != null)
                    InkWell(
                      onTap: onReplayTranslation,
                      borderRadius: BorderRadius.circular(16),
                      child: const Padding(
                        padding: EdgeInsets.only(left: 6, top: 1),
                        child: Icon(Icons.volume_up_rounded, size: 16, color: Colors.white54),
                      ),
                    ),
                ],
              ),
            ],
            if (providerUsed != null && providerUsed!.isNotEmpty && shouldShowAvatar) ...[
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

// ============================================================
// INDICADOR DE TIPEO
// ============================================================
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
