import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import '../widgets/states.dart';
import 'book_toc_page.dart';
import 'chapter_reading_page.dart';

/// 书架页：5 本酿造手册入口 + "继续上次阅读"。
class BookshelfPage extends ConsumerWidget {
  const BookshelfPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booksAsync = ref.watch(booksProvider);
    final lastReadAsync = ref.watch(lastReadInfoProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('酿造手册')),
      body: booksAsync.when(
        loading: () => const LoadingState(hint: '正在加载书架…'),
        error: (e, _) => EmptyState(icon: Icons.error_outline, title: '加载失败：$e'),
        data: (books) => ListView(
          padding: const EdgeInsets.all(12),
          children: [
            lastReadAsync.whenOrNull(
                  data: (info) => info == null
                      ? const SizedBox.shrink()
                      : Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          color: Theme.of(context)
                              .colorScheme
                              .primaryContainer
                              .withOpacity(0.4),
                          child: ListTile(
                            leading: const Icon(Icons.play_circle_outline),
                            title: Text(info.chapterTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            subtitle: Text(
                                '继续上次阅读 · ${info.percent}% · ${info.bookTitle}'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () =>
                                Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => ChapterReadingPage(
                                  chapterKey: info.chapterKey),
                            )),
                          ),
                        ),
                ) ??
                const SizedBox.shrink(),
            for (final book in books)
              Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => BookTocPage(bookId: book.bookId),
                  )),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        _cover(book.accent, book.bookId),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(book.title,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                          fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text(book.subtitle,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant)),
                              const SizedBox(height: 6),
                              Text('${book.chapters.length} 章',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _cover(String accent, String bookId) {
    final colors = {
      'primary': const Color(0xFF9A5B13),
      'secondary': const Color(0xFF4E6B2A),
      'tertiary': const Color(0xFF44546A),
    };
    final icons = {
      'ferm_sop': Icons.rule,
      'ferm_fault': Icons.build_circle_outlined,
      'ferm_calc': Icons.functions,
      'ferm_safety': Icons.gpp_maybe_outlined,
      'ferm_newbie': Icons.school_outlined,
    };
    return Container(
      width: 56,
      height: 74,
      decoration: BoxDecoration(
        color: colors[accent] ?? colors['primary'],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icons[bookId] ?? Icons.menu_book, color: Colors.white),
    );
  }
}
