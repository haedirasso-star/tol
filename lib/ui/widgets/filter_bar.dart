import 'package:flutter/material.dart';
import '../../models/genre_model.dart';

class FilterBar extends StatefulWidget {
  final Function(int) onGenreSelected;
  const FilterBar({super.key, required this.onGenreSelected});

  @override
  State<FilterBar> createState() => _FilterBarState();
}

class _FilterBarState extends State<FilterBar> {
  int _selectedIndex = 0;
  final List<Genre> _genres = Genre.getCategories();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _genres.length,
        itemBuilder: (context, index) {
          bool isSelected = _selectedIndex == index;
          return GestureDetector(
            onTap: () {
              setState(() => _selectedIndex = index);
              widget.onGenreSelected(_genres[index].id);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              margin: const EdgeInsets.only(left: 10),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFFFD700) : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: isSelected ? Colors.transparent : Colors.white10),
              ),
              child: Center(
                child: Text(
                  _genres[index].name,
                  style: TextStyle(
                    color: isSelected ? Colors.black : Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
