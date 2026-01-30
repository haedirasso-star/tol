import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ForceUpdateDialog extends StatelessWidget {
  final String updateUrl;
  final String message;

  const ForceUpdateDialog({super.key, required this.updateUrl, required this.message});

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // منع المستخدم من إغلاق النافذة بالرجوع
      child: AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("تحديث إجباري 🚀", style: TextStyle(color: Color(0xFFFFD700))),
        content: Text(message, style: const TextStyle(color: Colors.white)),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFD700)),
            onPressed: () => launchUrl(Uri.parse(updateUrl)),
            child: const Text("تحديث الآن", style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }
}
