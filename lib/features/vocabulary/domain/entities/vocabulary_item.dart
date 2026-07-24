import 'package:equatable/equatable.dart';

class VocabularyItem extends Equatable {
  final int? id;
  final String word;
  final List<String> semanticCluster;
  final int srsNextReviewHours;
  final String contextSentence;
  final String? emotionalTag;

  const VocabularyItem({
    this.id,
    required this.word,
    required this.semanticCluster,
    this.srsNextReviewHours = 24,
    required this.contextSentence,
    this.emotionalTag,
  });

  @override
  List<Object?> get props => [id, word, semanticCluster, srsNextReviewHours, contextSentence, emotionalTag];
}
