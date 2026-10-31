import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import '../widgets/states.dart';
import 'chapter_reading_page.dart';

/// 书目录页：章节列表 → 阅读页。
class BookTocPage extends ConsumerWidget {
  const BookTocPage({super.key, required this.bookId});

  final String bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booksAsync = ref.watch(booksProvider);
    return booksAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: EmptyState(icon: Icons.error_outline, title: '加载失败：$e'),
      ),
      data: (books) {
        final matches =
            books.where((b) => b.bookId == bookId).toList();
        if (matches.isEmpty) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyState(icon: Icons.menu_book, title: '没有找到这本书'),
          );
        }
        final book = matches.first;
        return Scaffold(
          appBar: AppBar(title: Text(book.title)),
          body: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(4, 0, 4, 10),
                child: Text(book.subtitle,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant)),
              ),
              for (var i = 0; i < book.chapters.length; i++)
                Card(
                  margin: const EdgeInsets.symmetric(vertical: 3),
                  child: ListTile(
                    leading: Text('${i + 1}',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary,
                                fontWeight: FontWeight.bold)),
                    title: Text(book.chapters[i].title),
                    trailing:
                        const Icon(Icons.chevron_right, size: 18),
                    onTap: () =>
                        Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ChapterReadingPage(
                          chapterKey: book.chapters[i].key),
                    )),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
