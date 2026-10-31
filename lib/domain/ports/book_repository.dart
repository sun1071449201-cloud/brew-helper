import '../models/book_models.dart';

/// 书籍数据端口：manifest + 章节 Markdown（assets 离线加载）。
abstract class BookRepository {
  Future<List<Book>> loadBooks();
  Future<ChapterContent> loadChapter(String chapterKey);
}
