import '../../domain/entities/content.dart';

/// Data model for Content (from API / Remote Config).
/// Converts to/from domain entity.
class ContentModel {
  final String id;
  final String title;
  final String description;
  final String posterUrl;
  final List<String> streamingUrls;
  final List<String> qualityOptions;
  final List<String> subtitleLanguages;
  final bool isLive;
  final int? year;
  final List<String> genres;
  final String? contentType;
  final int? totalEpisodes;
  final int? duration;
  final String? rating;
  final double? watchProgress;

  ContentModel({
    required this.id,
    required this.title,
    required this.description,
    required this.posterUrl,
    required this.streamingUrls,
    this.qualityOptions = const [],
    this.subtitleLanguages = const [],
    this.isLive = false,
    this.year,
    this.genres = const [],
    this.contentType,
    this.totalEpisodes,
    this.duration,
    this.rating,
    this.watchProgress,
  });

  factory ContentModel.fromJson(Map<String, dynamic> json) {
    return ContentModel(
      id: json['id'] as String? ?? '',
      title: (json['titleAr'] ?? json['title']) as String? ?? '',
      description: json['description'] as String? ?? '',
      posterUrl: json['posterUrl'] as String? ?? '',
      streamingUrls: (json['streamingUrls'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      qualityOptions: (json['qualityOptions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          ['1080p', '720p', '480p'],
      subtitleLanguages: (json['subtitleLanguages'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      isLive: json['isLive'] as bool? ?? false,
      year: json['year'] as int?,
      genres: (json['genres'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      contentType: json['contentType'] as String?,
      totalEpisodes: json['totalEpisodes'] as int?,
      duration: json['duration'] as int?,
      rating: json['rating'] as String?,
      watchProgress: (json['watchProgress'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'posterUrl': posterUrl,
      'streamingUrls': streamingUrls,
      'qualityOptions': qualityOptions,
      'subtitleLanguages': subtitleLanguages,
      'isLive': isLive,
      'year': year,
      'genres': genres,
      'contentType': contentType,
      'totalEpisodes': totalEpisodes,
      'duration': duration,
      'rating': rating,
      'watchProgress': watchProgress,
    };
  }

  Content toEntity() {
    return Content(
      id: id,
      title: title,
      description: description,
      posterUrl: posterUrl,
      streamingUrls: streamingUrls,
      qualityOptions: qualityOptions,
      subtitleLanguages: subtitleLanguages,
      isLive: isLive,
      year: year,
      genres: genres,
      contentType: contentType,
      totalEpisodes: totalEpisodes,
      duration: duration,
      rating: rating,
      watchProgress: watchProgress,
    );
  }

  static ContentModel fromEntity(Content entity) {
    return ContentModel(
      id: entity.id,
      title: entity.title,
      description: entity.description,
      posterUrl: entity.posterUrl,
      streamingUrls: entity.streamingUrls,
      qualityOptions: entity.qualityOptions,
      subtitleLanguages: entity.subtitleLanguages,
      isLive: entity.isLive,
      year: entity.year,
      genres: entity.genres,
      contentType: entity.contentType,
      totalEpisodes: entity.totalEpisodes,
      duration: entity.duration,
      rating: entity.rating,
      watchProgress: entity.watchProgress,
    );
  }
}
