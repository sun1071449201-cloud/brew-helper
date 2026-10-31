// 章节学习卡模型：assets/data/book_learning.json（每章速览 + 3 题自测）。
// 出题红线：quiz 答案必须能从该章原文找到依据，逐题回对原文后才准入库。

class QuizItem {
  const QuizItem({
    required this.question,
    required this.options,
    required this.answer,
    required this.explanation,
  });

  final String question;
  final List<String> options;
  final int answer; // 正确选项下标
  final String explanation;

  factory QuizItem.fromJson(Map<String, dynamic> j) => QuizItem(
        question: j['question'] as String,
        options: (j['options'] as List).cast<String>(),
        answer: j['answer'] as int,
        explanation: j['explanation'] as String? ?? '',
      );
}

class ChapterLearning {
  const ChapterLearning({
    required this.chapterKey,
    required this.summary,
    required this.quiz,
  });

  final String chapterKey;
  final List<String> summary; // 本章速览 3~5 条
  final List<QuizItem> quiz; // 3 题；全对 → 掌握，否则看过

  factory ChapterLearning.fromJson(Map<String, dynamic> j) => ChapterLearning(
        chapterKey: j['chapter_key'] as String,
        summary: (j['summary'] as List).cast<String>(),
        quiz: [
          for (final q in (j['quiz'] as List)) QuizItem.fromJson(q),
        ],
      );
}
