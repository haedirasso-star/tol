import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../../domain/entities/content.dart';
import '../../core/services/video_player_service.dart';
import '../widgets/player_controls.dart';
import '../widgets/quality_selector.dart';
import '../widgets/subtitle_selector.dart';

class VideoPlayerPage extends StatefulWidget {
  final Content content;

  const VideoPlayerPage({Key? key, required this.content}) : super(key: key);

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  late VideoPlayerService _playerService;
  bool _showControls = true;
  bool _showQualitySelector = false;
  bool _showSubtitleSelector = false;

  @override
  void initState() {
    super.initState();
    _playerService = VideoPlayerService();
    _initializePlayer();
    _setupControlsTimer();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _playerService.dispose();
    _playerService.closeStreams();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);

    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );

    super.dispose();
  }

  Future<void> _initializePlayer() async {
    try {
      await _playerService.initialize(widget.content);
    } catch (e) {
      _showErrorDialog('فشل تحميل الفيديو: $e');
    }
  }

  void _setupControlsTimer() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });

    if (_showControls) {
      _setupControlsTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          children: [
            Center(
              child: _playerService.controller != null &&
                      _playerService.controller!.value.isInitialized
                  ? AspectRatio(
                      aspectRatio: _playerService.controller!.value.aspectRatio,
                      child: VideoPlayer(_playerService.controller!),
                    )
                  : const Center(
                      child: CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Color(0xFFFF6B00)),
                      ),
                    ),
            ),
            StreamBuilder<VideoPlayerState>(
              stream: _playerService.stateStream,
              builder: (context, snapshot) {
                if (snapshot.data == VideoPlayerState.buffering) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFFFF6B00)),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            if (_showControls)
              PlayerControls(
                controller: _playerService.controller,
                onPlayPause: () {
                  if (_playerService.controller!.value.isPlaying) {
                    _playerService.pause();
                  } else {
                    _playerService.play();
                  }
                },
                onSeekForward: _playerService.seekForward,
                onSeekBackward: _playerService.seekBackward,
                onQualityTap: () {
                  setState(() {
                    _showQualitySelector = !_showQualitySelector;
                    _showSubtitleSelector = false;
                  });
                },
                onSubtitleTap: () {
                  setState(() {
                    _showSubtitleSelector = !_showSubtitleSelector;
                    _showQualitySelector = false;
                  });
                },
                onPiP: _playerService.enablePiP,
                onBack: () => Navigator.pop(context),
                content: widget.content,
              ),
            if (_showQualitySelector)
              Positioned(
                right: 20,
                top: MediaQuery.of(context).size.height / 2 - 150,
                child: QualitySelector(
                  qualities: _playerService.availableQualities,
                  currentQuality: _playerService.currentQuality,
                  onQualitySelected: (quality) async {
                    await _playerService.changeQuality(quality, widget.content);
                    setState(() {
                      _showQualitySelector = false;
                    });
                  },
                ),
              ),
            if (_showSubtitleSelector)
              Positioned(
                right: 20,
                top: MediaQuery.of(context).size.height / 2 - 100,
                child: SubtitleSelector(
                  subtitles: widget.content.subtitleLanguages,
                  onSubtitleSelected: (String? subtitle) {
                    setState(() {
                      _showSubtitleSelector = false;
                    });
                  },
                ),
              ),
            if (_showControls)
              Positioned(
                top: 50,
                right: 20,
                child: StreamBuilder<String>(
                  stream: _playerService.qualityStream,
                  initialData: _playerService.currentQuality,
                  builder: (context, snapshot) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFFFF6B00),
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        snapshot.data ?? 'تلقائي',
                        style: const TextStyle(
                          color: Color(0xFFFF6B00),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'خطأ',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          message,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text(
              'موافق',
              style: TextStyle(color: Color(0xFFFF6B00)),
            ),
          ),
        ],
      ),
    );
  }
}
