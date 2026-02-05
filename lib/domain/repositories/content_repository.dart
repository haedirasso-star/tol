import '../entities/content.dart';

/// Abstract repository for content (trending, featured, etc.).
/// Implemented in data layer.
abstract class ContentRepository {
  Future<List<Content>> getTrendingContent();
  Future<List<Content>> getFeaturedContent();
  Future<List<Content>> getNewReleases();
  Future<List<Content>> getContinueWatching();
  Future<List<Content>> getRecommended();
  Future<List<Content>> getMovies();
  Future<List<Content>> getSeries();
  Future<List<Content>> getSportsContent();
  Future<List<Content>> getLiveContent();
}
