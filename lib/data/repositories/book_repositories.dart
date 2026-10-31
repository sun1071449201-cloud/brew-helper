import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../domain/models/book_models.dart';
import '../../domain/ports/book_repository.dart';
import '../database/app_database.dart';

/// 从 assets/books/manifest.json 与章节 Markdown 文件加载书籍内容（离线）。
class AssetBookRepository implements BookRepository {
  static const _manifestAsset = 'assets/books/manifest.json';
  static const _bookAssetBase = 'assets/books/';

  List<Book>? _cache;
  final Map<String, ChapterContent> _chapterCache = {};

  @override
  Future<List<Book>> loadBooks() async {
    if (_cache != null) return _cache!;
    final raw = await rootBundle.loadString(_manifestAsset);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final books = (decoded['books'] as List).map((b) {
      final m = b as Map<String, dynamic>;
      return Book(
        bookId: m['book_id'] as String,
        title: m['title'] as String,
        subtitle: m['subtitle'] as String,
        accent: m['accent'] as String? ?? 'primary',
        chapters: _parseNodes((m['chapters'] as List).cast<Map<String, dynamic>>()),
      );
    }).toList();
    _cache = books;
    return books;
  }

  List<BookNode> _parseNodes(List<Map<String, dynamic>> nodes) => [
        for (final n in nodes)
          BookNode(
            key: n['key'] as String,
            title: n['title'] as String,
            file: n['file'] as String?,
            children: n['children'] == null
                ? const []
                : _parseNodes((n['children'] as List).cast<Map<String, dynamic>>()),
          ),
      ];

  @override
  Future<ChapterContent> loadChapter(String chapterKey) async {
    final cached = _chapterCache[chapterKey];
    if (cached != null) return cached;
    final books = await loadBooks();
    for (final book in books) {
      final leaves = <BookNode>[];
      void collect(List<BookNode> nodes) {
        for (final n in nodes) {
          if (n.isLeaf) {
            leaves.add(n);
          } else {
            collect(n.children);
          }
        }
      }

      collect(book.chapters);
      for (var i = 0; i < leaves.length; i++) {
        final node = leaves[i];
        if (node.key != chapterKey) continue;
        final md =
            (await rootBundle.loadString('$_bookAssetBase${node.file}'))
                .replaceFirst('\uFEFF', '');
        final content = ChapterContent(
          chapterKey: node.key,
          bookId: book.bookId,
          chapterTitle: node.title,
          bookTitle: book.title,
          bodyMarkdown: md,
          segments: _splitSegments(md),
          prevKey: i > 0 ? leaves[i - 1].key : null,
          nextKey: i < leaves.length - 1 ? leaves[i + 1].key : null,
        );
        _chapterCache[chapterKey] = content;
        return content;
      }
    }
    throw StateError('未找到章节：$chapterKey');
  }

  /// 章节分段：按 Markdown 的 "## "/"### " 标题切开（heading 保留原文本）。
  /// 锚点定位以节号前缀匹配 heading（如 "1.2"），支持到三级小节。
  List<ChapterSegment> _splitSegments(String md) {
    final segments = <ChapterSegment>[];
    final headingRe = RegExp(r'^(#{2,3})\s+(.+)$');
    final buffer = StringBuffer();
    String? currentHeading;

    void flush() {
      final body = buffer.toString().trim();
      if (body.isNotEmpty || currentHeading != null) {
        segments.add(ChapterSegment(heading: currentHeading, bodyMd: body));
      }
    }

    // 兼容 CRLF 与 LF 两种行尾。
    for (final line in md.split(RegExp(r'\r?\n'))) {
      final m = headingRe.firstMatch(line);
      if (m != null) {
        flush();
        buffer.clear();
        currentHeading = m.group(2)!.trim();
        buffer.writeln(line);
      } else {
        buffer.writeln(line);
      }
    }
    flush();
    return segments;
  }
}

class DriftSettingsRepository {
  DriftSettingsRepository(this._db);

  final AppDatabase _db;

  Future<String?> get(String key) async {
    final row = await (_db.select(_db.appSettings)
          ..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> set(String key, String value) async {
    await _db.into(_db.appSettings).insertOnConflictUpdate(
          AppSettingsCompanion(key: Value(key), value: Value(value)),
        );
  }
}
