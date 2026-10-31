import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../../data/repositories/book_repositories.dart';
import '../../data/repositories/brew_repositories.dart';
import '../../data/repositories/user_data_repositories.dart';
import '../../domain/models/book_models.dart';
import '../../domain/models/chapter_learning.dart';
import '../../domain/ports/book_repository.dart';
import '../../domain/services/book_learning_service.dart';
import '../../domain/services/daily_service.dart';
import '../../domain/services/study_service.dart';

export '../../data/repositories/user_data_repositories.dart'
    show HistoryEntry;

/// 在 main() 中 override（数据库需异步初始化后才可用）。
final databaseProvider =
    Provider<AppDatabase>((ref) => throw UnimplementedError('override in main()'));

// ---------- 仓库层 ----------

final settingsRepositoryProvider =
    Provider<DriftSettingsRepository>((ref) => DriftSettingsRepository(ref.watch(databaseProvider)));

final userDataRepositoryProvider = Provider<DriftUserDataRepository>(
    (ref) => DriftUserDataRepository(ref.watch(databaseProvider)));

final sopRepositoryProvider = Provider<DriftSopRepository>(
    (ref) => DriftSopRepository(ref.watch(databaseProvider)));

final faultRepositoryProvider = Provider<DriftFaultRepository>(
    (ref) => DriftFaultRepository(ref.watch(databaseProvider)));

final glossaryRepositoryProvider = Provider<DriftGlossaryRepository>(
    (ref) => DriftGlossaryRepository(ref.watch(databaseProvider)));

final brewTablesRepositoryProvider = Provider<DriftBrewTablesRepository>(
    (ref) => DriftBrewTablesRepository(ref.watch(databaseProvider)));

final bookRepositoryProvider = Provider<BookRepository>((ref) => AssetBookRepository());

// ---------- 数据检索（family 键 = 搜索词；空串 = 浏览全部） ----------

final sopQueryProvider = FutureProvider.family<List<SopProcedure>, String>(
    (ref, query) => ref.watch(sopRepositoryProvider).search(query));

final faultQueryProvider = FutureProvider.family<List<FaultDiagnosi>, String>(
    (ref, query) => ref.watch(faultRepositoryProvider).search(query));

final glossaryQueryProvider = FutureProvider.family<List<GlossaryTerm>, String>(
    (ref, query) => ref.watch(glossaryRepositoryProvider).search(query));

/// 工艺参数（family 键 = 工序名；空串 = 全部）。
final processParamsProvider =
    FutureProvider.family<List<ProcessParam>, String>(
        (ref, process) => ref.watch(brewTablesRepositoryProvider).processParams(process));

/// 公式卡列表。
final calcFormulasProvider = FutureProvider<List<CalcFormula>>(
    (ref) => ref.watch(brewTablesRepositoryProvider).calcFormulas());

/// 安全规范列表。
final safetyRulesProvider = FutureProvider<List<SafetyRule>>(
    (ref) => ref.watch(brewTablesRepositoryProvider).safetyRules());

/// 数据集模式：demo = 经验参考库（参数未经核对）/ standard = 已核对库。
final datasetModeProvider = FutureProvider<String>((ref) async {
  final v = await ref.watch(settingsRepositoryProvider).get('dataset_mode');
  return (v == null || v.isEmpty) ? 'demo' : v;
});

// ---------- 每日知识点 ----------

final dailyServiceProvider = Provider<DailyService>(
    (ref) => DailyService(ref.watch(databaseProvider)));

/// 当日候选知识卡（同一天稳定；池去重后按序取前 5 条供"换一条"轮转）。
final dailyCandidatesProvider = FutureProvider<List<DailyFact>>((ref) {
  return ref.watch(dailyServiceProvider).candidates(DateTime.now());
});

/// "换一条"的轮转下标（仅 UI 状态）。
final dailyTipIndexProvider = StateProvider<int>((ref) => 0);

// ---------- 学习统计（v3） ----------

/// 章节学习卡（assets/data/book_learning.json）：chapterKey → 卡片。
final bookLearningProvider = FutureProvider<Map<String, ChapterLearning>>(
    (ref) => BookLearningService.load());

/// 章节学习状态：chapterKey → 0 未学 / 1 看过 / 2 掌握。
final chapterLearningProvider = FutureProvider<Map<String, int>>((ref) {
  return ref.watch(userDataRepositoryProvider).chapterLearningMap();
});

/// 章节已读标记映射（chapterKey → 是否已读）。
final readMarksProvider = FutureProvider<Map<String, bool>>((ref) {
  return ref.watch(userDataRepositoryProvider).readMarks();
});

/// 术语背诵进度（termId → 0 未背 / 1 还不熟 / 2 已背）。
final glossaryProgressProvider = FutureProvider<Map<String, int>>((ref) {
  return ref.watch(userDataRepositoryProvider).glossaryProgressMap();
});

/// 今天到期需要复习的已背术语。
final glossaryDueProvider = FutureProvider<Set<String>>((ref) {
  return ref.watch(userDataRepositoryProvider).dueGlossaryTermIds();
});

/// 今天背下的术语数。
final glossaryLearnedTodayProvider = FutureProvider<int>((ref) {
  return ref.watch(userDataRepositoryProvider).countGlossaryLearnedToday();
});

/// 连续学习天数（app_settings 的 study_streak）。
final studyStreakProvider = FutureProvider<int>((ref) async {
  final v =
      await ref.watch(settingsRepositoryProvider).get(StudyService.keyStreak);
  return int.tryParse(v ?? '') ?? 0;
});

/// 今天是否已产生学习行为。
final studiedTodayProvider = FutureProvider<bool>((ref) async {
  final last = await ref
      .watch(settingsRepositoryProvider)
      .get(StudyService.keyLastDate);
  return last == StudyService.dayKeyOf(DateTime.now());
});

/// 累计看过的每日知识点条数（去重）。
final dailyShownCountProvider = FutureProvider<int>((ref) {
  return ref.watch(dailyServiceProvider).totalShownDistinct();
});

/// 上次阅读信息（书架页"继续上次阅读"用；无记录为 null）。
class LastReadInfo {
  const LastReadInfo({
    required this.chapterKey,
    required this.chapterTitle,
    required this.bookTitle,
    required this.percent,
  });

  final String chapterKey;
  final String chapterTitle;
  final String bookTitle;
  final int percent;
}

final lastReadInfoProvider = FutureProvider<LastReadInfo?>((ref) async {
  final settings = ref.watch(settingsRepositoryProvider);
  final chapterKey = await settings.get('last_read_chapter');
  if (chapterKey == null || chapterKey.isEmpty) return null;
  final percent =
      int.tryParse(await settings.get('last_read_percent') ?? '') ?? 0;
  final chapterTitle =
      await settings.get('last_read_chapter_title') ?? chapterKey;
  final bookTitle = await settings.get('last_read_book_title') ?? '';
  return LastReadInfo(
    chapterKey: chapterKey,
    chapterTitle: chapterTitle,
    bookTitle: bookTitle,
    percent: percent,
  );
});

/// 学习行为入口统一 touch 连续天数。
Future<void> touchStudyStreak(WidgetRef ref) {
  return StudyService.touch(ref.read(settingsRepositoryProvider));
}

// ---------- 搜索历史 / 收藏 ----------

final sopHistoryProvider = FutureProvider<List<HistoryEntry>>((ref) {
  return ref.watch(userDataRepositoryProvider).recentHistory('sop');
});

final faultHistoryProvider = FutureProvider<List<HistoryEntry>>((ref) {
  return ref.watch(userDataRepositoryProvider).recentHistory('fault');
});

final allFavoritesProvider = FutureProvider<List<Favorite>>((ref) {
  return ref.watch(userDataRepositoryProvider).allFavorites();
});

// ---------- 书籍 ----------

final booksProvider =
    FutureProvider<List<Book>>((ref) => ref.watch(bookRepositoryProvider).loadBooks());

final chapterContentProvider = FutureProvider.family<ChapterContent, String>(
    (ref, chapterKey) => ref.watch(bookRepositoryProvider).loadChapter(chapterKey));

/// 每章的书签列表。
final bookmarksForChapterProvider =
    FutureProvider.family<List<Bookmark>, String>((ref, chapterKey) {
  return ref.watch(userDataRepositoryProvider).bookmarksForChapter(chapterKey);
});

/// 全部书签（管理页用）。
final allBookmarksProvider = FutureProvider<List<Bookmark>>((ref) {
  return ref.watch(userDataRepositoryProvider).allBookmarks();
});

/// 每章保存的滚动位置（family 键 = "bookId|chapterKey"）。
final chapterProgressProvider =
    FutureProvider.family<double, String>((ref, arg) {
  final parts = arg.split('|');
  return ref.watch(userDataRepositoryProvider).progressOf(parts[0], parts[1]);
});

// ---------- 设置控制器 ----------

/// 主题模式（system/light/dark），持久化到 app_settings。
class ThemeModeController extends StateNotifier<ThemeMode> {
  ThemeModeController(this._settings) : super(ThemeMode.system);

  final DriftSettingsRepository _settings;
  static const _key = 'theme_mode';

  Future<void> load() async {
    final v = await _settings.get(_key);
    var matched = ThemeMode.system;
    for (final m in ThemeMode.values) {
      if (m.name == v) {
        matched = m;
        break;
      }
    }
    state = matched;
  }

  Future<void> choose(ThemeMode mode) async {
    state = mode;
    await _settings.set(_key, mode.name);
  }
}

final themeModeControllerProvider =
    StateNotifierProvider<ThemeModeController, ThemeMode>(
        (ref) => ThemeModeController(ref.watch(settingsRepositoryProvider)));

/// 色板名（amber/malt/hop/slate），持久化。
class SeedColorController extends StateNotifier<String> {
  SeedColorController(this._settings) : super('amber');

  final DriftSettingsRepository _settings;
  static const _key = 'seed_color';

  Future<void> load() async {
    state = await _settings.get(_key) ?? 'amber';
  }

  Future<void> choose(String name) async {
    state = name;
    await _settings.set(_key, name);
  }
}

final seedColorControllerProvider =
    StateNotifierProvider<SeedColorController, String>(
        (ref) => SeedColorController(ref.watch(settingsRepositoryProvider)));

/// 阅读字号（全局，持久化到 app_settings）。
class FontScaleController extends StateNotifier<FontScale> {
  FontScaleController(this._settings) : super(FontScale.medium);

  final DriftSettingsRepository _settings;
  static const _key = 'reading_font';

  Future<void> load() async {
    state = FontScale.fromName(await _settings.get(_key));
  }

  Future<void> choose(FontScale scale) async {
    state = scale;
    await _settings.set(_key, scale.name);
  }
}

final fontScaleControllerProvider =
    StateNotifierProvider<FontScaleController, FontScale>(
        (ref) => FontScaleController(ref.watch(settingsRepositoryProvider)));

/// 术语背诵模式下次进入的起始下标（app_settings 的 glossary_last_index）。
final glossaryLastIndexProvider = FutureProvider<int>((ref) async {
  final v =
      await ref.watch(settingsRepositoryProvider).get('glossary_last_index');
  return int.tryParse(v ?? '') ?? 0;
});
