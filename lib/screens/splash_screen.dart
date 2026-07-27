import 'dart:async';
import 'package:flutter/material.dart';
import '../features/vocabulary/presentation/screens/chat_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  late List<Map<String, String>> _avatars;
  Timer? _timer;

  // Mapa de idioma a nombre para mostrar
  final Map<String, String> _langDisplayName = {
    'en': 'Inglés',
    'es': 'Español',
    'sw': 'Suajili',
    'zh': 'Mandarín',
    'hi': 'Hindi',
    'fr': 'Francés',
    'ru': 'Ruso',
    'pt': 'Portugués',
    'de': 'Alemán',
    'ar': 'Árabe',
  };

  @override
  void initState() {
    super.initState();
    _avatars = [
      {'code': 'en', 'image': 'assets/avatars/adri_en.png'},
      {'code': 'es', 'image': 'assets/avatars/adri_sp.png'},
      {'code': 'sw', 'image': 'assets/avatars/adri_sw.png'},
      {'code': 'zh', 'image': 'assets/avatars/adri_zh.png'},
      {'code': 'hi', 'image': 'assets/avatars/adri_hi.png'},
      {'code': 'fr', 'image': 'assets/avatars/adri_fr.png'},
      {'code': 'ru', 'image': 'assets/avatars/adri_ru.png'},
      {'code': 'pt', 'image': 'assets/avatars/adri_pt.png'},
      {'code': 'de', 'image': 'assets/avatars/adri_de.png'},
      {'code': 'ar', 'image': 'assets/avatars/adri_ar.png'},
    ];

    _timer = Timer.periodic(const Duration(milliseconds: 1500), (timer) {
      if (_pageController.hasClients) {
        final nextPage = (_currentPage + 1) % _avatars.length;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
        setState(() => _currentPage = nextPage);
      }
    });

    Future.delayed(const Duration(seconds: 4), () {
      _timer?.cancel();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ChatScreen()),
        );
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Colors.black,
        child: PageView(
          controller: _pageController,
          onPageChanged: (index) {
            setState(() => _currentPage = index);
          },
          children: _avatars.map((avatar) {
            final langCode = avatar['code']!;
            final displayName = _langDisplayName[langCode] ?? langCode;
            return Container(
              color: Colors.black,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Imagen del avatar
                  Image.asset(
                    avatar['image']!,
                    fit: BoxFit.contain,
                  ),
                  // Texto en la parte inferior
                  Positioned(
                    bottom: 60,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withOpacity(0.7),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Profesora de $displayName',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(
                                  color: Colors.black,
                                  blurRadius: 8,
                                  offset: Offset(2, 2),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'ADRY',
                            style: const TextStyle(
                              color: Color(0xFFEC4899),
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                              shadows: [
                                Shadow(
                                  color: Colors.black,
                                  blurRadius: 8,
                                  offset: Offset(2, 2),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
