import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brew_helper/data/database/app_database.dart';
import 'package:brew_helper/data/repositories/book_repositories.dart';
import 'package:brew_helper/data/repositories/user_data_repositories.dart';
import 'package:brew_helper/domain/services/study_service.dart';

void main() {
  late AppDatabase db;
  late DriftUserDataRepository userRepo;
  late DriftSettingsRepository settings;

  setUpAll(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    userRepo = DriftUserDataRepository(db);
    settings = DriftSettingsRepository(db);
  });

  tearDownAll(() async {
    await db.close();
  });

  group('连续天数 nextStreak（纯函数，算式见断言注释）', () {
    test('首次学习：重置 1', () {
      // 无记录 → 1
      expect(StudyService.nextStreak(null, '2026-10-31', 0), 1);
    });

    test('同日重复 touch：原值不动', () {
      // 当天已累计 → current 原样返回
      expect(StudyService.nextStreak('2026-10-31', '2026-10-31', 5), 5);
    });

    test('昨天学过：+1', () {
      // 10-30 → 10-31 差 1 天 → current+1
      expect(StudyService.nextStreak('2026-10-30', '2026-10-31', 5), 6);
    });

    test('断档一天：重置 1', () {
      // 10-29 → 10-31 差 2 天 → 1
      expect(StudyService.nextStreak('2026-10-29', '2026-10-31', 7), 1);
    });

    test('跨月连续：+1', () {
      // 10-31 → 11-01 差 1 天 → +1
      expect(StudyService.nextStreak('2026-10-31', '2026-11-01', 3), 4);
    });
  });

  test('touch 当天幂等：重复调用不重复累计', () async {
    final now = DateTime(2026, 10, 31, 8, 0);
    await StudyService.touch(settings, now: now);
    await StudyService.touch(settings, now: now.add(const Duration(hours: 2)));
    expect(int.tryParse(await settings.get('study_streak') ?? ''), 1);
    expect(await settings.get('last_study_date'), '2026-10-31');

    // 第二天：+1
    await StudyService.touch(settings,
        now: now.add(const Duration(days: 1)));
    expect(int.tryParse(await settings.get('study_streak') ?? ''), 2);
  });

  test('章节已读：标记/取消/统计', () async {
    await userRepo.setRead('ferm_sop.ch01', isRead: true);
    await userRepo.setRead('ferm_sop.ch02', isRead: true);
    // 重复标记同章幂等
    await userRepo.setRead('ferm_sop.ch01', isRead: true);
    var marks = await userRepo.readMarks();
    expect(marks['ferm_sop.ch01'], isTrue);
    expect(marks.length, 2);

    await userRepo.setRead('ferm_sop.ch01', isRead: false);
    marks = await userRepo.readMarks();
    expect(marks['ferm_sop.ch01'], isFalse);
  });

  test('术语背诵：已背/还不熟/间隔复习到期', () async {
    final now = DateTime(2026, 10, 31, 9, 0);
    await userRepo.markGlossaryTerm(termId: 't041', known: true, now: now);
    var map = await userRepo.glossaryProgressMap();
    expect(map['t041'], 2);

    // 已背后进入间隔复习：1 天后到期
    final due = await userRepo.dueGlossaryTermIds(now: now);
    expect(due.contains('t041'), isFalse);
    final dueTomorrow = await userRepo.dueGlossaryTermIds(
        now: now.add(const Duration(days: 1, minutes: 1)));
    expect(dueTomorrow.contains('t041'), isTrue);

    // 标记还不熟：status=1、lapses+1、立即到期
    await userRepo.markGlossaryTerm(
        termId: 't041', known: false, now: now.add(const Duration(days: 2)));
    map = await userRepo.glossaryProgressMap();
    expect(map['t041'], 1);
    final dueNow = await userRepo
        .dueGlossaryTermIds(now: now.add(const Duration(days: 2)));
    expect(dueNow.contains('t041'), isTrue);

    // 今天背下的词数（updatedAt 由插入时的真实时钟写入，统计也用真实时钟）
    await userRepo.markGlossaryTerm(termId: 't042', known: true);
    final learnedToday = await userRepo.countGlossaryLearnedToday();
    expect(learnedToday, 1);

    // 清除
    await userRepo.clearGlossaryTerm('t041');
    map = await userRepo.glossaryProgressMap();
    expect(map.containsKey('t041'), isFalse);
  });
}
