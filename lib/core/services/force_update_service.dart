import 'firebase_remote_config_service.dart';

/// Service to check if app force update is required.
class ForceUpdateService {
  final FirebaseRemoteConfigService _remoteConfig;

  ForceUpdateService([FirebaseRemoteConfigService? remoteConfig])
      : _remoteConfig = remoteConfig ?? FirebaseRemoteConfigService();

  /// Returns true if user must update the app.
  Future<bool> checkForUpdate() async {
    return _remoteConfig.isForceUpdateRequired();
  }
}
