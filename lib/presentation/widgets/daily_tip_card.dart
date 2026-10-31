import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../screens/chapter_reading_page.dart';
import '../state/providers.dart';
import 'reader_markdown.dart';

/// 今日知识点卡片：SOP 页顶部"今日一课"。同一天稳定一条，30 天不重复，
/// "换一条"在当日候选里轮转。chapterKey 非空可跳转书籍章节锚点。
class DailyTipCard extends ConsumerStatefulWidget {
  const DailyTipCard({super.key});

  @override
  ConsumerState<DailyTipCard> createState() => _DailyTipCardState();
}

class _DailyTipCardState extends ConsumerState<DailyTipCard> {
  bool _expanded = false;
  final _marked = <String>{};
  bool _firstMarkScheduled = false;

  void _markShown(DailyFact fact) {
    if (_marked.contains(fact.factId)) return;
    _marked.add(fact.factId);
    ref.read(dailyServiceProvider).markShown(fact.factId, DateTime.now());
    touchStudyStreak(ref);
    ref.invalidate(dailyShownCountProvider);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final candidatesAsync = ref.watch(dailyCandidatesProvider);
    final index = ref.watch(dailyTipIndexProvider);

    return candidatesAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => const SizedBox.shrink(),
      data: (candidates) {
        if (candidates.isEmpty) return const SizedBox.shrink();
        final fact = candidates[index % candidates.length];
        // 当天首次展示记入历史（初始化执行一次：帧回调 + 守卫，不在 build 外用 ref.listen）。
        if (!_firstMarkScheduled) {
          _firstMarkScheduled = true;
          final first = fact;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _markShown(first);
          });
        }
        final hasChapter = (fact.chapterKey ?? '').trim().isNotEmpty;

        return Card(
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          color: scheme.primaryContainer.withOpacity(0.35),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.today_outlined, size: 16),
                    const SizedBox(width: 6),
                    Text('今日知识点',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: scheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(fact.category,
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                                  color: scheme.onSecondaryContainer)),
                    ),
                    const Spacer(),
                    Text('${candidates.length} 条待学',
                        style: Theme.of(context).textTheme.labelSmall),
                  ],
                ),
                const SizedBox(height: 8),
                Text(fact.title,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 180),
                  crossFadeState: _expanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  firstChild: GestureDetector(
                    onTap: () => setState(() => _expanded = true),
                    child: Text(
                      _plainBody(fact.bodyMd),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          height: 1.55, color: scheme.onSurface),
                    ),
                  ),
                  secondChild: MarkdownBody(
                    data: fact.bodyMd,
                    softLineBreak: true,
                    extensionSet: readerMarkdownExtensions,
                    styleSheet: MarkdownStyleSheet.fromTheme(
                            Theme.of(context))
                        .copyWith(
                      p: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(height: 1.55),
                      listBullet: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(height: 1.55),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () =>
                          setState(() => _expanded = !_expanded),
                      icon: Icon(
                          _expanded
                              ? Icons.unfold_less
                              : Icons.unfold_more,
                          size: 15),
                      label: Text(_expanded ? '收起' : '展开全文',
                          style: const TextStyle(fontSize: 12)),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        final next = index + 1;
                        ref.read(dailyTipIndexProvider.notifier).state =
                            next;
                        final nxt =
                            candidates[next % candidates.length];
                        _markShown(nxt);
                      },
                      icon: const Icon(Icons.shuffle, size: 15),
                      label: const Text('换一条',
                          style: TextStyle(fontSize: 12)),
                    ),
                    const Spacer(),
                    if (hasChapter)
                      TextButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ChapterReadingPage(
                              chapterKey: fact.chapterKey!.trim(),
                              anchor: fact.anchor?.trim(),
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.menu_book_outlined,
                            size: 15),
                        label: const Text('读相关章节',
                            style: TextStyle(fontSize: 12)),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _plainBody(String md) {
    final plain = md
        .replaceAll(RegExp(r'[#*`>|]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return plain;
  }
}
