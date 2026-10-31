import 'package:drift/drift.dart';

import '../../domain/services/daily_service.dart';
import '../database/app_database.dart';

/// 搜索历史条目（自建模型，避免直接依赖 Drift 生成的行类名）。
class HistoryEntry {
  const HistoryEntry({
    required this.id,
    required this.kind,
    required this.queryText,
    required this.createdAt,
  });

  final int id;
  final String kind;
  final String queryText;
  final DateTime createdAt;
}

/// 用户学习数据（阅读进度 / 书签 / 搜索历史 / 收藏）——种子导入不清空。
class DriftUserDataRepository {
  DriftUserDataRepository(this._db);

  final AppDatabase _db;

  // ---------- 阅读进度 ----------

  Future<void> saveProgress({
    required String bookId,
    required String chapterKey,
    required double offsetPx,
  }) async {
    // delete-then-insert 保证幂等：ReadingProgress 的唯一约束在
    // (book_id, chapter_key)，insertOnConflictUpdate 只覆盖主键 id。
    await (_db.delete(_db.readingProgress)
          ..where((t) =>
              t.bookId.equals(bookId) & t.chapterKey.equals(chapterKey)))
        .go();
    await _db.into(_db.readingProgress).insert(ReadingProgressCompanion.insert(
          bookId: bookId,
          chapterKey: chapterKey,
          offsetPx: Value(offsetPx),
        ));
  }

  Future<double> progressOf(String bookId, String chapterKey) async {
    final row = await (_db.select(_db.readingProgress)
          ..where((t) =>
              t.bookId.equals(bookId) & t.chapterKey.equals(chapterKey)))
        .getSingleOrNull();
    return row?.offsetPx ?? 0;
  }

  // ---------- 书签 ----------

  Future<void> addBookmark({
    required String bookId,
    required String chapterKey,
    required int segmentIndex,
    required String excerpt,
    String? note,
    String? anchor,
  }) async {
    await _db.into(_db.bookmarks).insert(BookmarksCompanion.insert(
          bookId: bookId,
          chapterKey: chapterKey,
          segmentIndex: Value(segmentIndex),
          excerpt: excerpt,
          note: Value(note),
          anchor: Value(anchor),
        ));
  }

  Future<List<Bookmark>> bookmarksForChapter(String chapterKey) async {
    return await (_db.select(_db.bookmarks)
          ..where((t) => t.chapterKey.equals(chapterKey))
          ..orderBy([(t) => OrderingTerm.asc(t.id)]))
        .get();
  }

  Future<List<Bookmark>> allBookmarks() async {
    return await (_db.select(_db.bookmarks)
          ..orderBy([(t) => OrderingTerm.desc(t.id)]))
        .get();
  }

  Future<void> deleteBookmark(int id) async {
    await (_db.delete(_db.bookmarks)..where((t) => t.id.equals(id))).go();
  }

  // ---------- 搜索历史（去重保留最近 50 条） ----------

  Future<void> addHistory(String kind, String queryText) async {
    final q = queryText.trim();
    if (q.isEmpty) return;
    // 先删旧记录再插入，实现“去重置顶”。
    await (_db.delete(_db.searchHistory)
          ..where((t) => t.kind.equals(kind) & t.queryText.equals(q)))
        .go();
    await _db.into(_db.searchHistory).insert(
          SearchHistoryCompanion.insert(kind: kind, queryText: q),
        );
    // 只保留最近 50 条。
    final rows = await (_db.select(_db.searchHistory)
          ..where((t) => t.kind.equals(kind))
          ..orderBy([(t) => OrderingTerm.desc(t.id)]))
        .get();
    if (rows.length > 50) {
      for (final r in rows.skip(50)) {
        await (_db.delete(_db.searchHistory)..where((t) => t.id.equals(r.id)))
            .go();
      }
    }
  }

  Future<List<HistoryEntry>> recentHistory(String kind,
      {int limit = 10}) async {
    final rows = await (_db.select(_db.searchHistory)
          ..where((t) => t.kind.equals(kind))
          ..orderBy([(t) => OrderingTerm.desc(t.id)])
          ..limit(limit))
        .get();
    return [
      for (final r in rows)
        HistoryEntry(id: r.id, kind: r.kind, queryText: r.queryText, createdAt: r.createdAt),
    ];
  }

  Future<void> clearHistory(String kind) async {
    await (_db.delete(_db.searchHistory)..where((t) => t.kind.equals(kind)))
        .go();
  }

  // ---------- 收藏 ----------

  Future<void> addFavorite({
    required String kind,
    required String title,
    required String subtitle,
    required String targetKey,
    String? targetAnchor,
  }) async {
    // 幂等：同 (kind, targetKey) 只留一条（先查后插，避免依赖 upsert 对
    // uniqueKeys 的冲突目标行为）。
    final existing = await (_db.select(_db.favorites)
          ..where(
              (t) => t.kind.equals(kind) & t.targetKey.equals(targetKey)))
        .getSingleOrNull();
    if (existing != null) return;
    await _db.into(_db.favorites).insert(FavoritesCompanion.insert(
          kind: kind,
          title: title,
          subtitle: subtitle,
          targetKey: targetKey,
          targetAnchor: Value(targetAnchor),
        ));
  }

  Future<void> removeFavorite(String kind, String targetKey) async {
    await (_db.delete(_db.favorites)
          ..where(
              (t) => t.kind.equals(kind) & t.targetKey.equals(targetKey)))
        .go();
  }

  Future<bool> isFavorite(String kind, String targetKey) async {
    final row = await (_db.select(_db.favorites)
          ..where(
              (t) => t.kind.equals(kind) & t.targetKey.equals(targetKey)))
        .getSingleOrNull();
    return row != null;
  }

  Future<List<Favorite>> allFavorites() async {
    return await (_db.select(_db.favorites)
          ..orderBy([(t) => OrderingTerm.desc(t.id)]))
        .get();
  }

  // ---------- 章节已读标记 ----------

  Future<Map<String, bool>> readMarks() async {
    final rows = await _db.select(_db.chapterReadMarks).get();
    return {for (final r in rows) r.chapterKey: r.isRead};
  }

  Future<void> setRead(String chapterKey, {required bool isRead}) async {
    // 唯一键在 chapterKey：delete-then-insert 保证幂等（见 README 坑 13）。
    await (_db.delete(_db.chapterReadMarks)
          ..where((t) => t.chapterKey.equals(chapterKey)))
        .go();
    await _db.into(_db.chapterReadMarks).insert(
          ChapterReadMarksCompanion.insert(chapterKey: chapterKey, isRead: Value(isRead)),
        );
  }

  // ---------- 术语背诵进度（间隔复习） ----------

  Future<Map<String, int>> glossaryProgressMap() async {
    final rows = await _db.select(_db.glossaryProgress).get();
    return {for (final r in rows) r.termId: r.status};
  }

  Future<void> markGlossaryTerm({
    required String termId,
    required bool known,
    DateTime? now,
  }) async {
    final n = now ?? DateTime.now();
    final existing = await (_db.select(_db.glossaryProgress)
          ..where((t) => t.termId.equals(termId)))
        .getSingleOrNull();
    final prevInterval = existing?.intervalDays ?? 0;
    final nextInterval =
        known ? switch (prevInterval) { 0 => 1, 1 => 3, 3 => 7, 7 => 30, _ => 60 } : 0;
    final status = known ? 2 : 1;
    final dueAt = known ? n.add(Duration(days: nextInterval)) : n;
    final lapses = known ? (existing?.lapses ?? 0) : (existing?.lapses ?? 0) + 1;
    if (existing == null) {
      await _db.into(_db.glossaryProgress).insert(
            GlossaryProgressCompanion.insert(
              termId: termId,
              status: Value(status),
              intervalDays: Value(nextInterval),
              dueAt: Value(dueAt),
              lapses: Value(lapses),
            ),
          );
    } else {
      await (_db.update(_db.glossaryProgress)
            ..where((t) => t.termId.equals(termId)))
          .write(GlossaryProgressCompanion(
            status: Value(status),
            intervalDays: Value(nextInterval),
            dueAt: Value(dueAt),
            lapses: Value(lapses),
          ));
    }
  }

  Future<void> markGlossarySeen(String termId) async {
    final existing = await (_db.select(_db.glossaryProgress)
          ..where((t) => t.termId.equals(termId)))
        .getSingleOrNull();
    if (existing == null) {
      await _db.into(_db.glossaryProgress).insert(
            GlossaryProgressCompanion.insert(termId: termId, seenCount: const Value(1)),
          );
    } else {
      await (_db.update(_db.glossaryProgress)
            ..where((t) => t.termId.equals(termId)))
          .write(GlossaryProgressCompanion(
              seenCount: Value(existing.seenCount + 1)));
    }
  }

  Future<void> clearGlossaryTerm(String termId) async {
    await (_db.delete(_db.glossaryProgress)
          ..where((t) => t.termId.equals(termId)))
        .go();
  }

  /// 到期待复习的词（dueAt <= now；含"还不熟"——它标记后立即到期）。
  Future<Set<String>> dueGlossaryTermIds({DateTime? now}) async {
    final n = now ?? DateTime.now();
    final rows = await _db.select(_db.glossaryProgress).get();
    return {
      for (final r in rows)
        if (r.dueAt != null && !r.dueAt!.isAfter(n)) r.termId,
    };
  }

  /// 今天背下的词数（status=2 且 updatedAt 是今天）。
  Future<int> countGlossaryLearnedToday({DateTime? now}) async {
    final n = now ?? DateTime.now();
    final today = DailyService.dayKeyOf(n);
    final rows = await _db.select(_db.glossaryProgress).get();
    return rows
        .where((r) => r.status == 2 && DailyService.dayKeyOf(r.updatedAt) == today)
        .length;
  }
}
