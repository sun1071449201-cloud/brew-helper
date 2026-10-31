import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables/brew_tables.dart';
import 'tables/meta_tables.dart';
import 'tables/user_data_tables.dart';

part 'app_database.g.dart';

/// 三组数据模型（17 张表）：
/// 种子表（导入器覆盖）：SopProcedures / ProcessParams / FaultDiagnosis /
///   CalcFormulas / GlossaryTerms / SafetyRules / DailyFacts / SeedMeta
/// 用户表（导入器跳过）：AppSettings（另有保存恢复逻辑） /
///   ReadingProgress / Bookmarks / SearchHistory / Favorites /
///   DailyHistory / ChapterReadMarks / GlossaryProgress / ChapterLearningProgress
/// FTS5 虚表（SQL 手建，随种子重建）：sop_fts / fault_fts / glossary_fts
@DriftDatabase(tables: [
  SopProcedures,
  ProcessParams,
  FaultDiagnosis,
  CalcFormulas,
  GlossaryTerms,
  SafetyRules,
  DailyFacts,
  SeedMeta,
  AppSettings,
  ReadingProgress,
  Bookmarks,
  SearchHistory,
  Favorites,
  DailyHistory,
  ChapterReadMarks,
  GlossaryProgress,
  ChapterLearningProgress,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 4;

  // ---------- FTS5 全文索引（trigram 分词支持中文子串匹配） ----------

  Future<void> createAllFts() async {
    await customStatement(
      "CREATE VIRTUAL TABLE IF NOT EXISTS sop_fts USING fts5(title, body, keywords, tokenize='trigram')",
    );
    await customStatement(
      "CREATE VIRTUAL TABLE IF NOT EXISTS fault_fts USING fts5(symptom, cause, steps, keywords, tokenize='trigram')",
    );
    await customStatement(
      "CREATE VIRTUAL TABLE IF NOT EXISTS glossary_fts USING fts5(en, zh, definition, tokenize='trigram')",
    );
  }

  Future<void> rebuildSopFts() async {
    await customStatement(
      "CREATE VIRTUAL TABLE IF NOT EXISTS sop_fts USING fts5(title, body, keywords, tokenize='trigram')",
    );
    await customStatement('DELETE FROM sop_fts');
    await customStatement(
      'INSERT INTO sop_fts(rowid, title, body, keywords) '
      'SELECT id, title, body_md, keywords FROM sop_procedures',
    );
  }

  Future<void> rebuildFaultFts() async {
    await customStatement(
      "CREATE VIRTUAL TABLE IF NOT EXISTS fault_fts USING fts5(symptom, cause, steps, keywords, tokenize='trigram')",
    );
    await customStatement('DELETE FROM fault_fts');
    await customStatement(
      'INSERT INTO fault_fts(rowid, symptom, cause, steps, keywords) '
      'SELECT id, symptom, cause_md, steps_md, keywords FROM fault_diagnosis',
    );
  }

  Future<void> rebuildGlossaryFts() async {
    await customStatement(
      "CREATE VIRTUAL TABLE IF NOT EXISTS glossary_fts USING fts5(en, zh, definition, tokenize='trigram')",
    );
    await customStatement('DELETE FROM glossary_fts');
    await customStatement(
      'INSERT INTO glossary_fts(rowid, en, zh, definition) '
      'SELECT id, en, zh, definition FROM glossary_terms',
    );
  }

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await createAllFts();
        },
        onUpgrade: (m, from, to) async {
          // 改表三件套：表类 + schemaVersion+1 + 此处 migration。
          if (from < 2) {
            // v2：每日知识点（种子表 + 30 天去重历史）。
            await m.createTable(dailyFacts);
            await m.createTable(dailyHistory);
          }
          if (from < 3) {
            // v3：章节已读标记 + 术语背诵进度（学习统计的数据底座）。
            await m.createTable(chapterReadMarks);
            await m.createTable(glossaryProgress);
          }
          if (from < 4) {
            // v4：章节学习状态（学习卡 quiz 的数据底座）。
            await m.createTable(chapterLearningProgress);
          }
        },
      );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationSupportDirectory();
    final file = File(p.join(dir.path, 'brew_helper.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
