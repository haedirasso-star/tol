import 'package:flutter/material.dart';

import '../../domain/entities/room_role.dart';

/// شريط علوي يظهر فقط عند وجود مشكلة اتصال
class ConnectionBanner extends StatelessWidget {
  final RoomConnectionState state;
  const ConnectionBanner({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final (text, color) = switch (state) {
      RoomConnectionState.connecting => ('جارٍ الاتصال…', Colors.blueGrey),
      RoomConnectionState.reconnecting =>
        ('انقطع الاتصال — جارٍ إعادة المحاولة…', Colors.orange),
      RoomConnectionState.disconnected => ('غير متصل', Colors.redAccent),
      RoomConnectionState.connected => ('', Colors.transparent),
    };

    if (text.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      color: color.withOpacity(.18),
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 13,
            height: 13,
            child: CircularProgressIndicator(strokeWidth: 2, color: color),
          ),
          const SizedBox(width: 10),
          Text(text, style: TextStyle(color: color, fontSize: 12.5)),
        ],
      ),
    );
  }
}
