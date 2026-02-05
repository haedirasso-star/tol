import 'dart:async';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../../domain/entities/content.dart';
import '../config/api_config.dart';

class VideoPlayerService {
  VideoPlayerController? _controller;
  StreamController<VideoPlayerState>? _stateController;
  StreamController<Duration>? _positionController;
  StreamController<String>? _qualityController;

  String _currentQuality = 'auto';
  bool _isInitialized = false;

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

  Future<void> initialize(Content content) async {
    try {
      await _enableScreenAlwaysOn();
      await _enableScreenRecordingPrevention();
      await dispose();

      final streamingUrl = _selectStreamingUrl(content);

      if (streamingUrl.contains('.m3u8')) {
        _controller = VideoPlayerController.network(
          streamingUrl,
          videoPlayerOptions: const VideoPlayerOptions(
            mixWithOthers: false,
            allowBackgroundPlayback: false,
          ),
          httpHeaders: await _buildSecureHeaders(content),
        );
      } else {
        _controller = VideoPlayerController.network(
          streamingUrl,
          httpHeaders: await _buildSecureHeaders(content),
        );
      }

      _controller!.addListener(_handleControllerUpdate);

      await _controller!.initialize();
      _isInitialized = true;

      await _controller!.play();

      _startPositionTracking();

      _stateController!.add(VideoPlayerState.playing);
    } catch (e) {
      _stateController!.add(VideoPlayerState.error);
      throw Exception('Failed to initialize video player: $e');
    }
  }

  Future<Map<String, String>> _buildSecureHeaders(Content content) async {
    final token = await _getAuthToken();

    return {
      ...ApiConfig.mediaHeaders,
      'Authorization': 'Bearer $token',
      'X-Device-ID': await _getDeviceId(),
      'X-Content-ID': content.id,
      'X-Session-ID': _generateSessionId(),
    };
  }

  String _selectStreamingUrl(Content content) {
    if (_currentQuality == 'auto' || content.streamingUrls.length == 1) {
      return content.streamingUrls.first;
    }

    final qualityUrl = content.qualityOptions.isNotEmpty
        ? content.qualityOptions
            .where((q) => q.contains(_currentQuality))
            .firstOrNull
        : null;

    return qualityUrl ?? content.streamingUrls.first;
  }

  void _handleControllerUpdate() {
    if (_controller == null) return;

    if (_controller!.value.isPlaying) {
      _stateController!.add(VideoPlayerState.playing);
    } else if (_controller!.value.isBuffering) {
      _stateController!.add(VideoPlayerState.buffering);
    } else {
      _stateController!.add(VideoPlayerState.paused);
    }

    if (_controller!.value.hasError) {
      _stateController!.add(VideoPlayerState.error);
    }
  }

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

  Future<void> play() async {
    await _controller?.play();
  }

  Future<void> pause() async {
    await _controller?.pause();
  }

  Future<void> seekTo(Duration position) async {
    await _controller?.seekTo(position);
  }

  Future<void> seekForward() async {
    final currentPosition = _controller?.value.position ?? Duration.zero;
    final newPosition = currentPosition + const Duration(seconds: 10);
    await seekTo(newPosition);
  }

  Future<void> seekBackward() async {
    final currentPosition = _controller?.value.position ?? Duration.zero;
    final newPosition = currentPosition - const Duration(seconds: 10);
    await seekTo(newPosition > Duration.zero ? newPosition : Duration.zero);
  }

  Future<void> changeQuality(String quality, Content content) async {
    if (_currentQuality == quality) return;

    try {
      final currentPosition = _controller?.value.position ?? Duration.zero;
      final wasPlaying = _controller?.value.isPlaying ?? false;

      _currentQuality = quality;
      _qualityController!.add(quality);

      await initialize(content);

      await seekTo(currentPosition);

      if (wasPlaying) {
        await play();
      }
    } catch (e) {
      print('Failed to change quality: $e');
    }
  }

  Future<void> setPlaybackSpeed(double speed) async {
    await _controller?.setPlaybackSpeed(speed);
  }

  Future<void> enablePiP() async {
    const platform = MethodChannel('com.totv.plus/pip');
    try {
      await platform.invokeMethod('enablePiP');
    } catch (e) {
      print('PiP not supported: $e');
    }
  }

  Future<void> _enableScreenAlwaysOn() async {
    const platform = MethodChannel('com.totv.plus/screen');
    try {
      await platform.invokeMethod('keepScreenOn', true);
    } catch (e) {
      print('Failed to enable screen always on: $e');
    }
  }

  Future<void> _enableScreenRecordingPrevention() async {
    const platform = MethodChannel('com.totv.plus/security');
    try {
      await platform.invokeMethod('setSecureFlag', true);
    } catch (e) {
      print('Failed to enable screen recording prevention: $e');
    }
  }

  Future<void> _disableScreenRecordingPrevention() async {
    const platform = MethodChannel('com.totv.plus/security');
    try {
      await platform.invokeMethod('setSecureFlag', false);
    } catch (e) {
      print('Failed to disable screen recording prevention: $e');
    }
  }

  Future<String> _getAuthToken() async {
    return 'mock_jwt_token_12345';
  }

  Future<String> _getDeviceId() async {
    return 'device_12345';
  }

  String _generateSessionId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  Future<void> dispose() async {
    await _controller?.pause();
    await _controller?.dispose();
    _controller = null;
    _isInitialized = false;

    const platform = MethodChannel('com.totv.plus/screen');
    try {
      await platform.invokeMethod('keepScreenOn', false);
    } catch (e) {
      print('Failed to disable screen always on: $e');
    }

    await _disableScreenRecordingPrevention();
  }

  void closeStreams() {
    _stateController?.close();
    _positionController?.close();
    _qualityController?.close();
  }
}

enum VideoPlayerState {
  idle,
  loading,
  buffering,
  playing,
  paused,
  completed,
  error,
}

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

class AdaptiveBitrateManager {
  static const int _measurementWindowSeconds = 10;
  final List<double> _bandwidthSamples = [];

  Future<double> measureBandwidth() async {
    return 5000000;
  }

  String getRecommendedQuality(List<VideoQuality> qualities) {
    if (_bandwidthSamples.isEmpty) {
      return '720p';
    }

    final avgBandwidth =
        _bandwidthSamples.reduce((a, b) => a + b) / _bandwidthSamples.length;

    for (var quality in qualities.reversed) {
      if (quality.bitrate <= avgBandwidth * 0.8) {
        return quality.value;
      }
    }

    return qualities.last.value;
  }

  void addSample(double bandwidth) {
    _bandwidthSamples.add(bandwidth);

    if (_bandwidthSamples.length > _measurementWindowSeconds) {
      _bandwidthSamples.removeAt(0);
    }
  }
}
