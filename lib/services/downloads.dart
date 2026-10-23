part of '../main.dart';

// ════════════════════════════════════════════════════════════════════
//  Downloads — تنزيل الأفلام والحلقات للمشاهدة بلا إنترنت
//  • يحفظ داخل مجلد التطبيق (لا يحتاج صلاحية تخزين)
//  • استئناف التنزيل المتوقف (Range) + تنزيلان متزامنان كحد أقصى
//  • متاح للمشتركين فقط — الروابط تُبنى من حساب المشترك نفسه
// ════════════════════════════════════════════════════════════════════

enum DlStatus { queued, running, paused, done, failed }

class DlItem {
  final String id, title, poster, kind, url, ext;   // kind: movie | episode
  final String seriesName;
  DlStatus status;
  int received, total;
  String path;
  DlItem({required this.id, required this.title, required this.poster, required this.kind,
      required this.url, required this.ext, this.seriesName = '', this.status = DlStatus.queued,
      this.received = 0, this.total = 0, this.path = ''});

  double get progress => total > 0 ? (received / total).clamp(0.0, 1.0) : 0;

  Map<String, dynamic> toJson() => {
    'id': id, 'title': title, 'poster': poster, 'kind': kind, 'url': url, 'ext': ext,
    'series': seriesName, 'status': status.name, 'received': received, 'total': total, 'path': path,
  };
  factory DlItem.fromJson(Map j) => DlItem(
    id: '${j['id']}', title: '${j['title'] ?? ''}', poster: '${j['poster'] ?? ''}',
    kind: '${j['kind'] ?? 'movie'}', url: '${j['url'] ?? ''}', ext: '${j['ext'] ?? 'mp4'}',
    seriesName: '${j['series'] ?? ''}',
    status: DlStatus.values.firstWhere((s) => s.name == j['status'], orElse: () => DlStatus.paused),
    received: (j['received'] as num?)?.toInt() ?? 0, total: (j['total'] as num?)?.toInt() ?? 0,
    path: '${j['path'] ?? ''}',
  );
}

class Downloads {
  static final ValueNotifier<int> rev = ValueNotifier(0);
  static final Map<String, DlItem> _items = {};
  static final Map<String, CancelToken> _tokens = {};
  static bool _loaded = false;
  static const _k = 'downloads_v1';
  static const _maxParallel = 2;
  static DateTime _lastSave = DateTime.fromMillisecondsSinceEpoch(0);

  static final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(minutes: 5),
    followRedirects: true,
  ));

  /// الأحدث أولاً
  static List<DlItem> get all => _items.values.toList().reversed.toList();

  static DlItem? of(String id) => _items[id];

  static Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final raw = (await SPref.i).getString(_k);
      if (raw != null && raw.isNotEmpty) {
        final dir = await _dir();
        for (final e in (jsonDecode(raw) as List)) {
          final it = DlItem.fromJson(e as Map);
          // ★ iOS يغيّر مسار مجلد التطبيق مع كل تحديث ⇐ نعيد بناء المسار من اسم الملف
          if (it.path.isNotEmpty && !io.File(it.path).existsSync()) {
            final name = it.path.split('/').last;
            if (name.isNotEmpty && io.File('$dir/$name').existsSync()) it.path = '$dir/$name';
          }
          // ما كان يعمل عند إغلاق التطبيق ⇐ متوقف (يُستأنف بضغطة)
          if (it.status == DlStatus.running || it.status == DlStatus.queued) it.status = DlStatus.paused;
          if (it.status == DlStatus.done && !io.File(it.path).existsSync()) continue;
          _items[it.id] = it;
        }
      }
    } catch (e) { debugPrint('[downloads] load $e'); }
    rev.value++;
  }

  static Future<void> _save({bool force = false}) async {
    final now = DateTime.now();
    if (!force && now.difference(_lastSave).inSeconds < 3) return;
    _lastSave = now;
    try {
      (await SPref.i).setString(_k, jsonEncode(_items.values.map((e) => e.toJson()).toList()));
    } catch (_) {}
  }

  static Future<String> _dir() async {
    final base = await getApplicationDocumentsDirectory();
    final d = io.Directory('${base.path}/downloads');
    if (!d.existsSync()) d.createSync(recursive: true);
    return d.path;
  }

  /// يبدأ تنزيل فيلم (عنصر من السيرفر). يُرجع رسالة للمستخدم.
  static Future<String> addMovie(dynamic item) async {
    await ensureLoaded();
    final urls = Api.movieUrls(item);
    if (urls.isEmpty) return 'التنزيل متاح للمشتركين فقط';
    final id = 'm_${item['stream_id']}';
    final ext = (item['container_extension']?.toString() ?? 'mp4').replaceAll('.', '');
    return _add(DlItem(id: id, title: '${item['name'] ?? ''}',
        poster: _poster(item), kind: 'movie', url: urls.first, ext: ext));
  }

  /// يبدأ تنزيل حلقة.
  static Future<String> addEpisode(dynamic ep, {required String seriesName, String cover = ''}) async {
    await ensureLoaded();
    final urls = Api.episodeUrls(ep);
    if (urls.isEmpty) return 'التنزيل متاح للمشتركين فقط';
    final id = 'e_${ep['id']}';
    final ext = (ep['container_extension']?.toString() ?? 'mp4').replaceAll('.', '');
    final n = ep['episode_num']?.toString() ?? '';
    final t = ep['title']?.toString().isNotEmpty == true ? '${ep['title']}' : 'الحلقة $n';
    final img = ep['info']?['movie_image']?.toString() ?? '';
    return _add(DlItem(id: id, title: t, poster: img.isNotEmpty ? img : cover,
        kind: 'episode', url: urls.first, ext: ext, seriesName: seriesName));
  }

  static String _poster(dynamic item) {
    for (final k in ['stream_icon', 'cover', 'icon']) {
      final v = item[k]?.toString() ?? '';
      if (v.isNotEmpty) return v;
    }
    return '';
  }

  static Future<String> _add(DlItem it) async {
    final old = _items[it.id];
    if (old != null) {
      if (old.status == DlStatus.done) return 'تم تنزيله مسبقاً — تجده في قائمة التنزيلات';
      if (old.status == DlStatus.running || old.status == DlStatus.queued) return 'قيد التنزيل…';
      resume(it.id);
      return 'استُؤنف التنزيل';
    }
    it.path = '${await _dir()}/${it.id}.${it.ext}';
    _items[it.id] = it;
    rev.value++;
    _save(force: true);
    _pump();
    return 'بدأ التنزيل — تابعه من «المزيد ← قائمة التنزيلات»';
  }

  static void _pump() {
    final running = _items.values.where((e) => e.status == DlStatus.running).length;
    var slots = _maxParallel - running;
    for (final it in _items.values.where((e) => e.status == DlStatus.queued).toList()) {
      if (slots-- <= 0) break;
      _run(it);
    }
  }

  static Future<void> _run(DlItem it) async {
    it.status = DlStatus.running;
    rev.value++;
    final f = io.File(it.path);
    final have = f.existsSync() ? f.lengthSync() : 0;
    final token = CancelToken();
    _tokens[it.id] = token;
    try {
      await _dio.download(
        it.url, it.path,
        cancelToken: token,
        deleteOnError: false,
        fileAccessMode: have > 0 ? FileAccessMode.append : FileAccessMode.write,
        options: Options(headers: have > 0 ? {'range': 'bytes=$have-'} : null),
        onReceiveProgress: (r, t) {
          it.received = have + r;
          if (t > 0) it.total = have + t;
          rev.value++;
          _save();
        },
      );
      it.status = DlStatus.done;
      if (it.total == 0) it.total = it.received;
    } on DioException catch (e) {
      it.status = CancelToken.isCancel(e) ? DlStatus.paused : DlStatus.failed;
      // الخادم لا يدعم الاستئناف ⇐ نبدأ من الصفر في المحاولة القادمة
      if (e.response?.statusCode == 416) { try { f.deleteSync(); } catch (_) {} it.received = 0; }
      debugPrint('[downloads] ${it.id}: ${e.message}');
    } catch (e) {
      it.status = DlStatus.failed;
      debugPrint('[downloads] ${it.id}: $e');
    }
    _tokens.remove(it.id);
    rev.value++;
    _save(force: true);
    _pump();
  }

  static void pause(String id) => _tokens[id]?.cancel('pause');

  static void resume(String id) {
    final it = _items[id];
    if (it == null || it.status == DlStatus.running || it.status == DlStatus.done) return;
    it.status = DlStatus.queued;
    rev.value++;
    _pump();
  }

  static Future<void> remove(String id) async {
    _tokens[id]?.cancel('remove');
    final it = _items.remove(id);
    if (it != null) { try { io.File(it.path).deleteSync(); } catch (_) {} }
    rev.value++;
    _save(force: true);
  }

  static String fmtSize(int b) {
    if (b <= 0) return '';
    if (b < 1 << 20) return '${(b / 1024).toStringAsFixed(0)} KB';
    if (b < 1 << 30) return '${(b / (1 << 20)).toStringAsFixed(0)} MB';
    return '${(b / (1 << 30)).toStringAsFixed(2)} GB';
  }
}

/// زر تنزيل يعكس الحالة (تنزيل · نسبة · تم)
class DownloadButton extends StatelessWidget {
  final String dlId;
  final Future<String> Function() start;
  final double size;
  final Color color;
  const DownloadButton({super.key, required this.dlId, required this.start,
      this.size = 24, this.color = Colors.white});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
    valueListenable: Downloads.rev,
    builder: (_, __, ___) {
      final it = Downloads.of(dlId);
      Widget icon;
      if (it == null) {
        icon = Icon(Icons.download_rounded, size: size, color: color);
      } else if (it.status == DlStatus.done) {
        icon = Icon(Icons.download_done_rounded, size: size, color: C.gold);
      } else if (it.status == DlStatus.running || it.status == DlStatus.queued) {
        icon = SizedBox(width: size, height: size, child: Stack(alignment: Alignment.center, children: [
          CircularProgressIndicator(value: it.progress == 0 ? null : it.progress,
              strokeWidth: 2.2, color: C.gold, backgroundColor: Colors.white12),
          Icon(Icons.stop_rounded, size: size * 0.5, color: color),
        ]));
      } else {
        icon = Icon(Icons.download_for_offline_outlined, size: size, color: Colors.orangeAccent);
      }
      return InkResponse(
        radius: size,
        onTap: () async {
          Sound.hapticL();
          if (it != null && (it.status == DlStatus.running || it.status == DlStatus.queued)) {
            Downloads.pause(dlId); return;
          }
          if (it != null && it.status == DlStatus.done) {
            Navigator.push(context, _fade(const DownloadsPage())); return;
          }
          if (!_canPlay(context)) return;
          final msg = await start();
          if (!context.mounted) return;
          ScaffoldMessenger.maybeOf(context)
            ?..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xFF1C1C21),
              content: Text(msg, textDirection: TextDirection.rtl,
                  style: T.cairo(s: FS.sm, c: Colors.white, w: FontWeight.w600)),
            ));
        },
        child: Padding(padding: const EdgeInsets.all(4), child: icon),
      );
    },
  );
}
