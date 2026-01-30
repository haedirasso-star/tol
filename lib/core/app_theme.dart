import 'package:flutter/material.dart';

class AppTheme {
  // اللون الذهبي الأساسي لتطبيق TOL
  static const Color primaryGold = Color(0xFFFFD700);
  // اللون الأسود العميق للخلفيات
  static const Color backgroundBlack = Color(0xFF0A0A0A);
  // لون الكروت والبطاقات (أسود فاتح قليلاً)
  static const Color surfaceGrey = Color(0xFF1A1A1A);

  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: primaryGold,
    scaffoldBackgroundColor: backgroundBlack,
    
    // تنسيق شريط التطبيق العلوي (AppBar)
    appBarTheme: const AppBarTheme(
      backgroundColor: backgroundBlack,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: primaryGold,
        fontSize: 20,
        fontWeight: FontWeight.bold,
        fontFamily: 'Cairo', // يفضل استخدام خط Cairo للعربية
      ),
    ),

    // تنسيق الأزرار الذهبية (ElevatedButton)
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryGold,
        foregroundColor: Colors.black,
        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),

    // تنسيق الأزرار الشفافة (OutlinedButton)
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: Colors.white24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),

    // تنسيق النصوص (TextTheme)
    textTheme: const TextTheme(
      displayLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      bodyLarge: TextStyle(color: Colors.white70),
      bodyMedium: TextStyle(color: Colors.white60),
    ),

    // تنسيق شريط التنقل السفلي
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: surfaceGrey,
      selectedItemColor: primaryGold,
      unselectedItemColor: Colors.white38,
      type: BottomNavigationBarType.fixed,
    ),
  );
}
