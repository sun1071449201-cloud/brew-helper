import 'package:flutter_test/flutter_test.dart';
import 'package:brew_helper/data/repositories/book_repositories.dart';
import 'package:brew_helper/domain/models/book_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AssetBookRepository repo;

  setUp(() {
    repo = AssetBookRepository();
  });

  test('5 本酿造手册加载，章节文件齐全', () async {
    final books = await repo.loadBooks();
    expect(books.length, 5);
    expect(books.map((b) => b.bookId), containsAll([
      'ferm_sop',
      'ferm_fault',
      'ferm_calc',
      'ferm_safety',
      'ferm_newbie',
    ]));

    for (final book in books) {
      expect(book.chapters, isNotEmpty, reason: '${book.bookId} 无章节');
      for (final node in book.chapters) {
        expect(node.isLeaf, isTrue, reason: '${node.key} 缺 file');
      }
    }
  });

  test('每章可加载，且至少有一个 ## 小节（锚点单位）', () async {
    final books = await repo.loadBooks();
    for (final book in books) {
      for (final node in book.chapters) {
        final content = await repo.loadChapter(node.key);
        expect(content.bookId, book.bookId);
        expect(content.segments, isNotEmpty);
        expect(
          content.sections,
          isNotEmpty,
          reason: '${node.key} 没有 ## 小节，锚点跳转会失效',
        );
      }
    }
  });

  test('锚点解析：完整节号匹配不误跳 1.1.x', () async {
    final books = await repo.loadBooks();
    final ch01 = await repo.loadChapter('ferm_sop.ch01');
    // ch01 有 "## 1.1 糖化：酶的世界" 与 "### 1.1.1 糖化的本质"
    final idx = ch01.resolveAnchor('1.1');
    expect(idx, isNotNull);
    expect(ch01.segments[idx!].heading, startsWith('1.1 '));
    expect(ch01.segments[idx].heading, isNot(startsWith('1.1.1')));
    // 章节上下文有效
    expect(books, isNotEmpty);
  });

  test('prev/next 链条闭合', () async {
    final books = await repo.loadBooks();
    for (final book in books) {
      final leaves = book.chapters;
      for (var i = 0; i < leaves.length; i++) {
        final content = await repo.loadChapter(leaves[i].key);
        if (i > 0) {
          expect(content.prevKey, leaves[i - 1].key);
        } else {
          expect(content.prevKey, isNull);
        }
        if (i < leaves.length - 1) {
          expect(content.nextKey, leaves[i + 1].key);
        } else {
          expect(content.nextKey, isNull);
        }
      }
    }
  });

  test('FontScale 档位回退 medium', () {
    expect(FontScale.fromName('small'), FontScale.small);
    expect(FontScale.fromName('不存在'), FontScale.medium);
  });
}
