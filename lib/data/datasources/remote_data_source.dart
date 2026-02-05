import '../models/content_model.dart';

/// Remote data source (API / Firebase Remote Config).
abstract class RemoteDataSource {
  Future<List<ContentModel>> getTrendingContent();
  Future<List<ContentModel>> getFeaturedContent();
  Future<List<ContentModel>> getNewReleases();
  Future<List<ContentModel>> getRecommended();
  Future<List<ContentModel>> getMovies();
  Future<List<ContentModel>> getSeries();
  Future<List<ContentModel>> getSportsContent();
  Future<List<ContentModel>> getLiveContent();
}
