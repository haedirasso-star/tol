import 'package:flutter/material.dart';
import 'package:better_player/better_player.dart';
import '../../constants.dart';

class SportsPlayer extends StatefulWidget {
  final String streamUrl;
  final String channelName;

  const SportsPlayer({super.key, required this.streamUrl, required this.channelName});

  @override
  State<SportsPlayer> createState() => _SportsPlayerState();
}

class _SportsPlayerState extends State<SportsPlayer> {
  late BetterPlayerController _controller;

  @override
  void initState() {
    super.initState();
    
    // إعدادات المشغل الاحترافية
    BetterPlayerConfiguration config = BetterPlayerConfiguration(
      aspectRatio: 16 / 9,
      fit: BoxFit.contain,
      autoPlay: true,
      allowedScreenSleep: false, // منع انطفاء الشاشة أثناء المباراة
      deviceOrientationsAfterFullScreen: [DeviceOrientation.portraitUp],
      
      // تخصيص الواجهة باللون الذهبي الخاص بك
      controlsConfiguration: BetterPlayerControlsConfiguration(
        controlBarColor: Colors.black87,
        progressBarPlayedColor: const Color(0xFFFFD700),
        loadingColor: const Color(0xFFFFD700),
        enableAudioTracks: true, // تغيير المعلق إن وجد
        enableQualities: true,   // تغيير الجودة (1080p, 720p, etc)
      ),
    );

    _controller = BetterPlayerController(config);
    
    // ربط رابط البث (M3U8) مع حماية ضد السرقة (Headers)
    BetterPlayerDataSource dataSource = BetterPlayerDataSource(
      BetterPlayerDataSourceType.network,
      widget.streamUrl,
      headers: {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)",
        "Referer": "https://vidsrc.to/",
      },
    );

    _controller.setupDataSource(dataSource);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(widget.channelName, style: const TextStyle(color: Color(0xFFFFD700))),
      ),
      body: Center(
        child: BetterPlayer(controller: _controller),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
