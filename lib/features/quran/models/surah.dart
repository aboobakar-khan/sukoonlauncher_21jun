class Surah {
  final int id;
  final String name;
  final String transliteration;
  final String type; // "meccan" or "medinan"
  final int totalVerses;
  final String? translation; // English meaning, e.g. "The Opener"

  Surah({
    required this.id,
    required this.name,
    required this.transliteration,
    required this.type,
    required this.totalVerses,
    this.translation,
  });

  /// English meaning of the surah name (e.g. "The Cow"), or '' if unknown.
  String get meaning => translation ?? '';

  factory Surah.fromJson(Map<String, dynamic> json) {
    return Surah(
      id: json['id'] as int,
      name: json['name'] as String,
      transliteration: json['transliteration'] as String,
      type: json['type'] as String,
      totalVerses: json['total_verses'] as int,
      translation: json['translation'] as String?,
    );
  }
}
