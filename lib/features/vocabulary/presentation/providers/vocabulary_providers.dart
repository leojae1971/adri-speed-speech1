{\rtf1\ansi\ansicpg1252\cocoartf2870
\cocoatextscaling0\cocoaplatform0{\fonttbl\f0\fswiss\fcharset0 Helvetica;}
{\colortbl;\red255\green255\blue255;}
{\*\expandedcolortbl;;}
\paperw11900\paperh16840\margl1440\margr1440\vieww11520\viewh8400\viewkind0
\pard\tx720\tx1440\tx2160\tx2880\tx3600\tx4320\tx5040\tx5760\tx6480\tx7200\tx7920\tx8640\pardirnatural\partightenfactor0

\f0\fs24 \cf0 import 'package:riverpod_annotation/riverpod_annotation.dart';\
import '../../../../core/services/database.dart';\
import '../../data/repositories/vocabulary_repository_impl.dart';\
import '../../domain/entities/vocabulary_word.dart';\
import '../../domain/repositories/vocabulary_repository.dart';\
\
part 'vocabulary_providers.g.dart';\
\
@riverpod\
AppDatabase appDatabase(AppDatabaseRef ref) \{\
  final db = AppDatabase();\
  ref.onDispose(() => db.close());\
  return db;\
\}\
\
@riverpod\
VocabularyRepository vocabularyRepository(VocabularyRepositoryRef ref) \{\
  final database = ref.watch(appDatabaseProvider);\
  return VocabularyRepositoryImpl(database);\
\}\
\
@riverpod\
class VocabularyNotifier extends _$VocabularyNotifier \{\
  @override\
  FutureOr<List<VocabularyWord>> build() async \{\
    final repository = ref.watch(vocabularyRepositoryProvider);\
    final result = await repository.getWordsToReview(DateTime.now());\
    \
    return result.fold(\
      (failure) => throw Exception(failure.message),\
      (words) => words,\
    );\
  \}\
\
  Future<void> reviewWord(int id, int quality) async \{\
    if (quality < 0 || quality > 5) return;\
\
    state = const AsyncValue.loading();\
    final repository = ref.read(vocabularyRepositoryProvider);\
\
    final currentWords = state.valueOrNull ?? [];\
    final wordToReview = currentWords.firstWhere((w) => w.id == id);\
\
    double newEaseFactor = wordToReview.easeFactor;\
    int newRepetitions = wordToReview.repetitions;\
    int newIntervalDays = wordToReview.intervalDays;\
\
    if (quality >= 3) \{\
      if (newRepetitions == 0) \{\
        newIntervalDays = 1;\
      \} else if (newRepetitions == 1) \{\
        newIntervalDays = 6;\
      \} else \{\
        newIntervalDays = (newIntervalDays * newEaseFactor).round();\
      \}\
      newRepetitions++;\
    \} else \{\
      newRepetitions = 0;\
      newIntervalDays = 1;\
    \}\
\
    newEaseFactor = newEaseFactor + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02));\
    if (newEaseFactor < 1.3) \{\
      newEaseFactor = 1.3;\
    \}\
\
    final nextReviewDate = DateTime.now().add(Duration(days: newIntervalDays));\
\
    final result = await repository.updateSrsData(\
      id,\
      newEaseFactor,\
      newIntervalDays,\
      newRepetitions,\
      nextReviewDate,\
    );\
\
    result.fold(\
      (failure) \{\
        state = AsyncValue.error(failure.message, StackTrace.current);\
      \},\
      (_) \{\
        ref.invalidateSelf();\
      \},\
    );\
  \}\
\
  Future<void> addWord(VocabularyWord word) async \{\
    state = const AsyncValue.loading();\
    final repository = ref.read(vocabularyRepositoryProvider);\
    final result = await repository.saveWord(word);\
\
    result.fold(\
      (failure) \{\
        state = AsyncValue.error(failure.message, StackTrace.current);\
      \},\
      (_) \{\
        ref.invalidateSelf();\
      \},\
    );\
  \}\
\}}