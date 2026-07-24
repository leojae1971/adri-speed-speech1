import 'package:equatable/equatable.dart';

class VocabularyWord extends Equatable {
  final int id;
  final String word;
  final String definition;
  final String? translation;
  final String? exampleSentence;
  final String? phonetic;
  final String? semanticGroup;
  final double easeFactor;
  final int intervalDays;
  final int repetitions;
  final DateTime nextReview;
  final DateTime? lastReviewed;

  const VocabularyWord({
    required this.id,
    required this.word,
    required this.definition,
    this.translation,
    this.exampleSentence,
    this.phonetic,
    this.semanticGroup,
    required this.easeFactor,
    required this.intervalDays,
    required this.repetitions,
    required this.nextReview,
    this.lastReviewed,
  });

  VocabularyWord copyWith({
    int? id,
    String? word,
    String? definition,
    String? translation,
    String? exampleSentence,
    String? phonetic,
    String? semanticGroup,
    double? easeFactor,
    int? intervalDays,
    int? repetitions,
    DateTime? nextReview,
    DateTime? lastReviewed,
  }) {
    return VocabularyWord(
      id: id ?? this.id,
      word: word ?? this.word,
      definition: definition ?? this.definition,
      translation: translation ?? this.translation,
      exampleSentence: exampleSentence ?? this.exampleSentence,
      phonetic: phonetic ?? this.phonetic,
      semanticGroup: semanticGroup ?? this.semanticGroup,
      easeFactor: easeFactor ?? this.easeFactor,
      intervalDays: intervalDays ?? this.intervalDays,
      repetitions: repetitions ?? this.repetitions,
      nextReview: nextReview ?? this.nextReview,
      lastReviewed: lastReviewed ?? this.lastReviewed,
    );
  }

  @override
  List<Object?> get props => [
        id,
        word,
        definition,
        translation,
        exampleSentence,
        phonetic,
        semanticGroup,
        easeFactor,
        intervalDays,
        repetitions,
        nextReview,
        lastReviewed,
      ];
}
