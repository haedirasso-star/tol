import '../models/content_model.dart';
import 'local_data_source.dart';

/// Local data source implementation (in-memory / Hive later).
class LocalDataSourceImpl implements LocalDataSource {
  final List<ContentModel> _continueWatching = [];

  @override
  Future<List<ContentModel>> getContinueWatching() async {
    return List.from(_continueWatching);
  }

  @override
  Future<void> saveContinueWatching(List<ContentModel> list) async {
    _continueWatching.clear();
    _continueWatching.addAll(list);
  }

  @override
  Future<void> clearCache() async {
    _continueWatching.clear();
  }
}
