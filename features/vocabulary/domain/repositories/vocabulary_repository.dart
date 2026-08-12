import 'package:fpdart/fpdart.dart';
import '../../../../core/errors/failures.dart';
import '../entities/vocabulary_word.dart';

abstract class VocabularyRepository {
  Future<Either<Failure, List<VocabularyWord>>> getWordsToReview(DateTime currentDate);
  Future<Either<Failure, Unit>> saveWord(VocabularyWord word);
  Future<Either<Failure, Unit>> updateSrsData(
    int id,
    double easeFactor,
    int intervalDays,
    int repetitions,
    DateTime nextReview,
  );
  Future<Either<Failure, Unit>> deleteWord(int id);
}
