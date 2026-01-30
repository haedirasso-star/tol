import 'package:url_launcher/url_launcher.dart';
import 'constants.dart';

class SupportLogic {
  // فتح الواتساب للمراسلة مباشرة
  static Future<void> contactWhatsApp() async {
    final Uri url = Uri.parse(AppAssets.whatsappSupport);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw 'لا يمكن فتح الواتساب حالياً';
    }
  }

  // فتح قناة التليجرام للاشتراك
  static Future<void> openTelegram() async {
    final Uri url = Uri.parse(AppAssets.telegramChannel);
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }
}
