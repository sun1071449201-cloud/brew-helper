import 'package:drift/drift.dart';

class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {key};
}

/// 种子版本指纹：version + checksum 相同则跳过导入（幂等）。
class SeedMeta extends Table {
  TextColumn get datasetName => text()();
  TextColumn get version => text()();
  TextColumn get checksum => text()();
  DateTimeColumn get importedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {datasetName};
}
