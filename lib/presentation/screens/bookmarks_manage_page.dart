import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import '../widgets/states.dart';
import 'chapter_reading_page.dart';

/// 书签管理页：全部书签，点击跳回原文段落，支持删除。
class BookmarksManagePage extends ConsumerWidget {
  const BookmarksManagePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmarksAsync = ref.watch(allBookmarksProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('书签管理')),
      body: bookmarksAsync.when(
        loading: () => const LoadingState(hint: '正在加载书签…'),
        error: (e, _) => EmptyState(icon: Icons.error_outline, title: '加载失败：$e'),
        data: (bookmarks) => bookmarks.isEmpty
            ? const EmptyState(
                icon: Icons.bookmark_border,
                title: '还没有书签',
                subtitle: '阅读时点段落右下角的书签图标即可收藏',
              )
            : ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  for (final b in bookmarks)
                    Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: const Icon(Icons.bookmark, size: 18),
                        title: Text(b.excerpt,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                        subtitle: b.note == null || b.note!.isEmpty
                            ? Text('${b.bookId} · ${b.chapterKey}')
                            : Text('备注：${b.note}'),
                        trailing: IconButton(
                          tooltip: '删除书签',
                          icon: const Icon(Icons.delete_outline, size: 18),
                          onPressed: () async {
                            await ref
                                .read(userDataRepositoryProvider)
                                .deleteBookmark(b.id);
                            ref.invalidate(allBookmarksProvider);
                            ref.invalidate(bookmarksForChapterProvider(
                                b.chapterKey));
                          },
                        ),
                        onTap: () =>
                            Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => ChapterReadingPage(
                            chapterKey: b.chapterKey,
                            jumpSegment: b.segmentIndex,
                          ),
                        )),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
