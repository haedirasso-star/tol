import 'package:flutter/material.dart';
import 'package:better_player/better_player.dart';
import 'package:flutter/services.dart';

class VideoPlayerPage extends StatefulWidget {
  final String videoUrl;
  final String title;

  const VideoPlayerPage({super.key, required this.videoUrl, required this.title});

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  late BetterPlayerController _betterPlayerController;

  @override
  void initState() {
    super.initState();
    
    // إعدادات المشغل لتناسب الأفلام والمباريات
    BetterPlayerConfiguration betterPlayerConfiguration = BetterPlayerConfiguration(
      aspectRatio: 16 / 9,
      fit: BoxFit.contain,
      autoPlay: true,
      looping: false,
      fullScreenByDefault: true, // التشغيل بوضع ملء الشاشة فوراً
      deviceOrientationsAfterFullScreen: [DeviceOrientation.portraitUp],
      
      // تخصيص الألوان لتناسب هوية TOL الذهبية
      controlsConfiguration: BetterPlayerControlsConfiguration(
        progressBarPlayedColor: const Color(0xFFFFD700),
        progressBarHandleColor: const Color(0xFFFFD700),
        loadingColor: const Color(0xFFFFD700),
        controlBarColor: Colors.black.withOpacity(0.7),
      ),
    );

    _betterPlayerController = BetterPlayerController(betterPlayerConfiguration);
    
    // ربط الرابط المستخرج من السيرفر بالمشغل
    BetterPlayerDataSource dataSource = BetterPlayerDataSource(
      BetterPlayerDataSourceType.network,
      widget.videoUrl,
      headers: {
        "User-Agent": "Mozilla/5.0",
        "Referer": "https://vidsrc.to/",
      }
    );
    
    _betterPlayerController.setupDataSource(dataSource);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(widget.title, style: const TextStyle(color: Color(0xFFFFD700))),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: BetterPlayer(controller: _betterPlayerController),
      ),
    );
  }

  @override
  void dispose() {
    _betterPlayerController.dispose();
    super.dispose();
  }
}
