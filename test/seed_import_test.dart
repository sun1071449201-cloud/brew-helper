import 'dart:convert';

import 'package:drift/drift.dart' show Value, Variable;
import 'package:drift/native.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:brew_helper/data/database/app_database.dart';
import 'package:brew_helper/data/database/seed_importer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late Map<String, String> files;

  setUpAll(() async {
    files = {};
    for (final name in kSeedFilesForTest) {
      files[name] = await rootBundle.loadString('assets/data/$name');
    }
  });

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('种子全量导入：行数符合清单', () async {
    await SeedImporter(db).seedIfNeeded(files);

    Future<int> count(String table) async {
      final r = await db.customSelect('SELECT COUNT(*) AS c FROM $table').get();
      return r.first.read<int>('c');
    }

    expect(await count('sop_procedures'), 18);
    expect(await count('process_params'), 22);
    expect(await count('fault_diagnosis'), 16);
    expect(await count('calc_formulas'), 8);
    expect(await count('glossary_terms'), 100);
    expect(await count('safety_rules'), 8);
    expect(await count('daily_facts'), 120);
    expect(await count('app_settings'), 2);
  });

  test('幂等：重复导入不重复', () async {
    final importer = SeedImporter(db);
    await importer.seedIfNeeded(files);
    await importer.seedIfNeeded(files);

    final meta = await (db.select(db.seedMeta)).get();
    expect(meta.length, 1);

    final sop = await db.customSelect('SELECT COUNT(*) AS c FROM sop_procedures').get();
    expect(sop.first.read<int>('c'), 18);
  });

  test('FTS：中文子串检索命中（≥3 字符走 trigram）', () async {
    await SeedImporter(db).seedIfNeeded(files);

    final hits = await db.customSelect(
      'SELECT f0.symptom FROM fault_fts ff JOIN fault_diagnosis f0 ON f0.id = ff.rowid '
      'WHERE fault_fts MATCH ? LIMIT 5',
      variables: [const Variable('"双乙酰"')],
    ).get();
    expect(hits, isNotEmpty);

    final sopHits = await db.customSelect(
      'SELECT s.title FROM sop_fts f JOIN sop_procedures s ON s.id = f.rowid '
      'WHERE sop_fts MATCH ? LIMIT 5',
      variables: [const Variable('"酵母扩培"')],
    ).get();
    expect(sopHits, isNotEmpty);

    final termHits = await db.customSelect(
      'SELECT g.en FROM glossary_fts f JOIN glossary_terms g ON g.id = f.rowid '
      'WHERE glossary_fts MATCH ? LIMIT 5',
      variables: [const Variable('"发酵度"')],
    ).get();
    expect(termHits, isNotEmpty);
  });

  test('用户数据保护：书签/收藏/历史/设置在再导入后保留', () async {
    final importer = SeedImporter(db);
    await importer.seedIfNeeded(files);

    await db.into(db.bookmarks).insert(BookmarksCompanion.insert(
          bookId: 'ferm_sop',
          chapterKey: 'ferm_sop.ch01',
          segmentIndex: const Value(2),
          excerpt: '测试书签',
        ));
    await db.into(db.favorites).insertOnConflictUpdate(
          FavoritesCompanion.insert(
            kind: 'sop',
            title: '测试收藏',
            subtitle: 'x',
            targetKey: 'sop_mash_in',
          ),
        );
    // 用户改过设置
    await db
        .into(db.appSettings)
        .insertOnConflictUpdate(AppSettingsCompanion.insert(
          key: 'theme_mode',
          value: 'dark',
        ));
    // 每日知识点历史（用户表，v2 起在跳过集合内）
    await db
        .into(db.dailyHistory)
        .insertOnConflictUpdate(DailyHistoryCompanion.insert(
          dayKey: '2026-10-31',
          factId: 'd001',
        ));

    // 内容变更（追加一条 SOP）触发再导入
    final modified = <String, String>{...files};
    final sopRaw = modified['sop_procedures.json']!;
    final list = (jsonDecode(sopRaw) as List).toList();
    list.add({
      'sop_id': 'sop_test_extra',
      'process': '糖化',
      'title': '测试新增条目',
      'body_md': '测试',
      'keywords': 'test',
      'verified': false,
      'source_ref': '以本厂 SOP 为准',
    });
    modified['sop_procedures.json'] = jsonEncode(list);

    await importer.seedIfNeeded(modified);

    // 用户数据仍在
    final bookmarks = await (db.select(db.bookmarks)).get();
    expect(bookmarks.where((b) => b.excerpt == '测试书签'), isNotEmpty);
    final favs = await (db.select(db.favorites)).get();
    expect(favs.any((f) => f.targetKey == 'sop_mash_in'), isTrue);
    final theme = await (db.select(db.appSettings)
          ..where((t) => t.key.equals('theme_mode')))
        .getSingleOrNull();
    expect(theme?.value, 'dark');
    // 默认设置键仍存在
    final mode = await (db.select(db.appSettings)
          ..where((t) => t.key.equals('dataset_mode')))
        .getSingleOrNull();
    expect(mode, isNotNull);
    // 每日知识点历史保留
    final hist = await (db.select(db.dailyHistory)
          ..where((t) => t.factId.equals('d001')))
        .get();
    expect(hist, isNotEmpty);
    // 新种子生效
    final sopCount =
        await db.customSelect('SELECT COUNT(*) AS c FROM sop_procedures').get();
    expect(sopCount.first.read<int>('c'), 19);
  });
}

/// 与 lib/data/database/seed_files.dart 的 kSeedFiles 保持一致
/// （测试里单独列出，避免测试可执行文件与 lib 的 const 合并问题）。
const kSeedFilesForTest = <String>[
  'sop_procedures.json',
  'process_params.json',
  'fault_diagnosis.json',
  'calc_formulas.json',
  'glossary_terms.json',
  'safety_rules.json',
  'daily_facts.json',
  'app_settings.json',
];
