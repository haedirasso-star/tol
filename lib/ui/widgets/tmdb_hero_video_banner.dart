part of '../../main.dart';

// ════════════════════════════════════════════════════════════════════════
//  TOTV+ — أدوات الواجهة الرئيسية (الإعلانات الترويجية بالفيديو أُزيلت في 3.0)
//  ──────────────────────────────────────────────────────────────────────
//  ★ أُزيل مشغّل YouTube (WebView) كلياً: كان يجعل اللمس والتمرير ثقيلاً.
//    بقيت هنا متغيّرات التبويب ومراقب الصفحات، وجلب «الرائج» من TMDB (صور فقط).
// ════════════════════════════════════════════════════════════════════════

/// مراقب الصفحات — يوقف الإعلان عند فتح صفحة فوقه (مثل المشغّل أو التفاصيل)
final RouteObserver<ModalRoute<void>> kRouteObserver = RouteObserver<ModalRoute<void>>();

/// التبويب الظاهر حالياً في الواجهة الرئيسية (0 = الرئيسية)
final ValueNotifier<int> kShellTab = ValueNotifier<int>(0);

/// كتم/صوت مشترك — اختيار المستخدم يبقى بين الشرائح (يبدأ صامتاً دائماً)
final ValueNotifier<bool> kTrailerMuted = ValueNotifier<bool>(true);

// ════════════════════════════════════════════════════════════════════════
//  1) خدمة الإعلانات من TMDB
// ════════════════════════════════════════════════════════════════════════
enum TrailerKind { youtube, mp4 }

class TrailerSource {
  final TrailerKind kind;
  final String key;   // YouTube video id
  final String url;   // رابط MP4 مباشر
  const TrailerSource.youtube(this.key) : kind = TrailerKind.youtube, url = '';
  const TrailerSource.mp4(this.url)     : kind = TrailerKind.mp4,     key = '';
  String get id => kind == TrailerKind.youtube ? 'yt:$key' : 'mp4:$url';
}

class TmdbBannerItem {
  final int id;
  final bool isTv;
  final String title, overview, backdrop, year;
  final double rating;
  final List<String> genres;
  const TmdbBannerItem({required this.id, required this.isTv, required this.title,
      required this.overview, required this.backdrop, required this.year,
      required this.rating, required this.genres});
}

class TmdbTrailerService {
  TmdbTrailerService._();
  static const _base = 'https://api.themoviedb.org/3';

  // ★ 3.0: أُزيل مشغّل YouTube من التطبيق كلياً لأنه كان سبب ثقل اللمس والتمرير.
  //   الدوال باقية بنفس الشكل حتى لا تتغيّر بقية الصفحات، لكنها لا تتصل بأي شيء.
  static TrailerSource? alternative(TrailerSource failed) => null;
  static Future<TrailerSource?> byId(int tmdbId, {bool isTv = false}) async => null;
  static Future<TrailerSource?> byTitle(String title, {bool isTv = false, int? tmdbId}) async => null;

  /// الرائج هذا الأسبوع — لبانر لا يعتمد على سيرفر المستخدم.
  static Future<List<TmdbBannerItem>> trending({bool isTv = false, int take = 8}) async {
    try {
      final r = await DioClient.tmdb.get(
        '$_base/trending/${isTv ? 'tv' : 'movie'}/week',
        queryParameters: {'api_key': TMDB._key, 'language': 'ar'},
      ).timeout(const Duration(seconds: 8));
      const g = {28:'أكشن',12:'مغامرة',16:'أنيميشن',35:'كوميدي',80:'جريمة',18:'دراما',
        14:'فانتازيا',27:'رعب',9648:'غموض',10749:'رومانسي',878:'خيال علمي',53:'إثارة',
        10759:'أكشن ومغامرة',10765:'خيال علمي',10768:'حرب',37:'غربي',10751:'عائلي'};
      return ((r.data['results'] as List?) ?? const [])
          .whereType<Map>()
          .where((m) => (m['backdrop_path'] ?? '').toString().isNotEmpty)
          .take(take)
          .map((m) => TmdbBannerItem(
                id: (m['id'] as num).toInt(),
                isTv: isTv,
                title: (m['title'] ?? m['name'] ?? '').toString(),
                overview: (m['overview'] ?? '').toString(),
                backdrop: 'https://image.tmdb.org/t/p/w1280${m['backdrop_path']}',
                year: ((m['release_date'] ?? m['first_air_date'] ?? '').toString()).split('-').first,
                rating: ((m['vote_average'] ?? 0) as num).toDouble(),
                genres: ((m['genre_ids'] as List?) ?? const [])
                    .map((x) => g[x] ?? '').where((x) => x.isNotEmpty).take(2).cast<String>().toList(),
              ))
          .toList();
    } catch (e) { debugPrint('[trailer] trending: $e'); return const []; }
  }
}

/// إعلانات الفيديو موقوفة نهائياً (لا WebView في التطبيق)
class TrailerPolicy {
  TrailerPolicy._();
  static Future<void> init() async {}
  static bool get enabled => false;
}

/// بقي للتوافق فقط — لا يرسم شيئاً
class HeroTrailerPlayer extends StatelessWidget {
  final TrailerSource source;
  final bool active;
  final VoidCallback? onReady, onFailed, onEnded;
  const HeroTrailerPlayer({super.key, required this.source, this.active = true,
      this.onReady, this.onFailed, this.onEnded});
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class TrailerMuteButton extends StatelessWidget {
  final double size;
  const TrailerMuteButton({super.key, this.size = 38});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: kTrailerMuted,
    builder: (_, muted, __) => Semantics(
      button: true,
      label: muted ? 'تشغيل الصوت' : 'كتم الصوت',
      child: GestureDetector(
        onTap: () { Sound.nav(); kTrailerMuted.value = !muted; },
        child: ClipOval(child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: size, height: size,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.35),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.55), width: 1.2)),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
              child: Icon(muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                  key: ValueKey(muted), color: Colors.white, size: size * 0.5),
            ),
          ),
        )),
      ),
    ),
  );
}

/// بقيت للتوافق فقط: كانت توقظ الصفحات عند كل تبديل تبويب لتشغيل/إيقاف الفيديو.
/// بعد إزالة الفيديو لا تستمع لشيء ولا تعيد بناء أي صفحة.
class TrailerGate extends ChangeNotifier {
  final int tab;
  TrailerGate({this.tab = 0});
  bool get active => true;
  void attach(BuildContext context) {}
}
