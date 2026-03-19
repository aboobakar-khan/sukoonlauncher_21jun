import 'package:hive/hive.dart';

part 'calm_watch_item.g.dart';

@HiveType(typeId: 50)
class CalmWatchItem extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String youtubeId;

  @HiveField(3)
  final bool isPlaylist;

  @HiveField(4)
  final String originalUrl;

  @HiveField(5)
  final DateTime addedAt;

  @HiveField(6)
  final bool isCompleted;

  @HiveField(7)
  final String reflection; // optional note when marking completed

  @HiveField(8)
  final String tag; // optional collection / playlist tag name

  CalmWatchItem({
    required this.id,
    required this.title,
    required this.youtubeId,
    required this.isPlaylist,
    required this.originalUrl,
    required this.addedAt,
    this.isCompleted = false,
    this.reflection = '',
    this.tag = '',
  });

  String get thumbnailUrl =>
      'https://img.youtube.com/vi/$youtubeId/hqdefault.jpg';
}
