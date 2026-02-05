import '../models/content_model.dart';

/// Local data source (Hive / Isar / SharedPreferences).
abstract class LocalDataSource {
  Future<List<ContentModel>> getContinueWatching();
  Future<void> saveContinueWatching(List<ContentModel> list);
  Future<void> clearCache();
}
