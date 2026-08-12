import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/services/avatar/adri_avatar_widget.dart';
import 'core/services/hybrid_tts_service.dart';
import 'core/services/ai_service.dart';
import 'core/services/speech_service.dart';
import 'core/services/backend_warmup_service.dart';
import 'core/services/notification_service.dart';
import 'core/screens/splash_screen.dart';
import 'features/vocabulary/presentation/screens/chat_screen.dart';
import 'features/vocabulary/presentation/screens/vocabulary_review_screen.dart';
import 'features/statistics/presentation/screens/statistics_screen.dart';
import 'features/vocabulary/presentation/screens/chat_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await NotificationService.initialize();
    await NotificationService.scheduleDailyReminder();
  } catch (e) {
    print('Error en notificaciones: $e');
  }
  BackendWarmupService().warmup();
  runApp(const AdriApp());
}

class AdriApp extends StatelessWidget {
  const AdriApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AdriSpeechState()),
        Provider(create: (_) => AIService()),
        Provider(create: (_) => HybridTtsService()),
        Provider(create: (_) => SpeechService()),
      ],
      child: MaterialApp(
        title: 'Adry Speed Speech',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: const Color(0xFF0F0F23),
          primaryColor: const Color(0xFF7C3AED),
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF7C3AED),
            secondary: Color(0xFFEC4899),
            surface: Color(0xFF1A1A2E),
          ),
        ),
        home: SplashScreen(),
        routes: {
          '/vocabulary': (context) => VocabularyReviewScreen(),
          '/statistics': (context) => StatisticsScreen(),
        },
      ),
    );
  }
}

class AdriSpeechState extends ChangeNotifier {
  AdriState _state = AdriState.idle;
  double _amplitude = 0.0;

  AdriState get state => _state;
  double get amplitude => _amplitude;

  void setState_(AdriState s) {
    _state = s;
    notifyListeners();
  }

  void setAmplitude(double a) {
    _amplitude = a.clamp(0.0, 1.0);
    notifyListeners();
  }
}

enum AdriState { idle, waiting, listening, speaking }
