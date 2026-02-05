import '../../core/services/firebase_remote_config_service.dart';
import '../models/content_model.dart';
import 'remote_data_source.dart';

/// Remote data source implementation using Firebase Remote Config.
class RemoteDataSourceImpl implements RemoteDataSource {
  final FirebaseRemoteConfigService _remoteConfig;

  RemoteDataSourceImpl([FirebaseRemoteConfigService? remoteConfig])
      : _remoteConfig = remoteConfig ?? FirebaseRemoteConfigService();

  @override
  Future<List<ContentModel>> getTrendingContent() async {
    final raw = await _remoteConfig.getTrendingContent();
    return raw.map((e) => ContentModel.fromJson(e)).toList();
  }

  @override
  Future<List<ContentModel>> getFeaturedContent() async {
    final raw = await _remoteConfig.getFeaturedContent();
    return raw.map((e) => ContentModel.fromJson(e)).toList();
  }

  @override
  Future<List<ContentModel>> getNewReleases() async {
    final raw = await _remoteConfig.getNewReleases();
    return raw.map((e) => ContentModel.fromJson(e)).toList();
  }

  @override
  Future<List<ContentModel>> getRecommended() async {
    final trending = await getTrendingContent();
    return trending.take(10).toList();
  }

  @override
  Future<List<ContentModel>> getMovies() async {
    final trending = await getTrendingContent();
    return trending.where((c) => c.contentType != 'series').toList();
  }

  @override
  Future<List<ContentModel>> getSeries() async {
    final trending = await getTrendingContent();
    return trending.where((c) => c.contentType == 'series').toList();
  }

  @override
  Future<List<ContentModel>> getSportsContent() async {
    return [];
  }

  @override
  Future<List<ContentModel>> getLiveContent() async {
    return [];
  }
}
