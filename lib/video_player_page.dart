import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart'; // ستحتاج لتحميل هذه المكتبة لاحقاً

class VideoPlayerPage extends StatelessWidget {
  final String videoUrl;
  final String title;

  VideoPlayerPage({required this.videoUrl, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.black,
      ),
      backgroundColor: Colors.black,
      body: WebView(
        initialUrl: videoUrl,
        javascriptMode: JavascriptMode.unrestricted,
        // هذا الجزء لمنع المواقع من فتح نوافذ منبثقة (Pop-ups)
        navigationDelegate: (NavigationRequest request) {
          if (request.url.contains("ads") || request.url.contains("googleads")) {
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ),
    );
  }
}
