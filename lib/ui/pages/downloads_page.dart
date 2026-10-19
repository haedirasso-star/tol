part of '../../main.dart';

// ════════════════════════════════════════════════════════════════════
//  قائمة التنزيلات + مشغّل بلا إنترنت
// ════════════════════════════════════════════════════════════════════
class DownloadsPage extends StatefulWidget {
  const DownloadsPage({super.key});
  @override State<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends State<DownloadsPage> {
  @override
  void initState() { super.initState(); Downloads.ensureLoaded(); }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black, elevation: 0, centerTitle: false,
        leading: IconButton(icon: const Icon(Icons.arrow_forward_ios_rounded, size: 18, color: Colors.white),
            onPressed: () => Navigator.pop(context)),
        title: Text('قائمة التنزيلات', style: T.cairo(s: FS.lg, w: FontWeight.w800, c: Colors.white)),
      ),
      body: ValueListenableBuilder<int>(
        valueListenable: Downloads.rev,
        builder: (_, __, ___) {
          final list = Downloads.all;
          if (list.isEmpty) {
            return Center(child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.download_for_offline_outlined, color: Colors.white24, size: 64),
                const SizedBox(height: 14),
                Text('لا توجد تنزيلات بعد', style: T.cairo(s: FS.lg, w: FontWeight.w800, c: Colors.white)),
                const SizedBox(height: 6),
                Text('اضغط زر التنزيل في صفحة أي فيلم أو حلقة لتشاهدها بلا إنترنت',
                    textAlign: TextAlign.center, style: T.cairo(s: FS.sm, c: Colors.white60, h: 1.6)),
              ]),
            ));
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(color: Color(0xFF1E1E22), height: 20),
            itemBuilder: (_, i) => _row(list[i]),
          );
        },
      ),
    ),
  );

  Widget _row(DlItem it) {
    final done = it.status == DlStatus.done;
    String sub;
    switch (it.status) {
      case DlStatus.done:    sub = Downloads.fmtSize(it.total); break;
      case DlStatus.running: sub = '${(it.progress * 100).toStringAsFixed(0)}% • ${Downloads.fmtSize(it.received)}'; break;
      case DlStatus.queued:  sub = 'في الانتظار…'; break;
      case DlStatus.paused:  sub = 'متوقف • اضغط للاستئناف'; break;
      case DlStatus.failed:  sub = 'فشل التنزيل • اضغط لإعادة المحاولة'; break;
    }
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        if (done) {
          Navigator.push(context, _fade(OfflinePlayerPage(path: it.path, title: it.title)));
        } else if (it.status == DlStatus.running || it.status == DlStatus.queued) {
          Downloads.pause(it.id);
        } else {
          Downloads.resume(it.id);
        }
      },
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(width: 120, height: 68, child: Stack(fit: StackFit.expand, children: [
            it.poster.isNotEmpty
                ? CachedNetworkImage(imageUrl: _imgUrl(it.poster), fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => const ColoredBox(color: Color(0xFF18181C)))
                : const ColoredBox(color: Color(0xFF18181C)),
            if (done) const Center(child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 30)),
            if (!done)
              Positioned(left: 0, right: 0, bottom: 0,
                child: LinearProgressIndicator(value: it.progress, minHeight: 3,
                    color: C.gold, backgroundColor: Colors.black54)),
          ])),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (it.seriesName.isNotEmpty)
            Text(it.seriesName, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: T.cairo(s: FS.xs, c: Colors.white54, w: FontWeight.w700)),
          Text(it.title, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: T.cairo(s: FS.md, w: FontWeight.w800, c: Colors.white)),
          const SizedBox(height: 3),
          Text(sub, style: T.cairo(s: FS.xs, c: done ? Colors.white60 : C.gold, w: FontWeight.w600)),
        ])),
        IconButton(
          icon: const Icon(Icons.delete_outline_rounded, color: Colors.white54),
          onPressed: () async {
            final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
              backgroundColor: const Color(0xFF16161A),
              title: Text('حذف التنزيل؟', style: T.cairo(s: FS.lg, w: FontWeight.w800)),
              content: Text(it.title, style: T.cairo(s: FS.sm, c: Colors.white70)),
              actions: [
                TextButton(onPressed: () => Navigator.pop(c, false),
                    child: Text('إلغاء', style: T.cairo(s: FS.md, c: Colors.white60))),
                TextButton(onPressed: () => Navigator.pop(c, true),
                    child: Text('حذف', style: T.cairo(s: FS.md, c: Colors.redAccent, w: FontWeight.w800))),
              ]));
            if (ok == true) Downloads.remove(it.id);
          },
        ),
      ]),
    );
  }
}

/// مشغّل بسيط للملفات المنزّلة (يعمل بلا إنترنت)
class OfflinePlayerPage extends StatefulWidget {
  final String path, title;
  const OfflinePlayerPage({super.key, required this.path, required this.title});
  @override State<OfflinePlayerPage> createState() => _OfflinePlayerPageState();
}

class _OfflinePlayerPageState extends State<OfflinePlayerPage> {
  late final VideoPlayerController _vc = VideoPlayerController.file(io.File(widget.path));
  bool _ui = true, _ready = false, _err = false;
  Timer? _hide;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WakelockPlus.enable();
    _vc.initialize().then((_) {
      if (!mounted) return;
      final resume = WatchHistory.getPositionSecs('dl_${widget.path.hashCode}');
      if (resume > 10) _vc.seekTo(Duration(seconds: resume));
      _vc.play();
      setState(() => _ready = true);
      _autoHide();
    }).catchError((_) { if (mounted) setState(() => _err = true); });
    _vc.addListener(() { if (mounted) setState(() {}); });
  }

  void _autoHide() {
    _hide?.cancel();
    _hide = Timer(const Duration(seconds: 3), () { if (mounted) setState(() => _ui = false); });
  }

  @override
  void dispose() {
    if (_ready) {
      WatchHistory.saveProgress('dl_${widget.path.hashCode}',
          _vc.value.position.inSeconds, _vc.value.duration.inSeconds);
    }
    _hide?.cancel();
    _vc.dispose();
    WakelockPlus.disable();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  String _t(Duration d) {
    final h = d.inHours, m = d.inMinutes % 60, s = d.inSeconds % 60;
    final mm = m.toString().padLeft(2, '0'), ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final v = _vc.value;
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () { setState(() => _ui = !_ui); if (_ui) _autoHide(); },
        child: Stack(children: [
          Center(child: _err
              ? Text('تعذّر تشغيل الملف', style: T.cairo(s: FS.md, c: Colors.white70))
              : _ready
                  ? AspectRatio(aspectRatio: v.aspectRatio, child: VideoPlayer(_vc))
                  : const CircularProgressIndicator(color: C.gold)),
          if (_ui) ...[
            Positioned(top: 12, left: 12, right: 12, child: Row(children: [
              IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(context)),
              Expanded(child: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: T.cairo(s: FS.md, w: FontWeight.w800, c: Colors.white))),
            ])),
            if (_ready) Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(iconSize: 40, color: Colors.white, icon: const Icon(Icons.replay_10_rounded),
                  onPressed: () { _vc.seekTo(v.position - const Duration(seconds: 10)); _autoHide(); }),
              const SizedBox(width: 24),
              IconButton(iconSize: 64, color: Colors.white,
                  icon: Icon(v.isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded),
                  onPressed: () { v.isPlaying ? _vc.pause() : _vc.play(); _autoHide(); }),
              const SizedBox(width: 24),
              IconButton(iconSize: 40, color: Colors.white, icon: const Icon(Icons.forward_10_rounded),
                  onPressed: () { _vc.seekTo(v.position + const Duration(seconds: 10)); _autoHide(); }),
            ])),
            if (_ready) Positioned(left: 20, right: 20, bottom: 18, child: Row(children: [
              Text(_t(v.position), style: const TextStyle(color: Colors.white, fontSize: 12)),
              Expanded(child: Slider(
                value: v.position.inMilliseconds.clamp(0, v.duration.inMilliseconds).toDouble(),
                max: math.max(1, v.duration.inMilliseconds).toDouble(),
                activeColor: C.gold, inactiveColor: Colors.white24,
                onChanged: (x) { _vc.seekTo(Duration(milliseconds: x.round())); _autoHide(); },
              )),
              Text(_t(v.duration), style: const TextStyle(color: Colors.white, fontSize: 12)),
            ])),
          ],
        ]),
      ),
    );
  }
}
