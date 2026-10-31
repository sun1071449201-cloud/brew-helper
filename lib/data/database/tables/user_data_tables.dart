import 'package:drift/drift.dart';

/// 阅读进度：每本书每章的最后滚动位置（用户数据，不随种子导入清库）。
class ReadingProgress extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get bookId => text()();
  TextColumn get chapterKey => text()();
  RealColumn get offsetPx => real().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [{bookId, chapterKey}];
}

/// 书签：任意分段 + 备注（用户数据）。
class Bookmarks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get bookId => text()();
  TextColumn get chapterKey => text()();
  IntColumn get segmentIndex => integer().withDefault(const Constant(0))();
  TextColumn get excerpt => text()(); // 书签处文字摘要
  TextColumn get note => text().nullable()(); // 用户备注
  TextColumn get anchor => text().nullable()(); // 节号锚点，内容改动后仍能定位
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// 搜索历史（SOP / 故障 / 术语共用，按 kind 区分；去重保留最近 50 条）。
class SearchHistory extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get kind => text()(); // sop / fault / glossary
  TextColumn get queryText => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [{kind, queryText}];
}

/// 收藏条目（SOP / 故障 / 术语 / 章节均可收藏）。
class Favorites extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get kind => text()(); // sop / fault / glossary / chapter
  TextColumn get title => text()();
  TextColumn get subtitle => text()();
  TextColumn get targetKey => text()(); // sop_id / fault_id / term_id / 章节键
  TextColumn get targetAnchor => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [{kind, targetKey}];
}

/// 每日知识点展示历史（用户数据）：30 天内不重复推荐。
class DailyHistory extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get dayKey => text()(); // yyyy-MM-dd
  TextColumn get factId => text()();
  DateTimeColumn get shownAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [{dayKey, factId}];
}

/// 章节已读标记（用户数据）。
class ChapterReadMarks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get chapterKey => text().unique()();
  BoolColumn get isRead => boolean().withDefault(const Constant(true))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// 术语背诵进度（用户数据）：
/// status: 0=未背，1=还不熟，2=已背；dueAt 驱动间隔复习。
class GlossaryProgress extends Table {
  TextColumn get termId => text()();
  IntColumn get status => integer().withDefault(const Constant(0))();
  IntColumn get seenCount => integer().withDefault(const Constant(0))();
  IntColumn get intervalDays => integer().withDefault(const Constant(0))();
  DateTimeColumn get dueAt => dateTime().nullable()();
  IntColumn get lapses => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {termId};
}

/// 章节学习状态（用户数据）：0 未学 / 1 看过 / 2 掌握；
/// bestScore 为自测最好成绩（满分 = quiz 题数）。
class ChapterLearningProgress extends Table {
  TextColumn get chapterKey => text()();
  IntColumn get status => integer().withDefault(const Constant(0))();
  IntColumn get bestScore => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {chapterKey};
}
