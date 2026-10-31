import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/chapter_learning.dart';

/// 章节学习卡加载器：assets/data/book_learning.json（随 APK 内置，完全离线）。
class BookLearningService {
  BookLearningService._();

  static const _asset = 'assets/data/book_learning.json';

  static Map<String, ChapterLearning>? _cache;

  /// 返回 chapterKey → 学习卡 的映射（只含有卡的章节）。
  static Future<Map<String, ChapterLearning>> load() async {
    if (_cache != null) return _cache!;
    final raw = await rootBundle.loadString(_asset);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final map = <String, ChapterLearning>{};
    for (final j in (decoded['chapters'] as List)) {
      final item = ChapterLearning.fromJson(j as Map<String, dynamic>);
      map[item.chapterKey] = item;
    }
    _cache = map;
    return map;
  }
}
