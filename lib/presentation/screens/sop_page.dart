import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../state/providers.dart';
import '../widgets/daily_tip_card.dart';
import '../widgets/states.dart';
import 'bookshelf_page.dart';
import 'bookmarks_manage_page.dart';
import 'learning_stats_page.dart';
import 'safety_page.dart';
import 'sop_detail_page.dart';

/// Tab 1：SOP 查询。按工序分类 + FTS 全文搜索，车间里遇到异常先翻这里。
class SopPage extends ConsumerStatefulWidget {
  const SopPage({super.key});

  @override
  ConsumerState<SopPage> createState() => _SopPageState();
}

class _SopPageState extends ConsumerState<SopPage> {
  final _searchController = TextEditingController();
  String _query = '';
  String _process = '全部';

  static const _processes = ['全部', '糖化', '发酵', 'CIP', '过滤', '灌装', '包装'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final modeAsync = ref.watch(datasetModeProvider);
    final historyAsync = ref.watch(sopHistoryProvider);
    final queryText = _query.trim();

    // 搜索词为空时按工序浏览，否则全文检索（页面内再按工序过滤）。
    final listAsync = ref.watch(sopQueryProvider(queryText));

    return Scaffold(
      appBar: AppBar(
        title: const Text('SOP 查询'),
        actions: [
          IconButton(
            tooltip: '学习统计',
            icon: const Icon(Icons.insights_outlined),
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LearningStatsPage())),
          ),
          IconButton(
            tooltip: '安全红线',
            icon: const Icon(Icons.warning_amber_outlined),
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SafetyPage())),
          ),
          IconButton(
            tooltip: '酿造手册',
            icon: const Icon(Icons.menu_book_outlined),
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const BookshelfPage())),
          ),
          IconButton(
            tooltip: '书签管理',
            icon: const Icon(Icons.bookmarks_outlined),
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const BookmarksManagePage())),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: '搜 SOP：如 温度 / CIP / 酵母 / 双乙酰',
                isDense: true,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                suffixIcon: queryText.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      ),
              ),
              onSubmitted: (v) {
                setState(() => _query = v.trim());
                if (v.trim().isNotEmpty) {
                  ref
                      .read(userDataRepositoryProvider)
                      .addHistory('sop', v.trim());
                  ref.invalidate(sopHistoryProvider);
                }
              },
            ),
          ),
          // 工序分类
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final p in _processes)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(p, style: const TextStyle(fontSize: 12)),
                      visualDensity: VisualDensity.compact,
                      selected: _process == p,
                      onSelected: (_) => setState(() => _process = p),
                    ),
                  ),
              ],
            ),
          ),
          // 数据集口径横幅
          modeAsync.whenOrNull(
                data: (mode) => Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: mode == 'standard'
                        ? scheme.primaryContainer.withOpacity(0.5)
                        : scheme.tertiaryContainer.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    mode == 'standard'
                        ? '已核对库：标注“已核对”的条目经人工核对，其余仍以本厂 SOP 为准。'
                        : '经验参考库：所有工艺参数均为经验值，执行前一律以本厂 SOP 为准。',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              ) ??
              const SizedBox.shrink(),
          // 搜索历史
          historyAsync.whenOrNull(
                data: (items) => items.isEmpty
                    ? const SizedBox.shrink()
                    : SizedBox(
                        height: 34,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          children: [
                            const Icon(Icons.history, size: 14),
                            const SizedBox(width: 4),
                            for (final h in items.take(8))
                              Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: ActionChip(
                                  label: Text(h.queryText,
                                      style: const TextStyle(fontSize: 11)),
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () {
                                    _searchController.text = h.queryText;
                                    setState(() => _query = h.queryText);
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
              ) ??
              const SizedBox.shrink(),
          Expanded(
            child: listAsync.when(
              loading: () => const LoadingState(hint: '正在检索 SOP…'),
              error: (e, _) => EmptyState(
                  icon: Icons.error_outline, title: '检索失败：$e'),
              data: (items) {
                var list = items;
                if (_process != '全部') {
                  list =
                      list.where((s) => s.process == _process).toList();
                }
                if (list.isEmpty) {
                  return EmptyState(
                    icon: Icons.search_off,
                    title: queryText.isEmpty
                        ? '$_process 工序暂无 SOP 条目'
                        : '没有匹配“$queryText”的 SOP',
                    subtitle: queryText.isEmpty
                        ? '换一个工序分类看看'
                        : '试试更短的关键词，如“温度”“CIP”',
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: list.length + 1,
                  itemBuilder: (_, i) {
                    if (i == 0) return const DailyTipCard();
                    final idx = i - 1;
                    return FadeIn(
                      delay: (idx % 10) * 15,
                      child: _SopCard(sop: list[idx]),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SopCard extends StatelessWidget {
  const _SopCard({required this.sop});

  final SopProcedure sop;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final preview = sop.bodyMd
        .replaceAll(RegExp(r'[#*`>|]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => SopDetailPage(sopId: sop.sopId),
        )),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: scheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(sop.process,
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(color: scheme.onSecondaryContainer)),
                  ),
                  const SizedBox(width: 6),
                  const UnverifiedBadge(),
                  const Spacer(),
                  const Icon(Icons.chevron_right, size: 18),
                ],
              ),
              const SizedBox(height: 6),
              Text(sop.title,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                preview.length <= 72 ? preview : '${preview.substring(0, 72)}…',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
