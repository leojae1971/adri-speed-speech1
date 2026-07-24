import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:io';

part 'database.g.dart';

class VocabularyItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get word => text().withLength(min: 1, max: 120)();
  TextColumn get definition => text()();
  TextColumn get translation => text().nullable()();
  TextColumn get exampleSentence => text().nullable()();
  TextColumn get phonetic => text().nullable()();
  TextColumn get semanticGroup => text().nullable()();

  RealColumn get easeFactor => real().withDefault(const Constant(2.5))();
  IntColumn get intervalDays => integer().withDefault(const Constant(0))();
  IntColumn get repetitions => integer().withDefault(const Constant(0))();

  DateTimeColumn get nextReview => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastReviewed => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class SessionSnapshots extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get sessionId => text().withLength(min: 1, max: 100)();
  TextColumn get metadataJson => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DriftDatabase(tables: [VocabularyItems, SessionSnapshots])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  Future<List<VocabularyItem>> getWordsToReview(DateTime currentDate) {
    return (select(vocabularyItems)
          ..where((tbl) => tbl.nextReview.isSmallerOrEqualValue(currentDate)))
        .get();
  }

  Future<int> insertOrUpdateVocabulary(VocabularyItemsCompanion item) {
    return into(vocabularyItems).insertOnConflictUpdate(item);
  }

  Future<void> updateSrsData(
    int id,
    double newEaseFactor,
    int newInterval,
    int newRepetitions,
    DateTime nextReviewDate,
  ) {
    return (update(vocabularyItems)..where((tbl) => tbl.id.equals(id))).write(
      VocabularyItemsCompanion(
        easeFactor: Value(newEaseFactor),
        intervalDays: Value(newInterval),
        repetitions: Value(newRepetitions),
        nextReview: Value(nextReviewDate),
        lastReviewed: Value(DateTime.now()),
      ),
    );
  }

  Future<int> deleteVocabulary(int id) {
    return (delete(vocabularyItems)..where((tbl) => tbl.id.equals(id))).go();
  }

  Future<int> saveSessionSnapshot(SessionSnapshotsCompanion snapshot) {
    return into(sessionSnapshots).insertOnConflictUpdate(snapshot);
  }

  Future<SessionSnapshot?> getLastSessionSnapshot(String sessionId) {
    return (select(sessionSnapshots)
          ..where((tbl) => tbl.sessionId.equals(sessionId))
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.createdAt, mode: OrderingMode.desc)])
          ..limit(1))
        .getSingleOrNull();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'lingua_core.sqlite'));
    return NativeDatabase(file);
  });
}
