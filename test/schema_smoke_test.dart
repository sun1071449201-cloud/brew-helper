import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brew_helper/data/database/app_database.dart';

void main() {
  test('schema v3：16 张表 + 3 个 FTS 虚表齐全', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.customSelect('SELECT 1').get();
    expect(db.schemaVersion, 3);

    final tables = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type='table'")
        .get();
    final names = tables.map((r) => r.read<String>('name')).toSet();

    // 种子表
    for (final t in [
      'sop_procedures',
      'process_params',
      'fault_diagnosis',
      'calc_formulas',
      'glossary_terms',
      'safety_rules',
      'daily_facts',
      'seed_meta',
    ]) {
      expect(names, contains(t));
    }

    // 用户表
    for (final t in [
      'app_settings',
      'reading_progress',
      'bookmarks',
      'search_history',
      'favorites',
      'daily_history',
      'chapter_read_marks',
      'glossary_progress',
    ]) {
      expect(names, contains(t));
    }

    // FTS 虚表（onCreate 时创建）
    await db.createAllFts();
    for (final t in ['sop_fts', 'fault_fts', 'glossary_fts']) {
      expect(names, contains(t));
    }

    // 关键列抽查
    Future<Set<String>> columns(String table) async {
      final rows = await db.customSelect('PRAGMA table_info($table)').get();
      return rows.map((r) => r.read<String>('name')).toSet();
    }

    expect(await columns('sop_procedures'),
        containsAll(['sop_id', 'process', 'body_md', 'verified', 'source_ref']));
    expect(await columns('fault_diagnosis'),
        containsAll(['symptom', 'cause_md', 'steps_md', 'remedy_md']));
    expect(await columns('bookmarks'), contains('anchor'));
    expect(await columns('favorites'), containsAll(['kind', 'target_key']));

    await db.close();
  });
}
