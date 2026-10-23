part of '../main.dart';

// ════════════════════════════════════════════════════════════════════
//  🔴 TOTV Live — قناة البث المباشر الخاصة بالتطبيق
//  ──────────────────────────────────────────────────────────────────
//  • تُدار بالكامل من «استوديو البث» في تطبيق الإدارة
//  • الجدول: live_channel في Supabase (05_live_channel.sql) — بلا أي قراءة Firebase
//      visible     bool    القناة ظاهرة للمستخدمين
//      on_air      bool    البث يعمل الآن
//      name        string  اسم القناة (افتراضي TOTV Live)
//      title       string  عنوان البث الحالي
//      subtitle    string  وصف قصير
//      poster      string  رابط البوستر https
//      url         string  رابط البث الرئيسي (m3u8 / mp4 / ts …)
//      backup_url  string  رابط احتياطي (اختياري)
//      started_at  timestamp
//  • التشغيل بمشغّلنا الاحترافي نفسه (PlayerPage) — بلا WebView
// ════════════════════════════════════════════════════════════════════
class LiveChannel {
  final bool visible, onAir;
  final String name, title, subtitle, poster, url, backup;
  final DateTime? startedAt;
  const LiveChannel({this.visible = false, this.onAir = false, this.name = 'TOTV Live', this.title = '',
      this.subtitle = '', this.poster = '', this.url = '', this.backup = '', this.startedAt});

  static const off = LiveChannel();

  factory LiveChannel.fromMap(Map<String, dynamic> d) {
    String s(String k) => (d[k] ?? '').toString().trim();
    final st = d['started_at'];
    final stIso = st is String ? DateTime.tryParse(st)?.toLocal() : null;
    return LiveChannel(
      visible: d['visible'] == true,
      onAir: d['on_air'] == true,
      name: s('name').isEmpty ? 'TOTV Live' : s('name'),
      title: s('title'),
      subtitle: s('subtitle'),
      poster: s('poster'),
      url: s('url'),
      backup: s('backup_url'),
      startedAt: st is Timestamp ? st.toDate() : stIso,
    );
  }

  /// روابط التشغيل بالترتيب (الرئيسي ثم الاحتياطي) — المشغّل ينتقل تلقائياً عند الفشل
  List<String> get urls => [url, backup].where((u) => u.startsWith('http')).toSet().toList();
  bool get playable => onAir && urls.isNotEmpty;
}

class TotvLive {
  TotvLive._();
  static final state = ValueNotifier<LiveChannel>(LiveChannel.off);
  static const _kCache = 'totv_live_v2';
  static bool _started = false, _busy = false;
  static DateTime? _at;
  static final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 8),
    responseType: ResponseType.plain,
  ));

  // ★ الحالة تُقرأ من Supabase (جدول live_channel) وليس Firestore:
  //   • لا قراءات Firebase إطلاقاً — افتح وأغلق القناة بلا حدود
  //   • التحديث الفوري: الإدارة ترسل رسالة FCM صامتة (live_sync) ⇐ كل تطبيق مفتوح يجلب الحالة
  //   • وعند فتح التطبيق أو الرجوع إليه (بحد أدنى دقيقة بين جلبتين)
  static void ensure() {
    if (_started) return;
    _started = true;
    SPref.i.then((p) {
      final raw = p.getString(_kCache);
      if (raw != null && state.value == LiveChannel.off) {
        try { state.value = LiveChannel.fromMap(Map<String, dynamic>.from(jsonDecode(raw) as Map)); } catch (_) {}
      }
    });
    WidgetsBinding.instance.addObserver(_Life());
    refresh(force: true);
  }

  static Future<void> refresh({bool force = false}) async {
    if (_busy || !kSupaReady) return;
    if (!force && _at != null && DateTime.now().difference(_at!).inSeconds < 60) return;
    _busy = true;
    try {
      final r = await _dio.get('$kSupaUrl/rest/v1/live_channel',
          queryParameters: {'id': 'eq.1', 'select': '*'},
          options: Options(headers: {'apikey': kSupaPublicKey,
            if (kSupaPublicKey.startsWith('eyJ')) 'Authorization': 'Bearer $kSupaPublicKey'}));
      final list = jsonDecode('${r.data}') as List;
      final row = list.isEmpty ? <String, dynamic>{} : Map<String, dynamic>.from(list.first as Map);
      _at = DateTime.now();
      state.value = LiveChannel.fromMap(row);
      (await SPref.i).setString(_kCache, jsonEncode(row));
    } catch (e) { debugPrint('[live] $e'); }
    _busy = false;
  }

  /// فتح القناة في مشغّلنا
  static void open([BuildContext? ctx]) {
    final c = state.value;
    final context = ctx ?? rootNavKey.currentContext;
    if (context == null) return;
    if (!c.playable) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
        content: Text(c.visible ? 'البث لم يبدأ بعد — سيصلك إشعار عند انطلاقه 🔔' : 'القناة غير متاحة الآن',
            style: T.cairo(s: FS.md)),
        behavior: SnackBarBehavior.floating));
      return;
    }
    Sound.nav();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => PlayerPage(
      urls: c.urls,
      title: c.title.isEmpty ? c.name : '${c.name} — ${c.title}',
      isLive: true,
    )));
  }
}

// ════════════════════════════════════════════════════════════════════
//  بطاقة القناة — تظهر في الرئيسية وقسم الرياضة حين تكون «ظاهرة»
// ════════════════════════════════════════════════════════════════════
class TotvLiveCard extends StatefulWidget {
  final EdgeInsets margin;
  const TotvLiveCard({super.key, this.margin = const EdgeInsets.fromLTRB(16, 14, 16, 4)});
  @override State<TotvLiveCard> createState() => _TotvLiveCardState();
}

class _TotvLiveCardState extends State<TotvLiveCard> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void initState() { super.initState(); TotvLive.ensure(); TotvLive.state.addListener(_sync); _sync(); }
  @override
  void dispose() { TotvLive.state.removeListener(_sync); _pulse.dispose(); super.dispose(); }

  // النبض يعمل فقط أثناء البث (لا حركة دائمة تستهلك المعالج)
  void _sync() {
    final on = TotvLive.state.value.onAir;
    if (on && !_pulse.isAnimating) _pulse.repeat(reverse: true);
    if (!on && _pulse.isAnimating) _pulse.stop();
    if (mounted) setState(() {});
  }

  String _since(DateTime? t) {
    if (t == null) return '';
    final m = DateTime.now().difference(t).inMinutes;
    if (m < 1) return 'بدأ الآن';
    if (m < 60) return 'منذ $m دقيقة';
    return 'منذ ${m ~/ 60} س ${m % 60} د';
  }

  @override
  Widget build(BuildContext context) {
    final c = TotvLive.state.value;
    if (!c.visible) return const SizedBox.shrink();
    final w = MediaQuery.of(context).size.width - widget.margin.horizontal;
    final dpr = MediaQuery.of(context).devicePixelRatio;
    return Padding(
      padding: widget.margin,
      child: GestureDetector(
        onTap: () => TotvLive.open(context),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: 16 / 8,
            child: Stack(fit: StackFit.expand, children: [
              if (c.poster.isNotEmpty)
                CachedNetworkImage(imageUrl: c.poster, fit: BoxFit.cover,
                    memCacheWidth: (w * dpr).round().clamp(400, 1400),
                    errorWidget: (_, __, ___) => const ColoredBox(color: Color(0xFF16161A)))
              else
                const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
                    begin: Alignment.topRight, end: Alignment.bottomLeft,
                    colors: [Color(0xFF3A0A0A), Color(0xFF0D0D10)]))),
              const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  stops: [0, .45, 1],
                  colors: [Color(0x66000000), Color(0x00000000), Color(0xE6000000)]))),
              // الشارة: مباشر / متوقف
              PositionedDirectional(top: 12, start: 12, child: Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: c.onAir ? const Color(0xFFE50914) : const Color(0xCC1E1E22),
                    borderRadius: BorderRadius.circular(6)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (c.onAir) FadeTransition(
                      opacity: Tween(begin: .25, end: 1.0).animate(_pulse),
                      child: Container(width: 7, height: 7,
                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle))),
                    if (c.onAir) const SizedBox(width: 6),
                    Text(c.onAir ? 'مباشر' : 'البث متوقف',
                        style: T.cairo(s: FS.sm, w: FontWeight.w800, c: Colors.white)),
                  ]),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0x99000000), borderRadius: BorderRadius.circular(6)),
                  child: Text(c.name, style: T.cairo(s: FS.sm, w: FontWeight.w800, c: C.gold)),
                ),
              ])),
              // العنوان + زر
              PositionedDirectional(start: 14, end: 14, bottom: 12, child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text(c.title.isEmpty ? c.name : c.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: T.cairo(s: FS.xl, w: FontWeight.w900, c: Colors.white, h: 1.25)),
                    if (c.subtitle.isNotEmpty || c.onAir)
                      Text([if (c.subtitle.isNotEmpty) c.subtitle, if (c.onAir) _since(c.startedAt)]
                              .where((x) => x.isNotEmpty).join('  •  '),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: T.cairo(s: FS.sm, w: FontWeight.w600, c: const Color(0xFFCFCFD4))),
                  ])),
                  const SizedBox(width: 10),
                  Container(
                    height: 40, padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                        color: c.onAir ? C.gold : const Color(0x33FFFFFF),
                        borderRadius: BorderRadius.circular(10)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(c.onAir ? Icons.play_arrow_rounded : Icons.notifications_active_rounded,
                          color: c.onAir ? Colors.black : Colors.white, size: 22),
                      const SizedBox(width: 4),
                      Text(c.onAir ? 'شاهد' : 'قريباً',
                          style: T.cairo(s: FS.md, w: FontWeight.w900, c: c.onAir ? Colors.black : Colors.white)),
                    ]),
                  ),
                ],
              )),
            ]),
          ),
        ),
      ),
    );
  }
}

/// يجلب حالة القناة عند الرجوع للتطبيق
class _Life with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) TotvLive.refresh();
  }
}
