import 'package:flutter/material.dart';
import '../../core/services/video_player_service.dart';

class QualitySelector extends StatelessWidget {
  final List<VideoQuality> qualities;
  final String currentQuality;
  final ValueChanged<String> onQualitySelected;

  const QualitySelector({
    Key? key,
    required this.qualities,
    required this.currentQuality,
    required this.onQualitySelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A).withOpacity(0.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFF6B00), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'الجودة',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ...qualities.map((q) {
            final isSelected = currentQuality == q.value;
            return ListTile(
              title: Text(
                q.label,
                style: TextStyle(
                  color: isSelected ? const Color(0xFFFF6B00) : Colors.white,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              onTap: () => onQualitySelected(q.value),
            );
          }),
        ],
      ),
    );
  }
}
