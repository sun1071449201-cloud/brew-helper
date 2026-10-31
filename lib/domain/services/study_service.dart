import '../../data/repositories/book_repositories.dart';

/// 学习连续天数服务：任何学习行为（标记已读 / 背术语 / 看每日知识点）
/// 当天 touch 一次，连续天数 +1；断一天重置为 1。
class StudyService {
  StudyService._();

  static const keyStreak = 'study_streak';
  static const keyLastDate = 'last_study_date';

  static String dayKeyOf(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// 纯函数：touch 后的连续天数。
  /// - 今天已累计：原值不动
  /// - 昨天有记录：+1
  /// - 断档/首次：重置 1
  static int nextStreak(String? lastDayKey, String todayKey, int current) {
    if (lastDayKey == todayKey) return current;
    if (lastDayKey == null || lastDayKey.isEmpty) return 1;
    final last = DateTime.tryParse(lastDayKey);
    final today = DateTime.tryParse(todayKey);
    if (last == null || today == null) return 1;
    final diff = DateTime(today.year, today.month, today.day)
        .difference(DateTime(last.year, last.month, last.day))
        .inDays;
    return diff == 1 ? current + 1 : 1;
  }

  /// 记录一次学习行为（当天幂等：重复调用不重复累计）。
  static Future<void> touch(DriftSettingsRepository settings,
      {DateTime? now}) async {
    final n = now ?? DateTime.now();
    final today = dayKeyOf(n);
    final current = int.tryParse(await settings.get(keyStreak) ?? '') ?? 0;
    final last = await settings.get(keyLastDate);
    final next = nextStreak(last, today, current);
    if (next != current || last != today) {
      await settings.set(keyStreak, '$next');
      await settings.set(keyLastDate, today);
    }
  }
}
