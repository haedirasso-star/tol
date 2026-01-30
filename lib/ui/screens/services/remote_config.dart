import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart'; // مكتبة لمعرفة رقم نسخة التطبيق
import '../constants.dart';

class RemoteConfigService {
  // رابط ملف الإعدادات على سيرفرك (يمكنك رفعه على GitHub بصيغة JSON)
  static const String _configUrl = "https://raw.githubusercontent.com/O_2828/config/main/app_config.json";

  static Future<Map<String, dynamic>> checkUpdate() async {
    try {
      final response = await http.get(Uri.parse(_configUrl));
      if (response.statusCode == 200) {
        final config = json.decode(response.body);
        
        // الحصول على نسخة التطبيق الحالية المثبتة في هاتف المستخدم
        PackageInfo packageInfo = await PackageInfo.fromPlatform();
        String currentVersion = packageInfo.version;

        // مقارنة نسخة المستخدم بالنسخة المطلوبة في السيرفر
        if (config['min_version'] != currentVersion) {
          return {
            "needsUpdate": true,
            "updateUrl": config['update_url'],
            "message": config['update_message']
          };
        }
      }
    } catch (e) {
      print("خطأ في فحص التحديثات: $e");
    }
    return {"needsUpdate": false};
  }
}
