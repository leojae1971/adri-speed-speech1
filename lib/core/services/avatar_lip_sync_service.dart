import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';

/// ============================================================
/// AVATAR LIP-SYNC SERVICE - VERSIÓN 2.0
/// ============================================================
/// 
/// CARACTERÍSTICAS:
/// - Visemas estimados desde texto para sincronización labial
/// - Timer a 20fps (50ms) para animación suave
/// - Pestañeo natural integrado (delay aleatorio 2-5s)
/// - Respiración sutil con AnimationController
/// - SOLO activo cuando isSpeaking = true (labios se mueven)
/// ============================================================

class VisemeFrame {
  final int startMs;
  final int endMs;
  final String mouth; // 'closed', 'half', 'open', 'wide', 'round', 'smile'

  VisemeFrame({
    required this.startMs,
    required this.endMs,
    required this.mouth,
  });
}

class AvatarLipSyncService extends ChangeNotifier {
  // ─── ESTADO ───
  bool _isSpeaking = false;
  String _currentMouth = 'closed';
  List<VisemeFrame> _visemes = [];
  int _currentIndex = 0;
  Timer? _animationTimer;
  Stopwatch? _stopwatch;

  // ─── PESTAÑEO ───
  bool _isBlinking = false;
  Timer? _blinkTimer;
  final Random _random = Random();

  // ─── GETTERS ───
  bool get isSpeaking => _isSpeaking;
  String get currentMouth => _currentMouth;
  bool get isBlinking => _isBlinking;

  // ============================================================
  // INICIAR HABLA (activa lip-sync)
  // ============================================================
  void startSpeaking({String? text}) {
    if (_isSpeaking) return;

    _isSpeaking = true;
    _currentMouth = 'closed';
    _currentIndex = 0;

    // Generar visemas desde texto si se proporciona
    if (text != null && text.isNotEmpty) {
      _visemes = _generateVisemesFromText(text);
    } else {
      _visemes = _generateDefaultVisemes();
    }

    // Iniciar timer de animación (20fps = 50ms)
    _stopwatch = Stopwatch()..start();
    _animationTimer = Timer.periodic(
      const Duration(milliseconds: 50),
      _updateFrame,
    );

    notifyListeners();
  }

  // ============================================================
  // DETENER HABLA (desactiva lip-sync - labios se detienen)
  // ============================================================
  void stopSpeaking() {
    _isSpeaking = false;
    _animationTimer?.cancel();
    _animationTimer = null;
    _stopwatch?.stop();
    _stopwatch = null;
    _currentMouth = 'closed';
    _currentIndex = 0;

    notifyListeners();
  }

  // ============================================================
  // ACTUALIZAR FRAME (cada 50ms)
  // ============================================================
  void _updateFrame(Timer timer) {
    if (!_isSpeaking || _visemes.isEmpty || _stopwatch == null) {
      _currentMouth = 'closed';
      notifyListeners();
      return;
    }

    final elapsedMs = _stopwatch!.elapsedMilliseconds;

    // Buscar visema actual basado en tiempo transcurrido
    VisemeFrame? activeViseme;
    for (final viseme in _visemes) {
      if (elapsedMs >= viseme.startMs && elapsedMs < viseme.endMs) {
        activeViseme = viseme;
        break;
      }
    }

    // Si terminamos todos los visemas, repetir ciclo o cerrar
    if (activeViseme == null) {
      if (elapsedMs > _visemes.last.endMs) {
        // Reiniciar ciclo para mantener animación mientras sigue hablando
        _stopwatch!.reset();
        _stopwatch!.start();
        activeViseme = _visemes.first;
      }
    }

    final newMouth = activeViseme?.mouth ?? 'closed';

    if (newMouth != _currentMouth) {
      _currentMouth = newMouth;
      notifyListeners();
    }
  }

  // ============================================================
  // GENERAR VISEMAS DESDE TEXTO
  // ============================================================
  List<VisemeFrame> _generateVisemesFromText(String text) {
    final visemes = <VisemeFrame>[];
    final cleanText = text.toLowerCase().trim();

    if (cleanText.isEmpty) return _generateDefaultVisemes();

    int currentMs = 0;
    final baseDuration = 80; // ms por carácter aproximado

    for (int i = 0; i < cleanText.length; i++) {
      final char = cleanText[i];
      final mouth = _charToMouth(char);
      final duration = _charToDuration(char);

      visemes.add(VisemeFrame(
        startMs: currentMs,
        endMs: currentMs + duration,
        mouth: mouth,
      ));

      currentMs += duration;
    }

    return visemes;
  }

  // ============================================================
  // MAPEO CARÁCTER → BOCA (Visemas)
  // ============================================================
  String _charToMouth(String char) {
    // Vocales abiertas
    if ('aeiouáéíóú'.contains(char)) {
      if ('aeáé'.contains(char)) return 'open';
      if ('oóuú'.contains(char)) return 'round';
      return 'wide'; // ií
    }

    // Consonantes labiales
    if ('bmp'.contains(char)) return 'closed';
    if ('fv'.contains(char)) return 'half';

    // Consonantes linguales
    if ('tdnlrsz'.contains(char)) return 'half';
    if ('jchg'.contains(char)) return 'open';
    if ('kw'.contains(char)) return 'round';

    // Espacios y puntuación
    if (' .,;:!?'.contains(char)) return 'smile';

    return 'closed';
  }

  int _charToDuration(String char) {
    if (' .,;:!?'.contains(char)) return 150; // Pausas más largas
    if ('aeiouáéíóú'.contains(char)) return 100; // Vocales
    if ('bmpfv'.contains(char)) return 80; // Labiales
    return 70; // Default
  }

  // ============================================================
  // VISEMAS POR DEFECTO (cuando no hay texto)
  // ============================================================
  List<VisemeFrame> _generateDefaultVisemes() {
    return [
      VisemeFrame(startMs: 0, endMs: 200, mouth: 'closed'),
      VisemeFrame(startMs: 200, endMs: 400, mouth: 'half'),
      VisemeFrame(startMs: 400, endMs: 600, mouth: 'open'),
      VisemeFrame(startMs: 600, endMs: 800, mouth: 'wide'),
      VisemeFrame(startMs: 800, endMs: 1000, mouth: 'round'),
      VisemeFrame(startMs: 1000, endMs: 1200, mouth: 'smile'),
      VisemeFrame(startMs: 1200, endMs: 1400, mouth: 'closed'),
    ];
  }

  // ============================================================
  // PESTAÑEO NATURAL (independiente del lip-sync)
  // ============================================================
  void startNaturalBlinking() {
    _scheduleNextBlink();
  }

  void _scheduleNextBlink() {
    final delay = Duration(milliseconds: 2000 + _random.nextInt(4000));
    _blinkTimer?.cancel();
    _blinkTimer = Timer(delay, () {
      _performBlink();
    });
  }

  void _performBlink() {
    _isBlinking = true;
    notifyListeners();

    Future.delayed(const Duration(milliseconds: 150), () {
      _isBlinking = false;
      notifyListeners();
      _scheduleNextBlink();
    });
  }

  // ============================================================
  // DISPOSE
  // ============================================================
  @override
  void dispose() {
    _animationTimer?.cancel();
    _blinkTimer?.cancel();
    super.dispose();
  }
}
