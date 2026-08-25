/// ═══════════════════════════════════════════════════════════════
///  TOTV+ Voice Rooms — نقطة الاستيراد الوحيدة للميزة
///
///  الاستخدام في تطبيقك:
///    import 'features/voice_room/voice_room.dart';
///    Navigator.push(ctx, MaterialPageRoute(
///        builder: (_) => const RoomsListPage()));
/// ═══════════════════════════════════════════════════════════════
library voice_room;

export 'core/failures.dart';
export 'di.dart';
export 'domain/entities/room_participant.dart';
export 'domain/entities/room_role.dart';
export 'domain/entities/voice_room.dart';
export 'domain/repositories/voice_room_repository.dart';
export 'domain/usecases/voice_room_usecases.dart';
export 'presentation/bloc/audio_level_cubit.dart';
export 'presentation/bloc/voice_room_bloc.dart';
export 'presentation/bloc/voice_room_event.dart';
export 'presentation/bloc/voice_room_state.dart';
export 'presentation/pages/rooms_list_page.dart';
export 'presentation/pages/voice_room_page.dart';
