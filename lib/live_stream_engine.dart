import 'package:flutter/material.dart';
import 'package:better_player/better_player.dart'; // المكتبة الأقوى للبث المباشر
import 'constants.dart';

class LiveStreamEngine extends StatefulWidget {
  final String streamUrl;
  final String channelName;

  const LiveStreamEngine({super.key, required this.streamUrl, required this.channelName});

  @override
  State<LiveStreamEngine> createState() => _LiveStreamEngineState();
}

class _LiveStreamEngineState extends State<LiveStreamEngine> {
  late BetterPlayerController _betterPlayerController;

  @override
  void initState() {
    super.initState();
    // إعدادات البث الاحترافية: دعم الـ Cache ومنع تقطيع الفيديو
    BetterPlayerConfiguration betterPlayerConfiguration = BetterPlayerConfiguration(
      aspectRatio: 16 / 9,
      fit: BoxFit.contain,
      autoPlay: true,
      looping: false,
      deviceOrientationsAfterFullScreen: [DeviceOrientation.portraitUp],
      // نظام الألوان الخاص بك (الذهبي والأسود) داخل المشغل
      controlsConfiguration: BetterPlayerControlsConfiguration(
        controlBarColor: Colors.black.withOpacity(0.7),
        progressBarPlayedColor: Color(0xFFFFD700),
        progressBarHandleColor: Color(0xFFFFD700),
        loadingColor: Color(0xFFFFD700),
        enableSkips: false, // لضمان مشاهدة البث الحي دون تقديم
      ),
    );

    BetterPlayerDataSource dataSource = BetterPlayerDataSource(
      BetterPlayerDataSourceType.network,
      widget.streamUrl,
      // إضافة مفاتيح السيرفر (Headers) لتجاوز حماية المواقع الرسمية
      headers: {
        "User-Agent": "Mozilla/5.0",
        "Referer": "https://vidsrc.to/",
      },
    );

    _betterPlayerController = BetterPlayerController(betterPlayerConfiguration);
    _betterPlayerController.setupDataSource(dataSource);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.channelName, style: TextStyle(color: Color(0xFFFFD700))),
        backgroundColor: Colors.transparent,
      ),
      body: BetterPlayer(controller: _betterPlayerController),
    );
  }

  @override
  void dispose() {
    _betterPlayerController.dispose();
    super.dispose();
  }
}
