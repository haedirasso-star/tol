import 'package:flutter/material.dart';

import '../../di.dart';
import '../../domain/entities/voice_room.dart';
import '../../domain/repositories/voice_room_repository.dart';
import 'voice_room_page.dart';

/// ═══════════════════════════════════════════════════════════════
///  قائمة الغرف ("المتجر").
///
///  ⚡ قراءة واحدة من Firestore عند الفتح + سحب للتحديث.
///     لا .snapshots() — العدّاد يكتبه Webhook من LiveKit، لا العميل.
/// ═══════════════════════════════════════════════════════════════
class RoomsListPage extends StatefulWidget {
  const RoomsListPage({super.key});

  @override
  State<RoomsListPage> createState() => _RoomsListPageState();
}

class _RoomsListPageState extends State<RoomsListPage> {
  late final VoiceRoomRepository _repo;
  List<VoiceRoomSummary> _rooms = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repo = VoiceRoomFactory.createRepository();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final res = await _repo.fetchRooms();
    if (!mounted) return;
    res.fold(
      (f) => setState(() {
        _error = f.message;
        _loading = false;
      }),
      (list) => setState(() {
        _rooms = list;
        _loading = false;
      }),
    );
  }

  Future<void> _create() async {
    final title = await showDialog<String>(
      context: context,
      builder: (_) => const _CreateRoomDialog(),
    );
    if (title == null || title.trim().length < 3) return;

    final res = await _repo.createRoom(title);
    if (!mounted) return;
    res.fold(
      (f) => _snack(f.message),
      (id) {
        _load();
        _open(id, title);
      },
    );
  }

  void _open(String id, String title) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => VoiceRoomPage(roomId: id, title: title),
    ));
  }

  void _snack(String m) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(m),
      backgroundColor: Colors.red.shade900,
      behavior: SnackBarBehavior.floating,
    ));

  @override
  void dispose() {
    _repo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1013),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E1013),
        elevation: 0,
        title: const Text('الغرف الصوتية',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white54),
            onPressed: _load,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        backgroundColor: const Color(0xFFFFC107),
        icon: const Icon(Icons.add_rounded, color: Colors.black),
        label: const Text('غرفة جديدة',
            style:
                TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.white24));
    }
    if (_error != null) {
      return _Message(
        icon: Icons.cloud_off_rounded,
        text: _error!,
        action: TextButton(onPressed: _load, child: const Text('إعادة المحاولة')),
      );
    }
    if (_rooms.isEmpty) {
      return const _Message(
        icon: Icons.forum_outlined,
        text: 'لا توجد غرف مفتوحة الآن.\nكن أول من يبدأ نقاشاً.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 90),
      itemCount: _rooms.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _RoomCard(
        room: _rooms[i],
        onTap: () => _open(_rooms[i].id, _rooms[i].title),
      ),
    );
  }
}

class _RoomCard extends StatelessWidget {
  final VoiceRoomSummary room;
  final VoidCallback onTap;
  const _RoomCard({required this.room, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF16181D),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: room.isLive
                ? const Color(0xFF4CAF50).withOpacity(.35)
                : Colors.white10,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (room.isLive) ...[
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                              color: Color(0xFF4CAF50), shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 7),
                      ],
                      Expanded(
                        child: Text(
                          room.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15.5,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (room.isLocked)
                        const Icon(Icons.lock_rounded,
                            size: 15, color: Colors.white38),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Text(
                    '${room.hostName} · ${room.listenerCount} مشارك',
                    style:
                        const TextStyle(color: Colors.white38, fontSize: 12.5),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_left_rounded, color: Colors.white24),
          ],
        ),
      ),
    );
  }
}

class _CreateRoomDialog extends StatefulWidget {
  const _CreateRoomDialog();
  @override
  State<_CreateRoomDialog> createState() => _CreateRoomDialogState();
}

class _CreateRoomDialogState extends State<_CreateRoomDialog> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF16181D),
      title: const Text('غرفة جديدة', style: TextStyle(color: Colors.white)),
      content: TextField(
        controller: _c,
        autofocus: true,
        maxLength: 60,
        style: const TextStyle(color: Colors.white),
        decoration: const InputDecoration(
          hintText: 'عن ماذا تريد التحدث؟',
          hintStyle: TextStyle(color: Colors.white24),
          counterStyle: TextStyle(color: Colors.white24),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء', style: TextStyle(color: Colors.white54)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _c.text),
          child: const Text('إنشاء', style: TextStyle(color: Color(0xFFFFC107))),
        ),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String text;
  final Widget? action;
  const _Message({required this.icon, required this.text, this.action});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 140),
        Icon(icon, size: 54, color: Colors.white12),
        const SizedBox(height: 16),
        Text(text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white38, fontSize: 14)),
        if (action != null) Center(child: action!),
      ],
    );
  }
}
