import 'package:flutter/material.dart';

class SubtitleSelector extends StatelessWidget {
  final List<String> subtitles;
  final ValueChanged<String?> onSubtitleSelected;

  const SubtitleSelector({
    Key? key,
    required this.subtitles,
    required this.onSubtitleSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
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
              'الترجمة',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            title: const Text(
              'إيقاف',
              style: TextStyle(color: Colors.white),
            ),
            onTap: () => onSubtitleSelected(null),
          ),
          ...subtitles.map((s) => ListTile(
                title: Text(
                  s,
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () => onSubtitleSelected(s),
              )),
        ],
      ),
    );
  }
}
