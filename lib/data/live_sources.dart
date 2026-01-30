class LiveSources {
  // روابط بث متغيرة (تحتاج لتحديث عبر API الخاص بك لاحقاً)
  static Map<String, String> get channels => {
    "beIN Sports 1 HD": "https://raw.githubusercontent.com/iptv-org/iptv/master/streams/ar.m3u",
    "beIN Sports 2 HD": "https://example.com/live/stream2.m3u8",
    "SSC Sports": "https://example.com/live/ssc.m3u8",
  };

  // رابط الدعم الفني الخاص بك في حال تعطل الرابط
  static const String supportLink = "https://wa.me/9647714415816";
}
