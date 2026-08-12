import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../../core/services/camera_translation_service.dart';
import '../../../../core/services/hybrid_tts_service.dart';
import '../../../../core/config/api_config.dart';
import '../../../../core/utils/logger.dart';

class ImageTranslationScreen extends StatefulWidget {
  const ImageTranslationScreen({super.key});

  @override
  State<ImageTranslationScreen> createState() => _ImageTranslationScreenState();
}

class _ImageTranslationScreenState extends State<ImageTranslationScreen> {
  final CameraTranslationService _translationService = CameraTranslationService();
  final HybridTtsService _ttsService = HybridTtsService();
  ImageTranslationResult? _result;
  String? _translatedText;
  bool _isProcessing = false;
  bool _isTranslating = false;
  String _statusMessage = 'Apunta la cámara a un cartel en inglés';

  @override
  void initState() {
    super.initState();
    _ttsService.initialize();
  }

  @override
  void dispose() {
    _translationService.dispose();
    super.dispose();
  }

  Future<void> _takePhotoAndTranslate() async {
    setState(() {
      _isProcessing = true;
      _isTranslating = false;
      _statusMessage = 'Capturando imagen...';
    });

    final result = await _translationService.translateFromCamera(
      targetLanguage: 'es',
      expectedSourceLanguage: 'en',
    );

    if (result == null) {
      setState(() {
        _result = null;
        _translatedText = null;
        _isProcessing = false;
        _statusMessage = '❌ No se detectó texto. Intenta de nuevo.';
      });
      return;
    }

    setState(() {
      _result = result;
      _isProcessing = false;
      _isTranslating = true;
      _statusMessage = '🔄 Traduciendo...';
    });

    // Traducir el texto reconocido
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.backendBaseUrl}/translate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'text': result.originalText,
          'source_lang': 'en',
          'target_lang': 'es',
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _translatedText = data['translation'] ?? 'Error en la traducción';
          _isTranslating = false;
          _statusMessage = '✅ Traducción completada';
        });
        // Reproducir la traducción automáticamente
        await _playTranslationAudio(_translatedText!);
      } else {
        setState(() {
          _translatedText = 'Error al traducir (${response.statusCode})';
          _isTranslating = false;
          _statusMessage = '❌ Error en la traducción';
        });
      }
    } catch (e) {
      setState(() {
        _translatedText = 'Error de conexión: $e';
        _isTranslating = false;
        _statusMessage = '❌ Error de conexión';
      });
      Logger.error('Error traduciendo: $e');
    }
  }

  Future<void> _pickFromGallery() async {
    setState(() {
      _isProcessing = true;
      _isTranslating = false;
      _statusMessage = 'Seleccionando imagen...';
    });

    final result = await _translationService.translateFromGallery(
      targetLanguage: 'es',
      expectedSourceLanguage: 'en',
    );

    if (result == null) {
      setState(() {
        _result = null;
        _translatedText = null;
        _isProcessing = false;
        _statusMessage = '❌ No se detectó texto. Intenta de nuevo.';
      });
      return;
    }

    setState(() {
      _result = result;
      _isProcessing = false;
      _isTranslating = true;
      _statusMessage = '🔄 Traduciendo...';
    });

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.backendBaseUrl}/translate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'text': result.originalText,
          'source_lang': 'en',
          'target_lang': 'es',
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _translatedText = data['translation'] ?? 'Error en la traducción';
          _isTranslating = false;
          _statusMessage = '✅ Traducción completada';
        });
        await _playTranslationAudio(_translatedText!);
      } else {
        setState(() {
          _translatedText = 'Error al traducir (${response.statusCode})';
          _isTranslating = false;
          _statusMessage = '❌ Error en la traducción';
        });
      }
    } catch (e) {
      setState(() {
        _translatedText = 'Error de conexión: $e';
        _isTranslating = false;
        _statusMessage = '❌ Error de conexión';
      });
      Logger.error('Error traduciendo: $e');
    }
  }

  Future<void> _playTranslationAudio(String text) async {
    try {
      // Usar voz en español para la traducción
      final voiceId = 'es-ES-ElviraNeural';
      final response = await http.post(
        Uri.parse('${ApiConfig.backendBaseUrl}/tts'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'text': text,
          'voice_id': voiceId,
          'lang': 'es',
          'rate': -10,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final audioBase64 = data['audio_base64'] as String?;
        if (audioBase64 != null && audioBase64.isNotEmpty) {
          // Usar audioplayers para reproducir
          final bytes = base64Decode(audioBase64);
          final source = BytesSource(bytes);
          await _ttsService._audioPlayer.play(source);
          await _ttsService._audioPlayer.onPlayerComplete.first;
          print('✅ Audio de traducción reproducido');
        }
      } else {
        // Fallback: usar TTS local
        await _ttsService.speakTranslation(text);
      }
    } catch (e) {
      Logger.error('Error reproduciendo traducción de cámara: $e');
      await _ttsService.speakTranslation(text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: const Text(
          '📷 Traductor Visual',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: _result != null
                ? _buildImageWithOverlay()
                : _buildPlaceholder(),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            color: const Color(0xFF16213E),
            child: Row(
              children: [
                if (_isProcessing || _isTranslating)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.orange,
                    ),
                  ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _statusMessage,
                    style: TextStyle(
                      color: _isProcessing || _isTranslating ? Colors.orange : Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Resultado de traducción con botón de audio
          if (_result != null && _translatedText != null)
            Expanded(
              flex: 1,
              child: Container(
                padding: const EdgeInsets.all(16),
                color: const Color(0xFF0F3460),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTextSection(
                        '🇬🇧 Original (Inglés)',
                        _result!.originalText,
                        Colors.blueAccent,
                      ),
                      const SizedBox(height: 12),
                      const Divider(color: Colors.white24),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextSection(
                              '🇪🇸 Traducción (Español)',
                              _translatedText ?? 'Sin traducción',
                              Colors.greenAccent,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.volume_up, color: Colors.white),
                            onPressed: () {
                              if (_translatedText != null && _translatedText!.isNotEmpty) {
                                _playTranslationAudio(_translatedText!);
                              }
                            },
                            tooltip: 'Escuchar traducción',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF16213E),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildActionButton(
                    icon: Icons.camera_alt,
                    label: 'Cámara',
                    color: const Color(0xFF533483),
                    onPressed: _isProcessing ? null : _takePhotoAndTranslate,
                  ),
                  _buildActionButton(
                    icon: Icons.photo_library,
                    label: 'Galería',
                    color: const Color(0xFF0F3460),
                    onPressed: _isProcessing ? null : _pickFromGallery,
                  ),
                  if (_result != null)
                    _buildActionButton(
                      icon: Icons.clear,
                      label: 'Limpiar',
                      color: Colors.redAccent.withOpacity(0.8),
                      onPressed: () {
                        setState(() {
                          _result = null;
                          _translatedText = null;
                          _statusMessage = 'Apunta la cámara a un cartel en inglés';
                        });
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MÉTODOS DE UI
  // ============================================================
  Widget _buildPlaceholder() {
    return Container(
      color: const Color(0xFF0F3460),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.camera_alt_outlined,
              size: 80,
              color: Colors.white.withOpacity(0.2),
            ),
            const SizedBox(height: 16),
            Text(
              'Toca la cámara para escanear',
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Apunta a carteles, menús o señales',
              style: TextStyle(
                color: Colors.white.withOpacity(0.25),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageWithOverlay() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.file(
          _result!.imageFile,
          fit: BoxFit.contain,
        ),
        ..._buildTextOverlays(),
        Positioned(
          top: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.greenAccent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'Traducido',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildTextOverlays() {
    final overlays = <Widget>[];
    for (final block in _result!.textBlocks) {
      for (final line in block.lines) {
        final rect = line.boundingBox;
        if (rect != null) {
          overlays.add(
            Positioned(
              left: rect.left,
              top: rect.top,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: Colors.greenAccent.withOpacity(0.5),
                    width: 1,
                  ),
                ),
                child: Text(
                  line.text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }
      }
    }
    return overlays;
  }

  Widget _buildTextSection(String label, String text, Color accentColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 16,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: accentColor,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: Colors.white, size: 22),
      label: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 14),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        disabledBackgroundColor: color.withOpacity(0.3),
      ),
    );
  }
}
