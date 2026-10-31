import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart' show Clipboard;

import '../../data/database/app_database.dart';
import '../state/providers.dart';
import '../widgets/reader_markdown.dart';
import '../widgets/states.dart';
import 'fault_page.dart';
import 'glossary_lookup_page.dart';

/// SOP 详情页：Markdown 渲染 + 收藏 + 划词（查术语 / 搜故障）。
class SopDetailPage extends ConsumerWidget {
  const SopDetailPage({super.key, required this.sopId});

  final String sopId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_sopDetailProvider(sopId));
    return async.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: EmptyState(
          icon: Icons.search_off,
          title: '没有找到这条 SOP',
          subtitle: e.toString(),
        ),
      ),
      data: (sop) => _SopDetailView(sop: sop),
    );
  }
}

final _sopDetailProvider =
    FutureProvider.family<SopProcedure, String>((ref, sopId) async {
  final sop = await ref.watch(sopRepositoryProvider).bySopId(sopId);
  if (sop == null) throw StateError('未找到 SOP：$sopId');
  return sop;
});

class _SopDetailView extends ConsumerStatefulWidget {
  const _SopDetailView({required this.sop});

  final SopProcedure sop;

  @override
  ConsumerState<_SopDetailView> createState() => _SopDetailViewState();
}

class _SopDetailViewState extends ConsumerState<_SopDetailView> {
  bool _favLoaded = false;
  bool _isFav = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_favLoaded) return;
    _favLoaded = true;
    // 初始化执行一次：addPostFrameCallback + bool 守卫（不在 build 外用 ref.listen）。
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final fav = await ref
          .read(userDataRepositoryProvider)
          .isFavorite('sop', widget.sop.sopId);
      if (mounted) setState(() => _isFav = fav);
    });
  }

  Future<void> _toggleFav() async {
    final repo = ref.read(userDataRepositoryProvider);
    if (_isFav) {
      await repo.removeFavorite('sop', widget.sop.sopId);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('已取消收藏')));
      }
    } else {
      await repo.addFavorite(
        kind: 'sop',
        title: widget.sop.title,
        subtitle: '${widget.sop.process} · SOP',
        targetKey: widget.sop.sopId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('已收藏')));
      }
    }
    ref.invalidate(allFavoritesProvider);
    if (mounted) setState(() => _isFav = !_isFav);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sop = widget.sop;
    return Scaffold(
      appBar: AppBar(
        title: Text(sop.process, style: const TextStyle(fontSize: 16)),
        actions: [
          IconButton(
            tooltip: _isFav ? '取消收藏' : '收藏',
            icon: Icon(_isFav ? Icons.star : Icons.star_border),
            onPressed: _toggleFav,
          ),
        ],
      ),
      body: SelectionArea(
        contextMenuBuilder: (context, selectableRegion) =>
            _SelectionContextMenu(
          selectableRegion: selectableRegion,
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: scheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(sop.process,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSecondaryContainer)),
                ),
                const SizedBox(width: 6),
                const UnverifiedBadge(),
              ],
            ),
            const SizedBox(height: 8),
            Text(sop.title,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontSize: 20)),
            const SizedBox(height: 8),
            Divider(color: scheme.outlineVariant),
            MarkdownBody(
              data: sop.bodyMd,
              softLineBreak: true,
              extensionSet: readerMarkdownExtensions,
              styleSheet: _detailStyleSheet(context),
            ),
            const SizedBox(height: 16),
            Text(
              '来源：${sop.sourceRef ?? '以本厂 SOP 为准'} · 本条为经验整理，执行前核对车间现行工艺卡。',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// 划词上下文菜单：查术语 / 搜故障 / 复制。
class _SelectionContextMenu extends StatelessWidget {
  const _SelectionContextMenu({required this.selectableRegion});

  final SelectableRegionState selectableRegion;

  Future<String?> _grabText() async {
    // copySelection 在 3.24 仍是取选中文本的稳定途径。
    // ignore: deprecated_member_use
    selectableRegion.copySelection(SelectionChangedCause.toolbar);
    final data = await Clipboard.getData('text/plain');
    return data?.text?.trim();
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: selectableRegion.contextMenuAnchors,
      buttonItems: [
        ContextMenuButtonItem(
          label: '查术语',
          onPressed: () async {
            final text = await _grabText();
            selectableRegion.hideToolbar();
            if (text == null || text.isEmpty || !context.mounted) return;
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => GlossaryLookupPage(query: text),
            ));
          },
        ),
        ContextMenuButtonItem(
          label: '搜故障',
          onPressed: () async {
            final text = await _grabText();
            selectableRegion.hideToolbar();
            if (text == null || text.isEmpty || !context.mounted) return;
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => FaultSearchPage(initialQuery: text),
            ));
          },
        ),
        ContextMenuButtonItem(
          label: '复制',
          onPressed: () {
            // ignore: deprecated_member_use
            selectableRegion.copySelection(SelectionChangedCause.toolbar);
            selectableRegion.hideToolbar();
          },
        ),
      ],
    );
  }
}

MarkdownStyleSheet _detailStyleSheet(BuildContext context) {
  final theme = Theme.of(context);
  final base = theme.textTheme.bodyLarge ??
      const TextStyle(fontSize: 15.5, height: 1.6);
  return MarkdownStyleSheet.fromTheme(theme).copyWith(
    p: base,
    listBullet: base,
    h2: theme.textTheme.titleMedium
        ?.copyWith(fontSize: 18, fontWeight: FontWeight.bold),
    h3: theme.textTheme.titleSmall
        ?.copyWith(fontSize: 16, fontWeight: FontWeight.bold),
    blockquote: base.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontStyle: FontStyle.italic),
    blockquoteDecoration: BoxDecoration(
      border: Border(
        left: BorderSide(color: theme.colorScheme.primary, width: 3),
      ),
      color: theme.colorScheme.primaryContainer.withOpacity(0.4),
    ),
    blockquotePadding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
    code: base.copyWith(
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
      fontFamily: 'monospace',
      fontSize: 14,
    ),
    codeblockDecoration: BoxDecoration(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
    ),
    codeblockPadding: const EdgeInsets.all(10),
    tableBorder:
        TableBorder.all(color: theme.colorScheme.outlineVariant, width: 1),
    tableCellsPadding:
        const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
  );
}
