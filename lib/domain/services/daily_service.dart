import 'package:drift/drift.dart';

import '../../data/database/app_database.dart';

/// 每日知识点服务：同一天稳定推荐、30 天内不重复、"换一条"按序轮转。
///
/// 选择算法（纯函数部分可单测）：
/// - dayKey = yyyy-MM-dd；dayHash(dayKey) 做当天稳定扰动；
/// - 候选池 = 池子 − 30 天内已展示的；池空回退全池；
/// - 排序键 = (sort * 31 + dayHash) % 100003，同一天结果稳定。
class DailyService {
  DailyService(this._db);

  final AppDatabase _db;

  static const historyWindowDays = 30;

  static String dayKeyOf(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// 当天稳定哈希（不依赖 String.hashCode 的实现细节）。
  static int dayHash(String dayKey) {
    var h = 0;
    for (final c in dayKey.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return h;
  }

  static int orderOf(int sort, int hash) => (sort * 31 + hash) % 100003;

  /// 当日候选（去重后的池按稳定顺序取前 [limit] 条）。
  Future<List<DailyFact>> candidates(DateTime now, {int limit = 5}) async {
    final all = await (_db.select(_db.dailyFacts)
          ..orderBy([(t) => OrderingTerm.asc(t.sort)]))
        .get();
    if (all.isEmpty) return const [];

    final cutoff =
        now.subtract(const Duration(days: historyWindowDays));
    final recent = await (_db.select(_db.dailyHistory)
          ..where((t) => t.shownAt.isBiggerOrEqualValue(cutoff)))
        .get();
    final seen = recent.map((r) => r.factId).toSet();

    var pool = [for (final f in all) if (!seen.contains(f.factId)) f];
    if (pool.isEmpty) pool = all; // 全看过：回退全池重新轮转

    final h = dayHash(dayKeyOf(now));
    pool.sort((a, b) =>
        orderOf(a.sort, h).compareTo(orderOf(b.sort, h)));
    return pool.take(limit).toList();
  }

  /// 累计看过的知识点条数（按 factId 去重，统计页用）。
  Future<int> totalShownDistinct() async {
    final rows = await _db.select(_db.dailyHistory).get();
    return rows.map((r) => r.factId).toSet().length;
  }

  /// 记录展示（dayKey + factId 幂等），并清理窗口外旧记录。
  /// 用 delete-then-insert 保证幂等：drift 的 insertOnConflictUpdate 目标是
  /// 主键 id，覆盖不到 uniqueKeys(day_key, fact_id)，重复插入会撞唯一约束。
  Future<void> markShown(String factId, DateTime now) async {
    final key = dayKeyOf(now);
    await (_db.delete(_db.dailyHistory)
          ..where((t) => t.dayKey.equals(key) & t.factId.equals(factId)))
        .go();
    await _db.into(_db.dailyHistory).insert(
          DailyHistoryCompanion.insert(dayKey: key, factId: factId),
        );
    final cutoff = now.subtract(const Duration(days: historyWindowDays));
    await (_db.delete(_db.dailyHistory)
          ..where((t) => t.shownAt.isSmallerThanValue(cutoff)))
        .go();
  }
}
