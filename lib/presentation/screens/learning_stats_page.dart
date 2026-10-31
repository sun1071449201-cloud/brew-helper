import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/book_models.dart';
import '../state/providers.dart';
import 'bookshelf_page.dart';

/// 学习统计页：连续天数 + 章节已读 + 术语已背 + 累计学习量，一眼看到自己的节奏。
class LearningStatsPage extends ConsumerWidget {
  const LearningStatsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streak = ref.watch(studyStreakProvider).valueOrNull ?? 0;
    final studiedToday = ref.watch(studiedTodayProvider).valueOrNull ?? false;
    final marks =
        ref.watch(readMarksProvider).valueOrNull ?? const <String, bool>{};
    final glossaryProgress = ref.watch(glossaryProgressProvider).valueOrNull ??
        const <String, int>{};
    final termsAsync = ref.watch(glossaryQueryProvider(''));
    final booksAsync = ref.watch(booksProvider);
    final favCount = ref.watch(allFavoritesProvider).valueOrNull?.length ?? 0;
    final bmCount = ref.watch(allBookmarksProvider).valueOrNull?.length ?? 0;
    final factsShown = ref.watch(dailyShownCountProvider).valueOrNull ?? 0;
    final learnedToday =
        ref.watch(glossaryLearnedTodayProvider).valueOrNull ?? 0;

    final books = booksAsync.valueOrNull ?? const <Book>[];
    var totalChapters = 0;
    for (final b in books) {
      totalChapters += b.chapters.length;
    }
    final readCount = marks.values.where((v) => v).length;
    final totalTerms = termsAsync.valueOrNull?.length ?? 0;
    final knownTerms = glossaryProgress.values.where((v) => v == 2).length;

    return Scaffold(
      appBar: AppBar(title: const Text('学习统计')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _streakCard(context, streak, studiedToday, learnedToday),
          const SizedBox(height: 8),
          _progressCard(
            context,
            icon: Icons.menu_book_outlined,
            title: '手册章节',
            done: readCount,
            total: totalChapters,
            onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const BookshelfPage())),
          ),
          _progressCard(
            context,
            icon: Icons.translate,
            title: '酿造术语',
            done: knownTerms,
            total: totalTerms,
            onTap: null,
          ),
          const SizedBox(height: 8),
          _countsCard(
            context,
            favorites: favCount,
            bookmarks: bmCount,
            factsShown: factsShown,
          ),
          const SizedBox(height: 12),
          Text(
            '连续天数由每天的学习行为累计：标记已读、背术语、看每日知识点都算。'
            '断一天会重置——把学习酿成习惯，像酵母一样天天干活。',
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _streakCard(
      BuildContext context, int streak, bool studiedToday, int learnedToday) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.primaryContainer.withOpacity(0.4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.local_fire_department,
                size: 40,
                color: streak > 0 ? scheme.primary : scheme.outline),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('连续学习 $streak 天',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    studiedToday
                        ? '今天已学习${learnedToday > 0 ? ' · 背了 $learnedToday 个术语' : ''}'
                        : '今天还没学习，去背两个术语或读一节手册',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _progressCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required int done,
    required int total,
    required VoidCallback? onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final pct = total == 0 ? 0.0 : (done / total).clamp(0.0, 1.0);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: scheme.primary),
                  const SizedBox(width: 8),
                  Text(title,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Text('$done / $total',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(color: scheme.primary)),
                  if (onTap != null)
                    const Icon(Icons.chevron_right, size: 18),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 6,
                  backgroundColor:
                      scheme.surfaceContainerHighest.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _countsCard(
    BuildContext context, {
    required int favorites,
    required int bookmarks,
    required int factsShown,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _count(context, Icons.star, '收藏', favorites),
            _divider(context),
            _count(context, Icons.bookmark, '书签', bookmarks),
            _divider(context),
            _count(context, Icons.today_outlined, '知识卡', factsShown),
          ],
        ),
      ),
    );
  }

  Widget _divider(BuildContext context) {
    return Container(
        width: 1,
        height: 28,
        color: Theme.of(context).colorScheme.outlineVariant);
  }

  Widget _count(BuildContext context, IconData icon, String label, int n) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Icon(icon, size: 20, color: scheme.primary),
        const SizedBox(height: 4),
        Text('$n',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
