import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/room_participant.dart';
import '../../domain/entities/room_role.dart';
import '../bloc/audio_level_cubit.dart';

/// بطاقة متحدث — الأفاتار يتوهّج مع مستوى الصوت.
///
/// ★ نقطة الأداء: يستمع لـ AudioLevelCubit بـ buildWhen يقارن هذا
///   المشارك فقط. حتى مع 12 متحدثاً و10 تحديثات/ثانية، لا يُعاد بناء
///   إلا البطاقة التي تغيّر مستواها فعلاً.
class SpeakerTile extends StatelessWidget {
  final RoomParticipant p;
  final bool showHostControls;
  final VoidCallback? onMute;
  final VoidCallback? onKick;

  const SpeakerTile({
    super.key,
    required this.p,
    this.showHostControls = false,
    this.onMute,
    this.onKick,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: showHostControls && !p.isLocal
          ? () => _showHostSheet(context)
          : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BlocBuilder<AudioLevelCubit, Map<String, double>>(
            // ★ لا تُعِد البناء إلا إن تغيّر مستوى *هذا* المشارك
            buildWhen: (a, b) => a[p.uid] != b[p.uid],
            builder: (_, levels) {
              final lvl = (levels[p.uid] ?? 0.0).clamp(0.0, 1.0);
              final speaking = p.isMicEnabled && lvl > 0.05;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                padding: EdgeInsets.all(speaking ? 3 + lvl * 3 : 3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: speaking
                        ? const Color(0xFF4CAF50)
                        : Colors.transparent,
                    width: 2.5,
                  ),
                ),
                child: _Avatar(p: p),
              );
            },
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 76,
            child: Text(
              p.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.white),
            ),
          ),
          const SizedBox(height: 2),
          _StatusRow(p: p),
        ],
      ),
    );
  }

  void _showHostSheet(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: const Color(0xFF16181D),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Text(p.name,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.mic_off_rounded, color: Colors.orange),
              title: const Text('كتم المتحدث',
                  style: TextStyle(color: Colors.white)),
              subtitle: const Text('لن يستطيع فتح المايك بنفسه',
                  style: TextStyle(color: Colors.white38, fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx);
                onMute?.call();
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.person_remove_rounded, color: Colors.red),
              title: const Text('طرد من الغرفة',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                onKick?.call();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final RoomParticipant p;
  const _Avatar({required this.p});

  @override
  Widget build(BuildContext context) {
    final initials = p.name.isNotEmpty ? p.name.substring(0, 1) : '؟';
    return CircleAvatar(
      radius: 30,
      backgroundColor: const Color(0xFF2A2E37),
      backgroundImage:
          p.avatarUrl.isNotEmpty ? NetworkImage(p.avatarUrl) : null,
      child: p.avatarUrl.isEmpty
          ? Text(initials,
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 22,
                  fontWeight: FontWeight.bold))
          : null,
    );
  }
}

class _StatusRow extends StatelessWidget {
  final RoomParticipant p;
  const _StatusRow({required this.p});

  @override
  Widget build(BuildContext context) {
    final icons = <Widget>[];

    if (p.role == RoomRole.host) {
      icons.add(const Icon(Icons.star_rounded,
          size: 13, color: Color(0xFFFFC107)));
    }
    if (p.isMutedByHost) {
      icons.add(const Icon(Icons.volume_off_rounded,
          size: 13, color: Colors.orangeAccent));
    } else if (!p.isMicEnabled) {
      icons.add(
          const Icon(Icons.mic_off_rounded, size: 13, color: Colors.white30));
    }
    if (p.quality == ConnectionQuality.poor) {
      icons.add(const Icon(Icons.signal_cellular_alt_1_bar_rounded,
          size: 13, color: Colors.orangeAccent));
    }

    if (icons.isEmpty) return const SizedBox(height: 13);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final i in icons) Padding(padding: const EdgeInsets.symmetric(horizontal: 1), child: i)
      ],
    );
  }
}
