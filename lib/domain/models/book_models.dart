// 书籍模块领域模型：manifest.json 定义书籍与章节列表，
// 章节正文为 Markdown 文件（assets/books/...），完全离线。

class Book {
  const Book({
    required this.bookId,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.chapters,
  });

  final String bookId;
  final String title;
  final String subtitle;
  final String accent; // primary / secondary / tertiary（封面配色）
  final List<BookNode> chapters;
}

/// 章节节点：叶子节点才有 file。
class BookNode {
  const BookNode({
    required this.key,
    required this.title,
    this.file,
    this.children = const [],
  });

  final String key; // 全局唯一章节键，如 ferm_sop.ch01
  final String title;
  final String? file; // 相对 assets/books/ 的 Markdown 路径
  final List<BookNode> children;

  bool get isLeaf => file != null;
}

/// 章节分段：按 "## "/"### " 标题切开的渲染单元。heading 为 null 的是章首导语。
/// 锚点定位（精准跳转）以节号（如 "1.2"）匹配 heading 前缀。
class ChapterSegment {
  const ChapterSegment({this.heading, required this.bodyMd});

  final String? heading;
  final String bodyMd;
}

/// 章节正文 + 分段。sections 为节标题列表（章目录展示用）。
class ChapterContent {
  const ChapterContent({
    required this.chapterKey,
    required this.bookId,
    required this.chapterTitle,
    required this.bookTitle,
    required this.bodyMarkdown,
    required this.segments,
    this.prevKey,
    this.nextKey,
  });

  final String chapterKey;
  final String bookId;
  final String chapterTitle;
  final String bookTitle;
  final String bodyMarkdown;
  final List<ChapterSegment> segments;
  final String? prevKey;
  final String? nextKey;

  List<String> get sections => [
        for (final s in segments)
          if (s.heading != null) s.heading!,
      ];

  /// 解析锚点 → 分段下标；匹配不到返回 null（由阅读页给出友好提示）。
  ///
  /// 节号锚点（如 "1.2"）按“完整节号”匹配，避免把 1.2 误跳到 1.2.1；
  /// 非数字锚点（标题文字）仍按前缀匹配。
  int? resolveAnchor(String? anchor) {
    final target = anchor?.trim();
    if (target == null || target.isEmpty) return null;
    final numericAnchor =
        RegExp(r'^[0-9]+(?:\.[0-9]+)*$').hasMatch(target);
    final numericLike = RegExp(r'^[0-9.]+$').hasMatch(target);
    // 只由数字和点组成、但格式不完整（如 "1.2."）判为无效，避免误跳。
    if (numericLike && !numericAnchor) return null;
    for (var i = 0; i < segments.length; i++) {
      final h = segments[i].heading?.trim();
      if (h == null || h.isEmpty) continue;
      if (numericAnchor) {
        final headingNumber =
            RegExp(r'^([0-9]+(?:\.[0-9]+)*)').firstMatch(h)?.group(1);
        if (headingNumber == target) return i;
        continue;
      }
      if (h.startsWith(target)) return i;
    }
    return null;
  }
}

/// 阅读字号档位（全局生效，持久化到 app_settings）。
enum FontScale {
  small(14.5),
  medium(17),
  large(20);

  const FontScale(this.bodySize);

  final double bodySize;

  String get label => switch (this) {
        FontScale.small => '小',
        FontScale.medium => '中',
        FontScale.large => '大',
      };

  static FontScale fromName(String? name) =>
      FontScale.values.firstWhere((v) => v.name == name,
          orElse: () => FontScale.medium);
}
