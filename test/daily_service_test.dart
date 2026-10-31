import 'package:drift/native.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:brew_helper/data/database/app_database.dart';
import 'package:brew_helper/data/database/seed_importer.dart';
import 'package:brew_helper/domain/services/daily_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late DailyService service;

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
    service = DailyService(db);
  });

  tearDownAll(() async {
    await db.close();
  });

  test('dayHash：同一天稳定，不同天不同', () {
    expect(DailyService.dayHash('2026-10-31'),
        DailyService.dayHash('2026-10-31'));
    expect(DailyService.dayHash('2026-10-31'),
        isNot(DailyService.dayHash('2026-11-01')));
    // 纯函数确定性：手动算式 31*31+…取前两位校验稳定性即可，不心算具体值
  });

  test('当日候选：同日两次调用结果一致（稳定推荐）', () async {
    final now = DateTime(2026, 10, 31, 8, 0);
    final a = await service.candidates(now);
    final b = await service.candidates(now);
    expect(a.map((f) => f.factId).toList(), b.map((f) => f.factId).toList());
    expect(a.length, 5);
  });

  test('30 天去重：展示过的不再进入候选池', () async {
    final now = DateTime(2026, 10, 31, 9, 0);
    final first = await service.candidates(now);
    final firstId = first.first.factId;
    await service.markShown(firstId, now);

    final second = await service.candidates(now);
    expect(second.map((f) => f.factId), isNot(contains(firstId)));
  });

  test('markShown 幂等：同日同条只留一行', () async {
    final now = DateTime(2026, 10, 31, 10, 0);
    await service.markShown('d002', now);
    await service.markShown('d002', now);
    final rows = await (db.select(db.dailyHistory)
          ..where((t) => t.factId.equals('d002')))
        .get();
    expect(rows.length, 1);
  });

  test('池全部看过时回退全池（不空转）', () async {
    // 把 40 条全部标记展示
    final now = DateTime(2026, 10, 31, 11, 0);
    final all = await (db.select(db.dailyFacts)).get();
    for (final f in all) {
      await service.markShown(f.factId, now);
    }
    final candidates = await service.candidates(now);
    expect(candidates, isNotEmpty);
  });
}
