import 'dart:math';

enum Viseme { closed, half, open, wide, round, smile }

class AvatarLipSyncService {
  static const double _fps = 20.0;
  static const Duration _frameDuration = Duration(milliseconds: 50);

  Viseme calculateViseme(double amplitude) {
    if (amplitude < 0.1) return Viseme.closed;
    if (amplitude < 0.25) return Viseme.half;
    if (amplitude < 0.4) return Viseme.open;
    if (amplitude < 0.55) return Viseme.wide;
    if (amplitude < 0.7) return Viseme.round;
    return Viseme.smile;
  }

  Duration get frameDuration => _frameDuration;

  double jitterAmplitude(double amplitude) {
    final jitter = (Random().nextDouble() - 0.5) * 0.1;
    return (amplitude + jitter).clamp(0.0, 1.0);
  }
}
