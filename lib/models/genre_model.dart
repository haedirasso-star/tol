class Genre {
  final int id;
  final String name;

  Genre({required this.id, required this.name});

  // قائمة التصنيفات المدعومة (يمكنك إضافة المزيد لتطويل الكود)
  static List<Genre> getCategories() {
    return [
      Genre(id: 0, name: "الكل"),
      Genre(id: 28, name: "أكشن"),
      Genre(id: 35, name: "كوميدي"),
      Genre(id: 27, name: "رعب"),
      Genre(id: 10749, name: "رومانسي"),
      Genre(id: 878, name: "خيال علمي"),
      Genre(id: 10770, name: "بث مباشر"),
      Genre(id: 99, name: "وثائقي"),
    ];
  }
}
