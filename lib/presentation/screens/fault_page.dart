import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../state/providers.dart';
import '../widgets/states.dart';
import 'fault_detail_page.dart';

/// Tab 3：异常排查。按症状搜索：发酵罐温度高 / CIP 回流液浊 / 酵母扩培染菌…
/// 每条 = 症状 → 可能原因 → 排查步骤 → 对策。
class FaultPage extends ConsumerStatefulWidget {
  const FaultPage({super.key});

  @override
  ConsumerState<FaultPage> createState() => _FaultPageState();
}

class _FaultPageState extends ConsumerState<FaultPage> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final listAsync = ref.watch(faultQueryProvider(_query.trim()));
    final historyAsync = ref.watch(faultHistoryProvider);
    final historyItems =
        historyAsync.valueOrNull ?? const <HistoryEntry>[];

    return Scaffold(
      appBar: AppBar(title: const Text('异常排查')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: '按症状搜：温度高 / 回流液浊 / DMS / 双乙酰',
                isDense: true,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                suffixIcon: _query.isEmpty
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
                      .addHistory('fault', v.trim());
                  ref.invalidate(faultHistoryProvider);
                }
              },
            ),
          ),
          if (historyItems.isNotEmpty && _query.isEmpty)
            SizedBox(
              height: 34,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                children: [
                  const Icon(Icons.history, size: 14),
                  const SizedBox(width: 4),
                  for (final h in historyItems.take(8))
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
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '排查三步法：先看“为什么会出现”→ 再按步骤排除 → 最后落实对策并记录。',
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          ),
          Expanded(
            child: listAsync.when(
              loading: () => const LoadingState(hint: '正在检索故障库…'),
              error: (e, _) =>
                  EmptyState(icon: Icons.error_outline, title: '检索失败：$e'),
              data: (items) {
                if (items.isEmpty) {
                  return EmptyState(
                    icon: Icons.search_off,
                    title: _query.isEmpty ? '故障库为空' : '没有匹配“$_query”的症状',
                    subtitle:
                        _query.isEmpty ? null : '试试更短的关键词，如“温度”“浊”“起泡”',
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: items.length,
                  itemBuilder: (_, i) => FadeIn(
                    delay: (i % 10) * 15,
                    child: _FaultCard(fault: items[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FaultCard extends StatelessWidget {
  const _FaultCard({required this.fault});

  final FaultDiagnosi fault;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => FaultDetailPage(faultId: fault.faultId),
        )),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.report_problem_outlined,
                      size: 16, color: scheme.error),
                  const SizedBox(width: 6),
                  const UnverifiedBadge(),
                  const Spacer(),
                  Text(fault.process,
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: scheme.onSurfaceVariant)),
                ],
              ),
              const SizedBox(height: 6),
              Text('症状：${fault.symptom}',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                fault.causeMd
                    .replaceAll(RegExp(r'[#*`>|]'), ' ')
                    .replaceAll(RegExp(r'\s+'), ' ')
                    .trim(),
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

/// 划词/外部入口跳转用的搜索页（带初始关键词）。
class FaultSearchPage extends ConsumerStatefulWidget {
  const FaultSearchPage({super.key, required this.initialQuery});

  final String initialQuery;

  @override
  ConsumerState<FaultSearchPage> createState() => _FaultSearchPageState();
}

class _FaultSearchPageState extends ConsumerState<FaultSearchPage> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(faultQueryProvider(_controller.text.trim()));
    return Scaffold(
      appBar: AppBar(title: const Text('故障检索')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _controller,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: '按症状搜：温度高 / 回流液浊 / DMS',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: listAsync.when(
              loading: () => const LoadingState(hint: '正在检索…'),
              error: (e, _) =>
                  EmptyState(icon: Icons.error_outline, title: '检索失败：$e'),
              data: (items) => items.isEmpty
                  ? const EmptyState(
                      icon: Icons.search_off, title: '没有匹配的症状')
                  : ListView(
                      padding: const EdgeInsets.all(12),
                      children: [
                        for (final f in items) _FaultCard(fault: f),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
