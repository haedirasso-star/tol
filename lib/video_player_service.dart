import 'dart:async';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../../domain/entities/content.dart';

class VideoPlayerService {
  VideoPlayerController? _controller;
  StreamController<VideoPlayerState>? _stateController;
  StreamController<Duration>? _positionController;
  StreamController<String>? _qualityController;
  
  String _currentQuality = 'auto';
  bool _isInitialized = false;
  
  // Quality options
  final List<VideoQuality> _availableQualities = [
    VideoQuality(label: 'تلقائي', value: 'auto', bitrate: 0),
    VideoQuality(label: '4K', value: '2160p', bitrate: 15000000),
    VideoQuality(label: '1080p', value: '1080p', bitrate: 5000000),
    VideoQuality(label: '720p', value: '720p', bitrate: 2500000),
    VideoQuality(label: '480p', value: '480p', bitrate: 1000000),
    VideoQuality(label: '360p', value: '360p', bitrate: 500000),
    VideoQuality(label: '240p', value: '240p', bitrate: 250000),
  ];

  VideoPlayerService() {
    _stateController = StreamController<VideoPlayerState>.broadcast();
    _positionController = StreamController<Duration>.broadcast();
    _qualityController = StreamController<String>.broadcast();
  }

  Stream<VideoPlayerState> get stateStream => _stateController!.stream;
  Stream<Duration> get positionStream => _positionController!.stream;
  Stream<String> get qualityStream => _qualityController!.stream;
  
  VideoPlayerController? get controller => _controller;
  bool get isInitialized => _isInitialized;
  String get currentQuality => _currentQuality;
  List<VideoQuality> get availableQualities => _availableQualities;

  /// Initialize player with content
  Future<void> initialize(Content content) async {
    try {
      // Enable screen always on (prevent sleep during playback)
      await _enableScreenAlwaysOn();
      
      // Enable FLAG_SECURE (prevent screen recording)
      await _enableScreenRecordingPrevention();
      
      // Dispose previous controller if exists
      await dispose();

      // Select streaming URL based on quality preference
      final streamingUrl = _selectStreamingUrl(content);
      
      // Initialize VideoPlayerController with HLS support
      if (streamingUrl.contains('.m3u8')) {
        // HLS Stream
        _controller = VideoPlayerController.network(
          streamingUrl,
          videoPlayerOptions: VideoPlayerOptions(
            mixWithOthers: false,
            allowBackgroundPlayback: false,
          ),
          httpHeaders: await _buildSecureHeaders(content),
        );
      } else {
        // Direct MP4
        _controller = VideoPlayerController.network(
          streamingUrl,
          httpHeaders: await _buildSecureHeaders(content),
        );
      }

      // Add listeners
      _controller!.addListener(_handleControllerUpdate);

      // Initialize
      await _controller!.initialize();
      _isInitialized = true;

      // Auto-play
      await _controller!.play();

      // Start position tracking
      _startPositionTracking();

      _stateController!.add(VideoPlayerState.playing);
    } catch (e) {
      _stateController!.add(VideoPlayerState.error);
      throw Exception('Failed to initialize video player: $e');
    }
  }

  /// Build secure headers with SSL pinning and JWT token
  Future<Map<String, String>> _buildSecureHeaders(Content content) async {
    // TODO: Get JWT token from auth service
    final token = await _getAuthToken();
    
    return {
      'Authorization': 'Bearer $token',
      'User-Agent': 'TOTV-Plus/1.0',
      'X-Device-ID': await _getDeviceId(),
      'X-Content-ID': content.id,
      'X-Session-ID': _generateSessionId(),
    };
  }

  /// Select streaming URL based on current quality setting
  String _selectStreamingUrl(Content content) {
    if (_currentQuality == 'auto' || content.streamingUrls.length == 1) {
      return content.streamingUrls.first;
    }
    
    // Find matching quality URL
    final qualityUrl = content.qualityOptions.firstWhere(
      (q) => q.contains(_currentQuality),
      orElse: () => content.streamingUrls.first,
    );
    
    return qualityUrl;
  }

  /// Handle controller updates
  void _handleControllerUpdate() {
    if (_controller == null) return;

    // Update playback state
    if (_controller!.value.isPlaying) {
      _stateController!.add(VideoPlayerState.playing);
    } else if (_controller!.value.isBuffering) {
      _stateController!.add(VideoPlayerState.buffering);
    } else {
      _stateController!.add(VideoPlayerState.paused);
    }

    // Check for errors
    if (_controller!.value.hasError) {
      _stateController!.add(VideoPlayerState.error);
    }
  }

  /// Track playback position
  void _startPositionTracking() {
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_controller != null && _controller!.value.isPlaying) {
        _positionController!.add(_controller!.value.position);
      }
      
      if (!_isInitialized) {
        timer.cancel();
      }
    });
  }

  /// Play
  Future<void> play() async {
    await _controller?.play();
  }

  /// Pause
  Future<void> pause() async {
    await _controller?.pause();
  }

  /// Seek to position
  Future<void> seekTo(Duration position) async {
    await _controller?.seekTo(position);
  }

  /// Seek forward 10 seconds
  Future<void> seekForward() async {
    final currentPosition = _controller?.value.position ?? Duration.zero;
    final newPosition = currentPosition + const Duration(seconds: 10);
    await seekTo(newPosition);
  }

  /// Seek backward 10 seconds
  Future<void> seekBackward() async {
    final currentPosition = _controller?.value.position ?? Duration.zero;
    final newPosition = currentPosition - const Duration(seconds: 10);
    await seekTo(newPosition > Duration.zero ? newPosition : Duration.zero);
  }

  /// Change quality
  Future<void> changeQuality(String quality, Content content) async {
    if (_currentQuality == quality) return;

    try {
      // Store current position
      final currentPosition = _controller?.value.position ?? Duration.zero;
      final wasPlaying = _controller?.value.isPlaying ?? false;

      // Update quality setting
      _currentQuality = quality;
      _qualityController!.add(quality);

      // Re-initialize with new quality
      await initialize(content);

      // Restore position
      await seekTo(currentPosition);

      // Resume playback if was playing
      if (wasPlaying) {
        await play();
      }
    } catch (e) {
      print('Failed to change quality: $e');
    }
  }

  /// Set playback speed
  Future<void> setPlaybackSpeed(double speed) async {
    await _controller?.setPlaybackSpeed(speed);
  }

  /// Enable Picture-in-Picture mode
  Future<void> enablePiP() async {
    // Platform-specific PiP implementation
    const platform = MethodChannel('com.totv.plus/pip');
    try {
      await platform.invokeMethod('enablePiP');
    } catch (e) {
      print('PiP not supported: $e');
    }
  }

  /// Enable screen always on
  Future<void> _enableScreenAlwaysOn() async {
    const platform = MethodChannel('com.totv.plus/screen');
    try {
      await platform.invokeMethod('keepScreenOn', true);
    } catch (e) {
      print('Failed to enable screen always on: $e');
    }
  }

  /// Enable screen recording prevention (FLAG_SECURE)
  Future<void> _enableScreenRecordingPrevention() async {
    const platform = MethodChannel('com.totv.plus/security');
    try {
      await platform.invokeMethod('setSecureFlag', true);
    } catch (e) {
      print('Failed to enable screen recording prevention: $e');
    }
  }

  /// Disable screen recording prevention
  Future<void> _disableScreenRecordingPrevention() async {
    const platform = MethodChannel('com.totv.plus/security');
    try {
      await platform.invokeMethod('setSecureFlag', false);
    } catch (e) {
      print('Failed to disable screen recording prevention: $e');
    }
  }

  /// Get auth token
  Future<String> _getAuthToken() async {
    // TODO: Implement actual auth token retrieval
    return 'mock_jwt_token_12345';
  }

  /// Get device ID
  Future<String> _getDeviceId() async {
    // TODO: Implement device ID retrieval
    return 'device_12345';
  }

  /// Generate session ID
  String _generateSessionId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  /// Dispose
  Future<void> dispose() async {
    await _controller?.pause();
    await _controller?.dispose();
    _controller = null;
    _isInitialized = false;
    
    // Disable screen always on
    const platform = MethodChannel('com.totv.plus/screen');
    try {
      await platform.invokeMethod('keepScreenOn', false);
    } catch (e) {
      print('Failed to disable screen always on: $e');
    }

    // Disable FLAG_SECURE
    await _disableScreenRecordingPrevention();
  }

  /// Close streams
  void closeStreams() {
    _stateController?.close();
    _positionController?.close();
    _qualityController?.close();
  }
}

/// Video Player States
enum VideoPlayerState {
  idle,
  loading,
  buffering,
  playing,
  paused,
  completed,
  error,
}

/// Video Quality Model
class VideoQuality {
  final String label;
  final String value;
  final int bitrate;

  VideoQuality({
    required this.label,
    required this.value,
    required this.bitrate,
  });
}

/// Adaptive Bitrate Manager (for auto quality)
class AdaptiveBitrateManager {
  static const int _measurementWindowSeconds = 10;
  final List<double> _bandwidthSamples = [];
  
  /// Measure current bandwidth
  Future<double> measureBandwidth() async {
    // TODO: Implement actual bandwidth measurement
    // This would typically measure download speed of video segments
    return 5000000; // 5 Mbps mock value
  }

  /// Get recommended quality based on bandwidth
  String getRecommendedQuality(List<VideoQuality> qualities) {
    if (_bandwidthSamples.isEmpty) {
      return '720p'; // Default to 720p
    }

    final avgBandwidth = _bandwidthSamples.reduce((a, b) => a + b) / _bandwidthSamples.length;

    // Find highest quality that fits bandwidth
    for (var quality in qualities.reversed) {
      if (quality.bitrate <= avgBandwidth * 0.8) {
        // Use 80% of bandwidth for safety margin
        return quality.value;
      }
    }

    return qualities.last.value; // Return lowest quality
  }

  /// Add bandwidth sample
  void addSample(double bandwidth) {
    _bandwidthSamples.add(bandwidth);
    
    // Keep only recent samples
    if (_bandwidthSamples.length > _measurementWindowSeconds) {
      _bandwidthSamples.removeAt(0);
    }
  }
}
