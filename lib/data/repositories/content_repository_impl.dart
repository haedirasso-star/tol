import '../../domain/entities/content.dart';
import '../../domain/repositories/content_repository.dart';
import '../datasources/local_data_source.dart';
import '../datasources/remote_data_source.dart';
import '../models/content_model.dart';

/// Content repository implementation.
/// Uses remote + local data sources.
class ContentRepositoryImpl implements ContentRepository {
  final RemoteDataSource _remote;
  final LocalDataSource _local;

  ContentRepositoryImpl({
    RemoteDataSource? remote,
    LocalDataSource? local,
  })  : _remote = remote ?? RemoteDataSourceImpl(),
        _local = local ?? LocalDataSourceImpl();

  @override
  Future<List<Content>> getTrendingContent() async {
    final models = await _remote.getTrendingContent();
    return models.map((m) => m.toEntity()).toList();
  }

  @override
  Future<List<Content>> getFeaturedContent() async {
    final models = await _remote.getFeaturedContent();
    if (models.isEmpty) {
      final trending = await _remote.getTrendingContent();
      return trending.take(5).map((m) => m.toEntity()).toList();
    }
    return models.map((m) => m.toEntity()).toList();
  }

  @override
  Future<List<Content>> getNewReleases() async {
    final models = await _remote.getNewReleases();
    return models.map((m) => m.toEntity()).toList();
  }

  @override
  Future<List<Content>> getContinueWatching() async {
    final models = await _local.getContinueWatching();
    return models.map((m) => m.toEntity()).toList();
  }

  @override
  Future<List<Content>> getRecommended() async {
    final models = await _remote.getRecommended();
    return models.map((m) => m.toEntity()).toList();
  }

  @override
  Future<List<Content>> getMovies() async {
    final models = await _remote.getMovies();
    return models.map((m) => m.toEntity()).toList();
  }

  @override
  Future<List<Content>> getSeries() async {
    final models = await _remote.getSeries();
    return models.map((m) => m.toEntity()).toList();
  }

  @override
  Future<List<Content>> getSportsContent() async {
    final models = await _remote.getSportsContent();
    return models.map((m) => m.toEntity()).toList();
  }

  @override
  Future<List<Content>> getLiveContent() async {
    final models = await _remote.getLiveContent();
    return models.map((m) => m.toEntity()).toList();
  }
}
