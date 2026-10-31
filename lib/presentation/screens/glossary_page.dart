import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../state/providers.dart';
import '../widgets/states.dart';

/// Tab 4：酿造术语。中英双语词库 FTS 检索 + 背诵翻卡模式，完全离线。
class GlossaryPage extends ConsumerStatefulWidget {
  const GlossaryPage({super.key});

  @override
  ConsumerState<GlossaryPage> createState() => _GlossaryPageState();
}

class _GlossaryPageState extends ConsumerState<GlossaryPage> {
  final _searchController = TextEditingController();
  String _query = '';
  String _category = '全部';
  bool _reciteMode = false;
  final _revealed = <int>{};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final termsAsync = ref.watch(glossaryQueryProvider(_query.trim()));

    return Scaffold(
      appBar: AppBar(
        title: const Text('酿造术语'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: ToggleButtons(
                isSelected: [!_reciteMode, _reciteMode],
                onPressed: (i) {
                  setState(() {
                    _reciteMode = i == 1;
                    _revealed.clear();
                  });
                },
                borderRadius: BorderRadius.circular(8),
                constraints: const BoxConstraints(minHeight: 32),
                textStyle: Theme.of(context).textTheme.labelSmall,
                children: const [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text('浏览'),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text('背诵'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: _reciteMode
          ? _ReciteView(
              onExit: () => setState(() => _reciteMode = false),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.translate),
                      hintText: '中英双向搜索：如 attenuation / 发酵度',
                      isDense: true,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
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
                    onChanged: (v) => setState(() => _query = v.trim()),
                  ),
                ),
                SizedBox(
                  height: 36,
                  child: Builder(builder: (context) {
                    final categories = <String>{'全部'};
                    for (final t in termsAsync.valueOrNull ??
                        const <GlossaryTerm>[]) {
                      categories.add(t.category);
                    }
                    return ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      children: [
                        for (final c in categories)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label:
                                  Text(c, style: const TextStyle(fontSize: 12)),
                              visualDensity: VisualDensity.compact,
                              selected: _category == c,
                              onSelected: (_) => setState(() => _category = c),
                            ),
                          ),
                      ],
                    );
                  }),
                ),
                Expanded(
                  child: termsAsync.when(
                    loading: () => const LoadingState(hint: '正在检索术语库…'),
                    error: (e, _) => EmptyState(
                        icon: Icons.error_outline, title: '检索失败：$e'),
                    data: (terms) {
                      var list = terms;
                      if (_category != '全部') {
                        list =
                            list.where((t) => t.category == _category).toList();
                      }
                      if (list.isEmpty) {
                        return EmptyState(
                          icon: Icons.search_off,
                          title: '没有匹配“$_query”的术语',
                          subtitle: '中英均可检索；也可按分类浏览',
                        );
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: list.length,
                        itemBuilder: (_, i) => FadeIn(
                          delay: (i % 10) * 15,
                          child: _TermCard(
                            term: list[i],
                            revealed: _revealed.contains(list[i].id),
                            onToggle: () => setState(() {
                              final id = list[i].id;
                              _revealed.contains(id)
                                  ? _revealed.remove(id)
                                  : _revealed.add(id);
                            }),
                          ),
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

class _TermCard extends StatelessWidget {
  const _TermCard({required this.term, required this.revealed, required this.onToggle});

  final GlossaryTerm term;
  final bool revealed;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(term.en,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: scheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(term.category,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: scheme.onSecondaryContainer)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              revealed
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(term.zh,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                    color: scheme.primary,
                                    fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(term.definition,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(height: 1.5)),
                        if (term.note != null && term.note!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text('老师傅提醒：${term.note}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                      fontStyle: FontStyle.italic)),
                        ],
                      ],
                    )
                  : Text('点击显示释义',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(
                              color: scheme.onSurfaceVariant, letterSpacing: 2)),
            ],
          ),
        ),
      ),
    );
  }
}

/// 背诵模式：翻卡自测（乱序）+ 已背/还不熟标记 + 间隔复习（dueAt）。
class _ReciteView extends ConsumerStatefulWidget {
  const _ReciteView({required this.onExit});

  final VoidCallback onExit;

  @override
  ConsumerState<_ReciteView> createState() => _ReciteViewState();
}

class _ReciteViewState extends ConsumerState<_ReciteView> {
  final _revealed = <int>{};

  int _score(GlossaryTerm t) =>
      (t.id * 9301 + t.en.length * 49297) % 233280;

  Future<void> _saveIndex(int index) async {
    await ref
        .read(settingsRepositoryProvider)
        .set('glossary_last_index', '$index');
  }

  Future<void> _mark(GlossaryTerm t, bool known) async {
    await ref
        .read(userDataRepositoryProvider)
        .markGlossaryTerm(termId: t.termId, known: known);
    await touchStudyStreak(ref);
    ref.invalidate(glossaryProgressProvider);
    ref.invalidate(glossaryDueProvider);
    ref.invalidate(glossaryLearnedTodayProvider);
    ref.invalidate(studiedTodayProvider);
  }

  @override
  Widget build(BuildContext context) {
    final termsAsync = ref.watch(glossaryQueryProvider(''));
    final progressAsync = ref.watch(glossaryProgressProvider);
    final dueAsync = ref.watch(glossaryDueProvider);
    final lastIndexAsync = ref.watch(glossaryLastIndexProvider);

    if (termsAsync.isLoading ||
        progressAsync.isLoading ||
        dueAsync.isLoading) {
      return const LoadingState(hint: '正在加载背诵进度…');
    }
    final terms = termsAsync.valueOrNull ?? const <GlossaryTerm>[];
    final progress = progressAsync.valueOrNull ?? const <String, int>{};
    final due = dueAsync.valueOrNull ?? const <String>{};
    if (terms.isEmpty) {
      return const EmptyState(icon: Icons.translate, title: '术语库为空');
    }

    // 队列：未背 + 还不熟 + 到期的已背词；乱序稳定。
    var queue = [
      for (final t in terms)
        if ((progress[t.termId] ?? 0) != 2 || due.contains(t.termId)) t,
    ];
    if (queue.isEmpty) queue = [...terms];
    queue.sort((a, b) => _score(a).compareTo(_score(b)));
    var start = lastIndexAsync.valueOrNull ?? 0;
    if (start >= queue.length) start = 0;

    final known = progress.values.where((v) => v == 2).length;

    return _RecitePager(
      queue: queue,
      startIndex: start,
      total: terms.length,
      known: known,
      dueCount: due.length,
      progress: progress,
      revealed: _revealed,
      onToggle: (termId) => setState(() {
        _revealed.contains(termId)
            ? _revealed.remove(termId)
            : _revealed.add(termId);
      }),
      onMark: _mark,
      onPage: _saveIndex,
      onExit: widget.onExit,
    );
  }
}

class _RecitePager extends StatefulWidget {
  const _RecitePager({
    required this.queue,
    required this.startIndex,
    required this.total,
    required this.known,
    required this.dueCount,
    required this.progress,
    required this.revealed,
    required this.onToggle,
    required this.onMark,
    required this.onPage,
    required this.onExit,
  });

  final List<GlossaryTerm> queue;
  final int startIndex;
  final int total;
  final int known;
  final int dueCount;
  final Map<String, int> progress;
  final Set<int> revealed;
  final void Function(int termId) onToggle;
  final Future<void> Function(GlossaryTerm t, bool known) onMark;
  final Future<void> Function(int index) onPage;
  final VoidCallback onExit;

  @override
  State<_RecitePager> createState() => _RecitePagerState();
}

class _RecitePagerState extends State<_RecitePager> {
  late final PageController _controller;
  late int _index;
  bool _revealedCurrent = false;
  late Map<String, int> _status;

  @override
  void initState() {
    super.initState();
    _index = widget.startIndex;
    _status = Map<String, int>.from(widget.progress);
    _controller = PageController(initialPage: _index);
    if (widget.queue.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onPage(_index);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _markCurrent(bool known) async {
    if (widget.queue.isEmpty) return;
    final t = widget.queue[_index];
    setState(() {
      _status[t.termId] = known ? 2 : 1;
      _revealedCurrent = false;
    });
    await widget.onMark(t, known);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(known ? '已背：${t.en}' : '标记还不熟：${t.en}'),
      duration: const Duration(milliseconds: 900),
    ));
    if (_index < widget.queue.length - 1) {
      await _controller.nextPage(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final knownNow = _status.values.where((v) => v == 2).length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '第 ${_index + 1}/${widget.queue.length} 条 · 已背 '
                  '$knownNow/${widget.total} · 待复习 ${widget.dueCount}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
              TextButton(onPressed: widget.onExit, child: const Text('去浏览')),
            ],
          ),
        ),
        Expanded(
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.queue.length,
            onPageChanged: (i) {
              setState(() {
                _index = i;
                _revealedCurrent = false;
              });
              widget.onPage(i);
            },
            itemBuilder: (context, i) {
              final t = widget.queue[i];
              final status = _status[t.termId] ?? 0;
              final show = _revealedCurrent || widget.revealed.contains(t.id);
              return Card(
                margin: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: InkWell(
                  onTap: () => setState(
                      () => _revealedCurrent = !_revealedCurrent),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: scheme.secondaryContainer,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(t.category,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall),
                            ),
                            if (status == 2) ...[
                              const SizedBox(width: 6),
                              const Text('已背',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.green)),
                            ] else if (status == 1) ...[
                              const SizedBox(width: 6),
                              const Text('还不熟',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.orange)),
                            ],
                          ],
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(height: 24),
                                Text(t.en,
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .displaySmall
                                        ?.copyWith(
                                            fontWeight: FontWeight.bold)),
                                const SizedBox(height: 16),
                                if (show) ...[
                                  Text(t.zh,
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall
                                          ?.copyWith(
                                              color: scheme.primary)),
                                  const SizedBox(height: 10),
                                  Text(t.definition,
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium),
                                  if (t.note != null &&
                                      t.note!.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text('老师傅提醒：${t.note}',
                                        textAlign: TextAlign.center,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                                fontStyle:
                                                    FontStyle.italic)),
                                  ],
                                ] else
                                  Text('点击卡片显示释义',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                              color: scheme
                                                  .onSurfaceVariant)),
                              ],
                            ),
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TextButton(
                              onPressed: () => setState(() =>
                                  _revealedCurrent = !_revealedCurrent),
                              child: Text(show ? '收起释义' : '显示释义'),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _markCurrent(false),
                                child: const Text('还不熟'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton(
                                onPressed: () => _markCurrent(true),
                                child: const Text('已背'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
