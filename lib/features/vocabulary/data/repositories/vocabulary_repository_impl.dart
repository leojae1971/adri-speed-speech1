import 'package:drift/drift.dart';
import 'package:fpdart/fpdart.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/services/database.dart';
import '../../../../core/utils/logger.dart';
import '../../domain/entities/vocabulary_word.dart';
import '../../domain/repositories/vocabulary_repository.dart';

class VocabularyRepositoryImpl implements VocabularyRepository {
  final AppDatabase _database;

  VocabularyRepositoryImpl(this._database);

  @override
  Future<Either<Failure, List<VocabularyWord>>> getWordsToReview(DateTime currentDate) async {
    try {
      final driftItems = await _database.getWordsToReview(currentDate);
      final domainItems = driftItems.map((item) => _mapToDomain(item)).toList();
      return right(domainItems);
    } catch (e, st) {
      Logger.error('Error recuperando palabras desde SQLite', error: e, stackTrace: st);
      return left(const DatabaseFailure('No se pudo acceder al almacén de datos de vocabulario.'));
    }
  }

  @override
  Future<Either<Failure, Unit>> saveWord(VocabularyWord word) async {
    try {
      final companion = VocabularyItemsCompanion(
        id: word.id == 0 ? const Value.absent() : Value(word.id),
        word: Value(word.word),
        definition: Value(word.definition),
        translation: Value(word.translation),
        exampleSentence: Value(word.exampleSentence),
        phonetic: Value(word.phonetic),
        semanticGroup: Value(word.semanticGroup),
        easeFactor: Value(word.easeFactor),
        intervalDays: Value(word.intervalDays),
        repetitions: Value(word.repetitions),
        nextReview: Value(word.nextReview),
        lastReviewed: Value(word.lastReviewed),
      );
      await _database.insertOrUpdateVocabulary(companion);
      return right(unit);
    } catch (e, st) {
      Logger.error('Error guardando palabra en la base de datos', error: e, stackTrace: st);
      return left(const DatabaseFailure('Error al guardar el nuevo término de vocabulario.'));
    }
  }

  @override
  Future<Either<Failure, Unit>> updateSrsData(
    int id,
    double easeFactor,
    int intervalDays,
    int repetitions,
    DateTime nextReview,
  ) async {
    try {
      await _database.updateSrsData(id, easeFactor, intervalDays, repetitions, nextReview);
      return right(unit);
    } catch (e, st) {
      Logger.error('Error actualizando métricas SRS en base de datos', error: e, stackTrace: st);
      return left(const DatabaseFailure('Fallo al actualizar el historial de repetición espaciada.'));
    }
  }

  @override
  Future<Either<Failure, Unit>> deleteWord(int id) async {
    try {
      await _database.deleteVocabulary(id);
      return right(unit);
    } catch (e, st) {
      Logger.error('Error eliminando palabra de la base de datos', error: e, stackTrace: st);
      return left(const DatabaseFailure('No se pudo eliminar el elemento de vocabulario.'));
    }
  }

  VocabularyWord _mapToDomain(VocabularyItem item) {
    return VocabularyWord(
      id: item.id,
      word: item.word,
      definition: item.definition,
      translation: item.translation,
      exampleSentence: item.exampleSentence,
      phonetic: item.phonetic,
      semanticGroup: item.semanticGroup,
      easeFactor: item.easeFactor,
      intervalDays: item.intervalDays,
      repetitions: item.repetitions,
      nextReview: item.nextReview,
      lastReviewed: item.lastReviewed,
    );
  }
}
