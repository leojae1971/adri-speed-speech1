import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/vocabulary_providers.dart';
import '../../domain/entities/vocabulary_word.dart';

class VocabularyReviewScreen extends StatefulWidget {
  const VocabularyReviewScreen({super.key});

  @override
  State<VocabularyReviewScreen> createState() => _VocabularyReviewScreenState();
}

class _VocabularyReviewScreenState extends State<VocabularyReviewScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vocabulario para revisar'),
        backgroundColor: const Color(0xFF16213E),
      ),
      body: Consumer<VocabularyNotifier>(
        builder: (context, notifier, child) {
          if (notifier.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (notifier.hasError) {
            return Center(
              child: Text('Error: ${notifier.error}'),
            );
          }
          final words = notifier.valueOrNull ?? [];
          if (words.isEmpty) {
            return const Center(
              child: Text(
                '¡No hay palabras para revisar hoy!\nSigue practicando y volverán.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: words.length,
            itemBuilder: (context, index) {
              final word = words[index];
              return Card(
                color: const Color(0xFF1A1A2E),
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        word.word,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        word.definition,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 14,
                        ),
                      ),
                      if (word.exampleSentence != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          '📝 ${word.exampleSentence}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildReviewButton(
                            context,
                            word,
                            quality: 1,
                            label: '😅 Difícil',
                            color: Colors.red,
                          ),
                          _buildReviewButton(
                            context,
                            word,
                            quality: 3,
                            label: '🤔 Regular',
                            color: Colors.orange,
                          ),
                          _buildReviewButton(
                            context,
                            word,
                            quality: 5,
                            label: '✅ Fácil',
                            color: Colors.green,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildReviewButton(
    BuildContext context,
    VocabularyWord word, {
    required int quality,
    required String label,
    required Color color,
  }) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.2),
        foregroundColor: color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      onPressed: () {
        Provider.of<VocabularyNotifier>(context, listen: false)
            .reviewWord(word.id, quality);
      },
      child: Text(label),
    );
  }
}
