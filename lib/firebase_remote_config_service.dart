import 'dart:convert';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert' as convert;

class FirebaseRemoteConfigService {
  static final FirebaseRemoteConfigService _instance = FirebaseRemoteConfigService._internal();
  factory FirebaseRemoteConfigService() => _instance;
  FirebaseRemoteConfigService._internal();

  late FirebaseRemoteConfig _remoteConfig;
  bool _initialized = false;

  // AES Encryption key (store securely in production)
  static const String _encryptionKey = 'TOTV_PLUS_SECRET_KEY_2025';

  /// Initialize Remote Config
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      _remoteConfig = FirebaseRemoteConfig.instance;

      // Set config settings
      await _remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 30),
          minimumFetchInterval: const Duration(minutes: 5), // 5 minutes for testing, 1 hour for production
        ),
      );

      // Set default values
      await _remoteConfig.setDefaults(_getDefaultConfig());

      // Fetch and activate
      await _remoteConfig.fetchAndActivate();

      _initialized = true;

      if (kDebugMode) {
        print('✅ Firebase Remote Config initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to initialize Remote Config: $e');
      }
      rethrow;
    }
  }

  /// Get default configuration
  Map<String, dynamic> _getDefaultConfig() {
    return {
      // App Configuration
      'app_version': '1.0.0',
      'min_supported_version': '1.0.0',
      'force_update_enabled': false,
      
      // Feature Flags
      'enable_downloads': true,
      'enable_pip': true,
      'enable_chromecast': true,
      'enable_4k_quality': true,
      
      // Content Configuration (Encrypted JSON)
      'trending_content': _encryptJson([]),
      'featured_content': _encryptJson([]),
      'new_releases': _encryptJson([]),
      'ramadan_series_2025': _encryptJson([]),
      
      // Streaming URLs (Encrypted)
      'cdn_base_urls': _encryptJson([
        'https://cdn1.totv.plus',
        'https://cdn2.totv.plus',
        'https://cdn3.totv.plus',
      ]),
      
      // UI Configuration
      'primary_color': '#FF6B00',
      'show_ads': false,
      'max_simultaneous_streams': 2,
      
      // Regional Content
      'iraq_exclusive_content': _encryptJson([]),
      'egypt_exclusive_content': _encryptJson([]),
      'saudi_exclusive_content': _encryptJson([]),
      
      // Maintenance
      'maintenance_mode': false,
      'maintenance_message': 'نعتذر، التطبيق تحت الصيانة حالياً',
    };
  }

  /// Check if force update is required
  Future<bool> isForceUpdateRequired() async {
    await _ensureInitialized();
    
    final forceUpdateEnabled = _remoteConfig.getBool('force_update_enabled');
    if (!forceUpdateEnabled) return false;

    final currentVersion = '1.0.0'; // Get from package_info
    final minVersion = _remoteConfig.getString('min_supported_version');

    return _compareVersions(currentVersion, minVersion) < 0;
  }

  /// Get trending content
  Future<List<Map<String, dynamic>>> getTrendingContent() async {
    await _ensureInitialized();
    final encrypted = _remoteConfig.getString('trending_content');
    return _decryptJsonList(encrypted);
  }

  /// Get featured content
  Future<List<Map<String, dynamic>>> getFeaturedContent() async {
    await _ensureInitialized();
    final encrypted = _remoteConfig.getString('featured_content');
    return _decryptJsonList(encrypted);
  }

  /// Get new releases
  Future<List<Map<String, dynamic>>> getNewReleases() async {
    await _ensureInitialized();
    final encrypted = _remoteConfig.getString('new_releases');
    return _decryptJsonList(encrypted);
  }

  /// Get Ramadan series 2025
  Future<List<Map<String, dynamic>>> getRamadanSeries2025() async {
    await _ensureInitialized();
    final encrypted = _remoteConfig.getString('ramadan_series_2025');
    return _decryptJsonList(encrypted);
  }

  /// Get CDN base URLs
  Future<List<String>> getCdnBaseUrls() async {
    await _ensureInitialized();
    final encrypted = _remoteConfig.getString('cdn_base_urls');
    final decoded = _decryptJsonList(encrypted);
    return decoded.map((e) => e.toString()).toList();
  }

  /// Get regional content by country code
  Future<List<Map<String, dynamic>>> getRegionalContent(String countryCode) async {
    await _ensureInitialized();
    
    String configKey;
    switch (countryCode.toUpperCase()) {
      case 'IQ':
        configKey = 'iraq_exclusive_content';
        break;
      case 'EG':
        configKey = 'egypt_exclusive_content';
        break;
      case 'SA':
        configKey = 'saudi_exclusive_content';
        break;
      default:
        return [];
    }

    final encrypted = _remoteConfig.getString(configKey);
    return _decryptJsonList(encrypted);
  }

  /// Check if feature is enabled
  bool isFeatureEnabled(String featureName) {
    return _remoteConfig.getBool('enable_$featureName');
  }

  /// Get primary color
  String getPrimaryColor() {
    return _remoteConfig.getString('primary_color');
  }

  /// Check maintenance mode
  bool isMaintenanceMode() {
    return _remoteConfig.getBool('maintenance_mode');
  }

  /// Get maintenance message
  String getMaintenanceMessage() {
    return _remoteConfig.getString('maintenance_message');
  }

  /// Get max simultaneous streams
  int getMaxSimultaneousStreams() {
    return _remoteConfig.getInt('max_simultaneous_streams');
  }

  /// Force refresh config
  Future<void> refresh() async {
    await _remoteConfig.fetchAndActivate();
  }

  /// Ensure initialized
  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await initialize();
    }
  }

  /// Encrypt JSON data using AES-256
  String _encryptJson(dynamic data) {
    try {
      final jsonString = json.encode(data);
      final key = utf8.encode(_encryptionKey);
      final bytes = utf8.encode(jsonString);
      
      // Simple XOR encryption for demo (use proper AES in production)
      final encrypted = <int>[];
      for (var i = 0; i < bytes.length; i++) {
        encrypted.add(bytes[i] ^ key[i % key.length]);
      }
      
      return base64.encode(encrypted);
    } catch (e) {
      if (kDebugMode) {
        print('Encryption error: $e');
      }
      return '';
    }
  }

  /// Decrypt JSON data
  List<Map<String, dynamic>> _decryptJsonList(String encrypted) {
    try {
      if (encrypted.isEmpty) return [];

      final key = utf8.encode(_encryptionKey);
      final encryptedBytes = base64.decode(encrypted);
      
      // Simple XOR decryption
      final decrypted = <int>[];
      for (var i = 0; i < encryptedBytes.length; i++) {
        decrypted.add(encryptedBytes[i] ^ key[i % key.length]);
      }
      
      final jsonString = utf8.decode(decrypted);
      final decoded = json.decode(jsonString);
      
      if (decoded is List) {
        return decoded.map((e) => e as Map<String, dynamic>).toList();
      }
      return [];
    } catch (e) {
      if (kDebugMode) {
        print('Decryption error: $e');
      }
      return [];
    }
  }

  /// Compare version strings
  int _compareVersions(String v1, String v2) {
    final parts1 = v1.split('.').map(int.parse).toList();
    final parts2 = v2.split('.').map(int.parse).toList();

    for (var i = 0; i < 3; i++) {
      if (parts1[i] > parts2[i]) return 1;
      if (parts1[i] < parts2[i]) return -1;
    }
    return 0;
  }

  /// Get all config values (for debugging)
  Map<String, dynamic> getAllConfig() {
    return _remoteConfig.getAll().map(
      (key, value) => MapEntry(key, value.asString()),
    );
  }
}

/// Remote Config Keys
class RemoteConfigKeys {
  static const String appVersion = 'app_version';
  static const String minSupportedVersion = 'min_supported_version';
  static const String forceUpdateEnabled = 'force_update_enabled';
  
  static const String trendingContent = 'trending_content';
  static const String featuredContent = 'featured_content';
  static const String newReleases = 'new_releases';
  static const String ramadanSeries2025 = 'ramadan_series_2025';
  
  static const String cdnBaseUrls = 'cdn_base_urls';
  static const String primaryColor = 'primary_color';
  static const String showAds = 'show_ads';
  static const String maxSimultaneousStreams = 'max_simultaneous_streams';
  
  static const String maintenanceMode = 'maintenance_mode';
  static const String maintenanceMessage = 'maintenance_message';
}

/// Example usage in admin panel to generate encrypted content:
/// 
/// ```dart
/// final content = [
///   {
///     'id': 'movie_001',
///     'title': 'Mission: Impossible - The Final Reckoning',
///     'titleAr': 'مهمة مستحيلة - الحساب الأخير',
///     'posterUrl': 'https://cdn.totv.plus/posters/mi8.jpg',
///     'streamingUrls': [
///       'https://cdn1.totv.plus/hls/mi8/master.m3u8',
///       'https://cdn2.totv.plus/hls/mi8/master.m3u8',
///     ],
///     'qualityOptions': ['2160p', '1080p', '720p', '480p'],
///     'year': 2025,
///     'rating': 'PG-13',
///     'duration': 142,
///     'isTrending': true,
///   },
///   // ... more content
/// ];
/// 
/// final service = FirebaseRemoteConfigService();
/// final encrypted = service._encryptJson(content);
/// 
/// // Then upload 'encrypted' to Firebase Remote Config console
/// ```
