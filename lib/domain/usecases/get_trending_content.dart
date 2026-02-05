import '../entities/content.dart';
import '../repositories/content_repository.dart';

/// Use case: get full home content (featured, trending, movies, series, etc.).
class GetTrendingContent {
  final ContentRepository _repository;

  GetTrendingContent(this._repository);

  Future<HomeContentResult> call() async {
    final featured = await _repository.getFeaturedContent();
    final trending = await _repository.getTrendingContent();
    final continueWatching = await _repository.getContinueWatching();
    final newReleases = await _repository.getNewReleases();
    final recommended = await _repository.getRecommended();
    final movies = await _repository.getMovies();
    final series = await _repository.getSeries();
    final sportsContent = await _repository.getSportsContent();
    final liveContent = await _repository.getLiveContent();

    return HomeContentResult(
      featuredContent: featured,
      trendingContent: trending,
      continueWatching: continueWatching,
      newReleases: newReleases,
      recommended: recommended,
      movies: movies,
      series: series,
      sportsContent: sportsContent,
      liveContent: liveContent,
    );
  }
}

class HomeContentResult {
  final List<Content> featuredContent;
  final List<Content> trendingContent;
  final List<Content> continueWatching;
  final List<Content> newReleases;
  final List<Content> recommended;
  final List<Content> movies;
  final List<Content> series;
  final List<Content> sportsContent;
  final List<Content> liveContent;

  HomeContentResult({
    required this.featuredContent,
    required this.trendingContent,
    required this.continueWatching,
    required this.newReleases,
    required this.recommended,
    required this.movies,
    required this.series,
    required this.sportsContent,
    required this.liveContent,
  });
}
