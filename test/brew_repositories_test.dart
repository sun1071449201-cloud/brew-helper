import 'package:drift/native.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:brew_helper/data/database/app_database.dart';
import 'package:brew_helper/data/database/seed_importer.dart';
import 'package:brew_helper/data/repositories/brew_repositories.dart';
import 'package:brew_helper/data/repositories/user_data_repositories.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late DriftSopRepository sopRepo;
  late DriftFaultRepository faultRepo;
  late DriftGlossaryRepository glossaryRepo;
  late DriftUserDataRepository userRepo;

  setUpAll(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final files = <String, String>{};
    for (final name in const [
      'sop_procedures.json',
      'process_params.json',
      'fault_diagnosis.json',
      'calc_formulas.json',
      'glossary_terms.json',
      'safety_rules.json',
      'daily_facts.json',
      'app_settings.json',
    ]) {
      files[name] = await rootBundle.loadString('assets/data/$name');
    }
    await SeedImporter(db).seedIfNeeded(files);
    sopRepo = DriftSopRepository(db);
    faultRepo = DriftFaultRepository(db);
    glossaryRepo = DriftGlossaryRepository(db);
    userRepo = DriftUserDataRepository(db);
  });

  tearDownAll(() async {
    await db.close();
  });

  test('SOP 检索：≥3 字符走 FTS，<3 字符回退 LIKE', () async {
    final fts = await sopRepo.search('双乙酰');
    expect(fts, isNotEmpty);

    // 两字词走 LIKE 兜底（FTS trigram 要求 ≥3 字符）
    final like = await sopRepo.search('CIP');
    expect(like, isNotEmpty);
  });

  test('故障检索命中症状关键词', () async {
    final hits = await faultRepo.search('温度');
    expect(hits, isNotEmpty);
    expect(hits.any((f) => f.faultId == 'fault_ferm_temp_high'), isTrue);
  });

  test('术语中英双向检索', () async {
    final en = await glossaryRepo.search('attenuation');
    expect(en, isNotEmpty);
    expect(en.first.zh, '发酵度');

    final zh = await glossaryRepo.search('絮凝');
    expect(zh, isNotEmpty);
    expect(zh.first.en, 'flocculation');
  });

  test('搜索历史去重置顶且限量', () async {
    await userRepo.addHistory('sop', '温度');
    await userRepo.addHistory('sop', '酵母');
    await userRepo.addHistory('sop', '温度'); // 去重置顶
    final list = await userRepo.recentHistory('sop');
    expect(list.length, 2);
    expect(list.first.queryText, '温度');

    await userRepo.clearHistory('sop');
    final cleared = await userRepo.recentHistory('sop');
    expect(cleared, isEmpty);
  });

  test('收藏：按 (kind, targetKey) 幂等', () async {
    await userRepo.addFavorite(
        kind: 'fault', title: 'T', subtitle: 'S', targetKey: 'fault_x');
    await userRepo.addFavorite(
        kind: 'fault', title: 'T', subtitle: 'S', targetKey: 'fault_x');
    final all = await userRepo.allFavorites();
    expect(all.where((f) => f.targetKey == 'fault_x').length, 1);

    await userRepo.removeFavorite('fault', 'fault_x');
    expect(await userRepo.isFavorite('fault', 'fault_x'), isFalse);
  });

  test('阅读进度写入与读取', () async {
    await userRepo.saveProgress(
        bookId: 'ferm_sop', chapterKey: 'ferm_sop.ch01', offsetPx: 320.5);
    final v = await userRepo.progressOf('ferm_sop', 'ferm_sop.ch01');
    expect(v, closeTo(320.5, 0.01));
  });

  test('书签增删查', () async {
    await userRepo.addBookmark(
      bookId: 'ferm_fault',
      chapterKey: 'ferm_fault.ch01',
      segmentIndex: 3,
      excerpt: '排查步骤',
      note: '记得先测冷媒',
      anchor: '1.1',
    );
    final forChapter =
        await userRepo.bookmarksForChapter('ferm_fault.ch01');
    expect(forChapter, isNotEmpty);
    expect(forChapter.first.anchor, '1.1');

    await userRepo.deleteBookmark(forChapter.first.id);
    expect(await userRepo.bookmarksForChapter('ferm_fault.ch01'), isEmpty);
  });
}
