import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/book_models.dart';
import '../state/providers.dart';
import '../widgets/reader_markdown.dart';
import '../widgets/states.dart';
import 'bookmarks_manage_page.dart';
import 'glossary_lookup_page.dart';

/// 阅读页：类书籍排版（Markdown 分段渲染），上下滚动，全局字号调整，
/// 上一章/下一章；支持锚点/书签精准定位并高亮；自动记忆阅读进度；
/// 分段可添加书签（带备注）；滚动进度条 + 回到顶部；划词查术语。
class ChapterReadingPage extends ConsumerWidget {
  const ChapterReadingPage({
    super.key,
    required this.chapterKey,
    this.anchor,
    this.jumpSegment,
  });

  final String chapterKey;

  /// 节号锚点（如 "1.2"），非空时加载后自动滚动并高亮该节。
  final String? anchor;

  /// 书签跳转：直接定位到分段下标。
  final int? jumpSegment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = chapterKey.trim();
    final scale = ref.watch(fontScaleControllerProvider);
    final contentAsync = ref.watch(chapterContentProvider(key));
    final marks = ref.watch(readMarksProvider).valueOrNull ?? {};
    final isRead = marks[key] ?? false;

    Future<void> toggleRead() async {
      await ref
          .read(userDataRepositoryProvider)
          .setRead(key, isRead: !isRead);
      await touchStudyStreak(ref);
      ref.invalidate(readMarksProvider);
      ref.invalidate(studiedTodayProvider);
    }

    return Scaffold(
      appBar: AppBar(
        title: contentAsync.whenOrNull(
              data: (c) => Text(c.chapterTitle),
            ) ??
            const Text('阅读'),
        actions: [
          PopupMenuButton<FontScale>(
            icon: const Icon(Icons.format_size),
            tooltip: '字号',
            onSelected: (s) =>
                ref.read(fontScaleControllerProvider.notifier).choose(s),
            itemBuilder: (_) => [
              for (final s in FontScale.values)
                PopupMenuItem(
                  value: s,
                  child: Row(
                    children: [
                      Icon(
                        s == scale ? Icons.check : Icons.circle_outlined,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text('${s.label}号字'),
                    ],
                  ),
                ),
            ],
          ),
          IconButton(
            tooltip: isRead ? '标记为未读' : '标记为已读',
            icon: Icon(isRead ? Icons.remove_done : Icons.done_all),
            onPressed: key.isEmpty ? null : toggleRead,
          ),
          IconButton(
            tooltip: '书签列表',
            icon: const Icon(Icons.bookmarks_outlined),
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const BookmarksManagePage())),
          ),
        ],
      ),
      body: key.isEmpty
          ? const EmptyState(
              icon: Icons.menu_book_outlined,
              title: '这篇内容暂时没找到',
              subtitle: '这条知识点没有带上章节编号。')
          : contentAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => const EmptyState(
                icon: Icons.menu_book_outlined,
                title: '这篇内容暂时没找到',
                subtitle: '可能是书籍数据没更新。',
              ),
              data: (content) => _ReadingView(
                content: content,
                chapterKey: key,
                anchor: anchor,
                jumpSegment: jumpSegment,
              ),
            ),
    );
  }
}

class _ReadingView extends ConsumerStatefulWidget {
  const _ReadingView({
    required this.content,
    required this.chapterKey,
    this.anchor,
    this.jumpSegment,
  });

  final ChapterContent content;
  final String chapterKey;
  final String? anchor;
  final int? jumpSegment;

  @override
  ConsumerState<_ReadingView> createState() => _ReadingViewState();
}

class _ReadingViewState extends ConsumerState<_ReadingView> {
  final _scrollController = ScrollController();
  final _segmentKeys = <int, GlobalKey>{};
  int? _highlightIndex;
  Timer? _highlightTimer;
  Timer? _saveDebounce;
  bool _restored = false;
  double _progress = 0;
  bool _showBackToTop = false;
  bool _jumpNoticeShown = false;
  // 锚点/书签跳转只执行一次；用户之后手动滚动不能被定时器或 rebuild 拉回去。
  bool _initialJumpHandled = false;

  void _notifyJumpMiss(String message) {
    if (_jumpNoticeShown) return;
    _jumpNoticeShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    });
  }

  GlobalKey _keyFor(int index) => _segmentKeys.putIfAbsent(index, GlobalKey.new);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant _ReadingView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 同一页面被换成不同锚点/书签时，允许新目标再跳一次。
    if (oldWidget.anchor != widget.anchor ||
        oldWidget.jumpSegment != widget.jumpSegment) {
      _initialJumpHandled = false;
      _jumpNoticeShown = false;
    }
  }

  void _onScroll() {
    // 实时更新阅读进度条；滚过一屏显示回到顶部。
    if (_scrollController.hasClients &&
        _scrollController.position.maxScrollExtent > 0) {
      final pct = (_scrollController.offset /
              _scrollController.position.maxScrollExtent)
          .clamp(0.0, 1.0);
      if ((pct - _progress).abs() > 0.005) {
        setState(() => _progress = pct);
      }
      final shouldShow = _scrollController.offset > 800;
      if (shouldShow != _showBackToTop) {
        setState(() => _showBackToTop = shouldShow);
      }
    }
    // 滚动停稳（800ms 无滚动）后保存阅读进度。
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 800), () {
      if (!mounted || !_scrollController.hasClients) return;
      ref.read(userDataRepositoryProvider).saveProgress(
            bookId: widget.content.bookId,
            chapterKey: widget.content.chapterKey,
            offsetPx: _scrollController.offset,
          );
      _saveLastRead();
    });
  }

  /// 离开页面前也记录一次最近阅读位置。
  void _saveLastReadSync() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.maxScrollExtent <= 0) return;
    final pct = (_scrollController.offset / pos.maxScrollExtent * 100)
        .round()
        .clamp(0, 100);
    final settings = ref.read(settingsRepositoryProvider);
    settings.set('last_read_percent', '$pct');
    settings.set('last_read_chapter', widget.content.chapterKey);
    settings.set('last_read_chapter_title', widget.content.chapterTitle);
    settings.set('last_read_book_title', widget.content.bookTitle);
  }

  /// 把最近阅读位置写进 app_settings（书架页"继续上次阅读"入口用）。
  Future<void> _saveLastRead() async {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.maxScrollExtent <= 0) return;
    final pct = (_scrollController.offset / pos.maxScrollExtent * 100)
        .round()
        .clamp(0, 100);
    final settings = ref.read(settingsRepositoryProvider);
    await settings.set('last_read_percent', '$pct');
    await settings.set('last_read_chapter', widget.content.chapterKey);
    await settings.set('last_read_chapter_title', widget.content.chapterTitle);
    await settings.set('last_read_book_title', widget.content.bookTitle);
    ref.invalidate(lastReadInfoProvider);
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    if (_scrollController.hasClients) {
      // 离开页面也保存一次最终位置。
      ref.read(userDataRepositoryProvider).saveProgress(
            bookId: widget.content.bookId,
            chapterKey: widget.content.chapterKey,
            offsetPx: _scrollController.offset,
          );
      _saveLastReadSync();
    }
    _scrollController.dispose();
    _highlightTimer?.cancel();
    super.dispose();
  }

  void _highlight(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _keyFor(index).currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutCubic,
          alignment: 0.06,
        );
      }
      setState(() => _highlightIndex = index);
      _highlightTimer?.cancel();
      _highlightTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _highlightIndex = null);
      });
    });
  }

  void _showToc() {
    final content = widget.content;
    final items = <Widget>[];
    for (var i = 0; i < content.segments.length; i++) {
      final heading = content.segments[i].heading;
      if (heading == null || heading.trim().isEmpty) continue;
      items.add(ListTile(
        dense: true,
        leading: const Icon(Icons.article_outlined, size: 18),
        title: Text(heading),
        onTap: () {
          Navigator.of(context).pop();
          _highlight(i);
        },
      ));
    }
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: items.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Text('本章没有可跳转的小节'),
              )
            : ListView(
                shrinkWrap: true,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Text('本章目录',
                        style: Theme.of(ctx).textTheme.titleMedium),
                  ),
                  ...items,
                ],
              ),
      ),
    );
  }

  String? _anchorForSegment(int segmentIndex) {
    final h = widget.content.segments[segmentIndex].heading?.trim();
    if (h == null || h.isEmpty) return null;
    final m = RegExp(r'^([0-9]+(?:\.[0-9]+)*)').firstMatch(h);
    return m?.group(1) ?? h;
  }

  Future<void> _addBookmark(int segmentIndex) async {
    final content = widget.content;
    final plain = content.segments[segmentIndex].bodyMd
        .replaceAll(RegExp(r'[#*|>`\n]'), ' ')
        .trim();
    final excerpt =
        plain.length <= 30 ? plain : '${plain.substring(0, 30)}…';
    final noteController = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加书签'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(excerpt, style: Theme.of(ctx).textTheme.bodySmall),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(
                labelText: '备注（可选）',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('保存书签')),
        ],
      ),
    );
    if (saved == true && mounted) {
      await ref.read(userDataRepositoryProvider).addBookmark(
            bookId: content.bookId,
            chapterKey: content.chapterKey,
            segmentIndex: segmentIndex,
            excerpt: excerpt,
            note: noteController.text.isEmpty ? null : noteController.text,
            anchor: _anchorForSegment(segmentIndex),
          );
      ref.invalidate(bookmarksForChapterProvider(content.chapterKey));
      ref.invalidate(allBookmarksProvider);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('书签已保存')));
      }
    }
    noteController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = ref.watch(fontScaleControllerProvider);
    final content = widget.content;
    final bookmarksAsync =
        ref.watch(bookmarksForChapterProvider(content.chapterKey));

    // 锚点/书签跳转定位：所有入口先做范围检查，找不到就明确告诉用户。
    final requestedAnchor = widget.anchor?.trim();
    final anchorTarget = content.resolveAnchor(requestedAnchor);
    final bookmarkSegment = widget.jumpSegment;
    final safeBookmarkSegment = bookmarkSegment != null &&
            bookmarkSegment >= 0 &&
            bookmarkSegment < content.segments.length
        ? bookmarkSegment
        : null;
    if (requestedAnchor != null &&
        requestedAnchor.isNotEmpty &&
        anchorTarget == null) {
      _notifyJumpMiss('本章没有找到“$requestedAnchor”节，已为你打开本章，可继续向下找');
    } else if (bookmarkSegment != null && safeBookmarkSegment == null) {
      _notifyJumpMiss('这条书签对应的段落已变化，已为你打开本章开头');
    }
    final jumpTarget = anchorTarget ?? safeBookmarkSegment;
    if (!_initialJumpHandled && jumpTarget != null) {
      _initialJumpHandled = true;
      final target = jumpTarget;
      WidgetsBinding.instance.addPostFrameCallback((_) => _highlight(target));
    }

    // 阅读进度恢复：无锚点/书签跳转时，回到上次滚动位置。
    if (jumpTarget == null && !_restored) {
      final saved = ref.watch(
          chapterProgressProvider('${content.bookId}|${content.chapterKey}'));
      saved.whenData((offset) {
        if (!_restored && offset > 40) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted &&
                !_restored &&
                _scrollController.hasClients &&
                _scrollController.offset < 10) {
              _scrollController.jumpTo(offset.clamp(
                  0.0, _scrollController.position.maxScrollExtent));
            }
            _restored = true;
          });
        } else {
          _restored = true;
        }
      });
    }

    final prevKey = content.prevKey ?? '';
    final nextKey = content.nextKey ?? '';

    return Stack(
      children: [
        ListView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            // 阅读进度条：滚动实时更新
            LinearProgressIndicator(
              value: _progress.clamp(0.0, 1.0),
              minHeight: 3,
              backgroundColor:
                  Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
            const SizedBox(height: 10),
            Text(
              content.bookTitle,
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      letterSpacing: 1),
            ),
            const SizedBox(height: 4),
            Text(
              content.chapterTitle,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold, height: 1.3),
            ),
            const SizedBox(height: 12),
            Divider(color: Theme.of(context).colorScheme.outlineVariant),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _showToc,
                icon: const Icon(Icons.toc, size: 18),
                label: const Text('本章目录'),
              ),
            ),
            // 划词搜索：长按选中文字 → 上下文菜单「查术语 / 复制」
            SelectionArea(
              contextMenuBuilder: (context, selectableRegion) =>
                  _SelectionContextMenu(
                selectableRegion: selectableRegion,
              ),
              child: Column(
                children: [
                  for (var i = 0; i < content.segments.length; i++)
                    _segment(
                      context: context,
                      index: i,
                      bodyMd: content.segments[i].bodyMd,
                      scale: scale,
                      highlighted: i == _highlightIndex,
                      bookmarked: bookmarksAsync.valueOrNull
                              ?.any((b) => b.segmentIndex == i) ??
                          false,
                      onBookmark: () => _addBookmark(i),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Divider(color: Theme.of(context).colorScheme.outlineVariant),
            Row(
              children: [
                Expanded(
                  child: prevKey.isEmpty
                      ? const SizedBox()
                      : FilledButton.tonalIcon(
                          onPressed: () => _open(context, prevKey),
                          icon: const Icon(Icons.chevron_left),
                          label: const Text('上一章'),
                        ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: nextKey.isEmpty
                      ? const SizedBox()
                      : FilledButton.icon(
                          onPressed: () => _open(context, nextKey),
                          icon: const Icon(Icons.chevron_right),
                          label: const Text('下一章'),
                        ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
        // 滚过一屏后显示"回到顶部"
        if (_showBackToTop)
          Positioned(
            right: 16,
            bottom: 24,
            child: FloatingActionButton.small(
              heroTag: 'backToTop',
              onPressed: _scrollToTop,
              child: const Icon(Icons.arrow_upward, size: 20),
            ),
          ),
      ],
    );
  }

  void _scrollToTop() {
    _scrollController.animateTo(0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic);
  }

  Widget _segment({
    required BuildContext context,
    required int index,
    required String bodyMd,
    required FontScale scale,
    required bool highlighted,
    required bool bookmarked,
    required VoidCallback onBookmark,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: _keyFor(index),
      decoration: highlighted
          ? BoxDecoration(
              color: scheme.primaryContainer.withOpacity(0.45),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: scheme.primary, width: 1.2),
            )
          : null,
      padding: highlighted
          ? const EdgeInsets.all(10)
          : const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
      child: Stack(
        children: [
          MarkdownBody(
            data: bodyMd,
            softLineBreak: true,
            extensionSet: readerMarkdownExtensions,
            styleSheet: _bookStyleSheet(context, scale),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: '添加书签',
              icon: Icon(
                bookmarked ? Icons.bookmark : Icons.bookmark_border,
                size: 16,
                color: bookmarked
                    ? scheme.primary
                    : scheme.onSurfaceVariant.withOpacity(0.5),
              ),
              onPressed: onBookmark,
            ),
          ),
        ],
      ),
    );
  }

  void _open(BuildContext context, String key) {
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => ChapterReadingPage(chapterKey: key),
    ));
  }
}

/// 划词上下文菜单：查术语 / 复制。
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

/// 书籍排版：随字号档位整体缩放，正文 1.85 倍行距，引用块带左侧色条。
MarkdownStyleSheet _bookStyleSheet(BuildContext context, FontScale scale) {
  final theme = Theme.of(context);
  final s = scale.bodySize / 17;
  final base = theme.textTheme.bodyLarge?.copyWith(
        fontSize: scale.bodySize,
        height: 1.85, // 呼吸感：行距略增
      ) ??
      TextStyle(fontSize: scale.bodySize, height: 1.85);
  final codeStyle = theme.textTheme.bodyMedium?.copyWith(
        fontSize: scale.bodySize * 0.85,
        height: 1.5,
        fontFamily: 'monospace',
      ) ??
      TextStyle(fontSize: scale.bodySize * 0.85);

  return MarkdownStyleSheet.fromTheme(theme).copyWith(
    p: base,
    listBullet: base,
    h1: theme.textTheme.titleLarge?.copyWith(
        fontSize: 22 * s, height: 1.4, fontWeight: FontWeight.bold),
    h2: theme.textTheme.titleMedium?.copyWith(
        fontSize: 19 * s, height: 1.45, fontWeight: FontWeight.bold),
    h3: theme.textTheme.titleSmall?.copyWith(
        fontSize: 17 * s, height: 1.5, fontWeight: FontWeight.bold),
    h4: base.copyWith(fontWeight: FontWeight.bold),
    blockquote: base.copyWith(
        color: theme.colorScheme.onSurfaceVariant, fontStyle: FontStyle.italic),
    blockquoteDecoration: BoxDecoration(
      border: Border(
        left: BorderSide(color: theme.colorScheme.primary, width: 3),
      ),
      color: theme.colorScheme.primaryContainer.withOpacity(0.4),
    ),
    blockquotePadding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
    code: codeStyle.copyWith(
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
    ),
    codeblockDecoration: BoxDecoration(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
    ),
    codeblockPadding: const EdgeInsets.all(10),
    tableHead:
        base.copyWith(fontWeight: FontWeight.bold, fontSize: scale.bodySize * 0.88),
    tableBody: base.copyWith(fontSize: scale.bodySize * 0.88, height: 1.4),
    tableBorder:
        TableBorder.all(color: theme.colorScheme.outlineVariant, width: 1),
    tableColumnWidth: FixedColumnWidth(
        MediaQuery.sizeOf(context).width < 380
            ? 96
            : (MediaQuery.sizeOf(context).width > 700 ? 150 : 112)),
    tableCellsPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    horizontalRuleDecoration: BoxDecoration(
      border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
    ),
  );
}
