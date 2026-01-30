class StreamKeysManager {
  // مفاتيح السيرفرات المشفرة لتجاوز الحماية
  static Map<String, String> get headers => {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    'Referer': 'https://vidsrc.to/',
    'Origin': 'https://vidsrc.to/',
  };

  // روابط البث المباشر للقنوات الرياضية (beIN & Premier League)
  // ملاحظة: هذه الروابط تحتاج لتحديث دوري من السيرفر الخاص بك
  static const String sportsServerKey = "https://your-private-api.com/get-live-sports";

  // دالة جلب رابط الفيلم بناءً على الـ ID الخاص به من TMDB
  static String getMovieLink(String tmdbId) {
    return "https://vidsrc.to/embed/movie/$tmdbId";
  }
}
