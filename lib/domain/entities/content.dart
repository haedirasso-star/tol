/// Domain entity for content (Movie, Series, Sports, Live).
/// Used across presentation and domain layers.
class Content {
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
  final double? watchProgress; // 0.0 - 1.0 for continue watching

  const Content({
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

  Content copyWith({
    String? id,
    String? title,
    String? description,
    String? posterUrl,
    List<String>? streamingUrls,
    List<String>? qualityOptions,
    List<String>? subtitleLanguages,
    bool? isLive,
    int? year,
    List<String>? genres,
    String? contentType,
    int? totalEpisodes,
    int? duration,
    String? rating,
    double? watchProgress,
  }) {
    return Content(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      posterUrl: posterUrl ?? this.posterUrl,
      streamingUrls: streamingUrls ?? this.streamingUrls,
      qualityOptions: qualityOptions ?? this.qualityOptions,
      subtitleLanguages: subtitleLanguages ?? this.subtitleLanguages,
      isLive: isLive ?? this.isLive,
      year: year ?? this.year,
      genres: genres ?? this.genres,
      contentType: contentType ?? this.contentType,
      totalEpisodes: totalEpisodes ?? this.totalEpisodes,
      duration: duration ?? this.duration,
      rating: rating ?? this.rating,
      watchProgress: watchProgress ?? this.watchProgress,
    );
  }
}
