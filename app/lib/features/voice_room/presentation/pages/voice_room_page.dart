import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../di.dart';
import '../../domain/entities/room_role.dart';
import '../../domain/repositories/voice_room_repository.dart';
import '../bloc/audio_level_cubit.dart';
import '../bloc/voice_room_bloc.dart';
import '../bloc/voice_room_event.dart';
import '../bloc/voice_room_state.dart';
import '../widgets/connection_banner.dart';
import '../widgets/mic_button.dart';
import '../widgets/speaker_tile.dart';

/// صفحة الغرفة الصوتية.
///
/// ⚠️ ينشئ Repository + BLoC + Cubit خاصة بهذه الغرفة، ويتخلّص منها
///    عند الخروج. كل غرفة = اتصال LiveKit مستقل.
class VoiceRoomPage extends StatelessWidget {
  final String roomId;
  final String title;

  const VoiceRoomPage({super.key, required this.roomId, this.title = ''});

  @override
  Widget build(BuildContext context) {
    final repo = VoiceRoomFactory.createRepository();

    return MultiBlocProvider(
      providers: [
        BlocProvider<VoiceRoomBloc>(
          create: (_) => VoiceRoomFactory.createBloc(repo)
            ..add(RoomJoinRequested(roomId)),
        ),
        BlocProvider<AudioLevelCubit>(
          create: (_) => VoiceRoomFactory.createLevels(repo),
        ),
      ],
      child: _RoomView(title: title, repo: repo),
    );
  }
}

class _RoomView extends StatelessWidget {
  final String title;
  final VoiceRoomRepository repo;
  const _RoomView({required this.title, required this.repo});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) context.read<VoiceRoomBloc>().add(const RoomLeaveRequested());
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0E1013),
        body: SafeArea(
          child: BlocConsumer<VoiceRoomBloc, VoiceRoomState>(
            listenWhen: (a, b) => a.error != b.error && b.error != null,
            listener: (ctx, s) {
              ScaffoldMessenger.of(ctx)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(
                  content: Text(s.error!),
                  backgroundColor: Colors.red.shade900,
                  behavior: SnackBarBehavior.floating,
                ));
              ctx.read<VoiceRoomBloc>().add(const ErrorDismissed());
            },
            builder: (ctx, s) {
              if (s.busy && s.room == null) {
                return const Center(
                    child: CircularProgressIndicator(color: Colors.white24));
              }

              return Column(
                children: [
                  ConnectionBanner(state: s.connection),
                  _Header(
                    title: s.room?.title.isNotEmpty == true
                        ? s.room!.title
                        : title,
                    listeners: s.listenerCount,
                    role: s.myRole,
                  ),
                  Expanded(child: _SpeakerGrid(state: s)),
                  const RoomControlBar(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String title;
  final int listeners;
  final RoomRole role;
  const _Header(
      {required this.title, required this.listeners, required this.role});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  '$listeners مستمع · ${switch (role) {
                    RoomRole.host => 'أنت المضيف',
                    RoomRole.speaker => 'أنت متحدث',
                    RoomRole.listener => 'أنت مستمع',
                  }}',
                  style: const TextStyle(color: Colors.white38, fontSize: 12.5),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down_rounded,
                color: Colors.white54),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
    );
  }
}

class _SpeakerGrid extends StatelessWidget {
  final VoiceRoomState state;
  const _SpeakerGrid({required this.state});

  @override
  Widget build(BuildContext context) {
    final speakers = state.speakers;
    if (speakers.isEmpty) {
      return const Center(
        child: Text('لا يوجد متحدثون بعد',
            style: TextStyle(color: Colors.white24, fontSize: 14)),
      );
    }

    final bloc = context.read<VoiceRoomBloc>();
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 18,
        crossAxisSpacing: 8,
        childAspectRatio: .78,
      ),
      itemCount: speakers.length,
      itemBuilder: (_, i) {
        final p = speakers[i];
        return SpeakerTile(
          p: p,
          showHostControls: state.isHost,
          onMute: () => bloc.add(ParticipantMuted(p.uid)),
          onKick: () => bloc.add(ParticipantKicked(p.uid)),
        );
      },
    );
  }
}
