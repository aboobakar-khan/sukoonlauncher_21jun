// Data models for the Islamic Book Reader feature.
// Maps directly to the JSON structure in assets/ar_raheeq_ch*.json

class BookModel {
  final String id;
  final String title;
  final String subtitle;
  final String author;
  final List<ChapterModel> chapters;

  const BookModel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.author,
    required this.chapters,
  });

  factory BookModel.fromJson(Map<String, dynamic> json) {
    return BookModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      author: json['author'] as String? ?? '',
      chapters: (json['chapters'] as List<dynamic>?)
              ?.map((c) => ChapterModel.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class ChapterModel {
  final String id;
  final String title;
  final String arabicTitle;
  final int number;
  final int totalTopics;
  final List<TopicModel> topics;

  const ChapterModel({
    required this.id,
    required this.title,
    required this.arabicTitle,
    required this.number,
    required this.totalTopics,
    required this.topics,
  });

  /// A chapter has content if its topics list is non-empty.
  bool get hasContent => topics.isNotEmpty;

  factory ChapterModel.fromJson(Map<String, dynamic> json) {
    return ChapterModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      arabicTitle: json['arabicTitle'] as String? ?? '',
      number: json['number'] as int? ?? 0,
      totalTopics: json['totalTopics'] as int? ?? 0,
      topics: (json['topics'] as List<dynamic>?)
              ?.map((t) => TopicModel.fromJson(t as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class TopicModel {
  final String id;
  final String title;
  final int number;
  final String topicSummary;
  final List<ParagraphModel> paragraphs;
  final List<String> keyPoints;
  final List<QuizQuestion> quiz;

  const TopicModel({
    required this.id,
    required this.title,
    required this.number,
    required this.topicSummary,
    required this.paragraphs,
    required this.keyPoints,
    required this.quiz,
  });

  factory TopicModel.fromJson(Map<String, dynamic> json) {
    return TopicModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      number: json['number'] as int? ?? 0,
      topicSummary: json['topicSummary'] as String? ?? '',
      paragraphs: (json['paragraphs'] as List<dynamic>?)
              ?.map((p) => ParagraphModel.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
      keyPoints: (json['keyPoints'] as List<dynamic>?)
              ?.map((k) => k as String)
              .toList() ??
          [],
      quiz: (json['quiz'] as List<dynamic>?)
              ?.map((q) => QuizQuestion.fromJson(q as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class ParagraphModel {
  final String id;
  final String text;

  const ParagraphModel({required this.id, required this.text});

  factory ParagraphModel.fromJson(Map<String, dynamic> json) {
    return ParagraphModel(
      id: json['id'] as String? ?? '',
      text: json['text'] as String? ?? '',
    );
  }
}

class QuizQuestion {
  final String id;
  final String question;
  final List<String> options;
  final String answer;

  const QuizQuestion({
    required this.id,
    required this.question,
    required this.options,
    required this.answer,
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    return QuizQuestion(
      id: json['id'] as String? ?? '',
      question: json['question'] as String? ?? '',
      options: (json['options'] as List<dynamic>?)
              ?.map((o) => o as String)
              .toList() ??
          [],
      answer: json['answer'] as String? ?? '',
    );
  }
}
