import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/database.dart';
import '../../data/repositories/vocabulary_repository_impl.dart';
import '../../domain/entities/vocabulary_word.dart';
import '../../domain/repositories/vocabulary_repository.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

final vocabularyRepositoryProvider = Provider<VocabularyRepository>((ref) {
  final database = ref.watch(appDatabaseProvider);
  return VocabularyRepositoryImpl(database);
});

final vocabularyNotifierProvider =
    StateNotifierProvider<VocabularyNotifier, AsyncValue<List<VocabularyWord>>>(
        (ref) {
  return VocabularyNotifier(ref);
});

class VocabularyNotifier extends StateNotifier<AsyncValue<List<VocabularyWord>>> {
  final Ref ref;

  VocabularyNotifier(this.ref) : super(const AsyncValue.loading()) {
    loadWords();
  }

  Future<void> loadWords() async {
    state = const AsyncValue.loading();
    try {
      final repository = ref.read(vocabularyRepositoryProvider);
      final result = await repository.getWordsToReview(DateTime.now());
      state = result.fold(
        (failure) => AsyncValue.error(failure.message, StackTrace.current),
        (words) => AsyncValue.data(words),
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> reviewWord(int id, int quality) async {
    if (quality < 0 || quality > 5) return;

    final currentWords = state.valueOrNull ?? [];
    final wordToReview = currentWords.firstWhere((w) => w.id == id);

    double newEaseFactor = wordToReview.easeFactor;
    int newRepetitions = wordToReview.repetitions;
    int newIntervalDays = wordToReview.intervalDays;

    if (quality >= 3) {
      if (newRepetitions == 0) {
        newIntervalDays = 1;
      } else if (newRepetitions == 1) {
        newIntervalDays = 6;
      } else {
        newIntervalDays = (newIntervalDays * newEaseFactor).round();
      }
      newRepetitions++;
    } else {
      newRepetitions = 0;
      newIntervalDays = 1;
    }

    newEaseFactor = newEaseFactor + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02));
    if (newEaseFactor < 1.3) newEaseFactor = 1.3;

    final nextReviewDate = DateTime.now().add(Duration(days: newIntervalDays));

    final repository = ref.read(vocabularyRepositoryProvider);
    final result = await repository.updateSrsData(
      id,
      newEaseFactor,
      newIntervalDays,
      newRepetitions,
      nextReviewDate,
    );

    result.fold(
      (failure) => state = AsyncValue.error(failure.message, StackTrace.current),
      (_) => loadWords(),
    );
  }

  Future<void> addWord(VocabularyWord word) async {
    final repository = ref.read(vocabularyRepositoryProvider);
    final result = await repository.saveWord(word);
    result.fold(
      (failure) => state = AsyncValue.error(failure.message, StackTrace.current),
      (_) => loadWords(),
    );
  }
}
