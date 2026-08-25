import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/voice_room_bloc.dart';
import '../bloc/voice_room_event.dart';
import '../bloc/voice_room_state.dart';

/// شريط التحكّم السفلي — مايك، سماعة، رفع يد، خروج
class RoomControlBar extends StatelessWidget {
  const RoomControlBar({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VoiceRoomBloc, VoiceRoomState>(
      buildWhen: (a, b) =>
          a.micEnabled != b.micEnabled ||
          a.canToggleMic != b.canToggleMic ||
          a.speakerphone != b.speakerphone ||
          a.handRaised != b.handRaised,
      builder: (ctx, s) {
        final bloc = ctx.read<VoiceRoomBloc>();
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          decoration: const BoxDecoration(
            color: Color(0xFF16181D),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _RoundBtn(
                icon: s.speakerphone
                    ? Icons.volume_up_rounded
                    : Icons.phone_in_talk_rounded,
                label: s.speakerphone ? 'مكبّر' : 'سماعة',
                onTap: () => bloc.add(const SpeakerphoneToggled()),
              ),

              // ★ المستمع يرى "ارفع يدك"، المتحدث يرى زر المايك
              if (s.canToggleMic)
                _MicButton(
                  enabled: s.micEnabled,
                  onTap: () => bloc.add(const MicToggled()),
                )
              else
                _RoundBtn(
                  icon: Icons.pan_tool_rounded,
                  label: s.handRaised ? 'يدك مرفوعة' : 'اطلب التحدث',
                  color: s.handRaised ? const Color(0xFFFFC107) : null,
                  big: true,
                  onTap: () => bloc.add(HandRaised(!s.handRaised)),
                ),

              _RoundBtn(
                icon: Icons.call_end_rounded,
                label: 'خروج',
                color: Colors.redAccent,
                onTap: () {
                  bloc.add(const RoomLeaveRequested());
                  Navigator.of(ctx).maybePop();
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MicButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;
  const _MicButton({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: enabled ? const Color(0xFF4CAF50) : Colors.white12,
              boxShadow: enabled
                  ? [
                      BoxShadow(
                          color: const Color(0xFF4CAF50).withOpacity(.4),
                          blurRadius: 18,
                          spreadRadius: 2)
                    ]
                  : null,
            ),
            child: Icon(
              enabled ? Icons.mic_rounded : Icons.mic_off_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(height: 6),
          Text(enabled ? 'تتحدث الآن' : 'مكتوم',
              style: const TextStyle(color: Colors.white60, fontSize: 11)),
        ],
      ),
    );
  }
}

class _RoundBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  final bool big;

  const _RoundBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.big = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = big ? 68.0 : 52.0;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (color ?? Colors.white).withOpacity(.14),
            ),
            child: Icon(icon, color: color ?? Colors.white, size: big ? 28 : 22),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: const TextStyle(color: Colors.white60, fontSize: 11)),
        ],
      ),
    );
  }
}
