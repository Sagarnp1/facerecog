import 'package:flutter/material.dart';
import '../models/user_model.dart';

class AppTheme {
  // Department-specific color schemes
  static const Map<Department, Color> departmentColors = {
    Department.BEI: Colors.blue,        // Electronics
    Department.BCT: Colors.green,       // Computer
    Department.BCE: Colors.brown,       // Civil
    Department.BAG: Colors.lightGreen,  // Agriculture
    Department.BEL: Colors.amber,       // Electrical
    Department.BME: Colors.red,         // Mechanical
    Department.BAR: Colors.purple,      // Architecture
  };

  static Color getDepartmentColor(Department department) {
    return departmentColors[department] ?? Colors.blue;
  }

  static ThemeData getTheme(Department department) {
    final primaryColor = getDepartmentColor(department);

    return ThemeData(
      primarySwatch: _createMaterialColor(primaryColor),
      primaryColor: primaryColor,
      visualDensity: VisualDensity.adaptivePlatformDensity,

      // AppBar theme
      appBarTheme: AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),

      // Card theme
      cardTheme: CardThemeData(
        elevation: 2,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),

      // Button themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),

      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),

      // FloatingActionButton theme
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
    );
  }

  static MaterialColor _createMaterialColor(Color color) {
    List strengths = <double>[.05];
    Map<int, Color> swatch = {};
    final int r = color.red, g = color.green, b = color.blue;

    for (int i = 1; i < 10; i++) {
      strengths.add(0.1 * i);
    }
    for (var strength in strengths) {
      final double ds = 0.5 - strength;
      swatch[(strength * 1000).round()] = Color.fromRGBO(
        r + ((ds < 0 ? r : (255 - r)) * ds).round(),
        g + ((ds < 0 ? g : (255 - g)) * ds).round(),
        b + ((ds < 0 ? b : (255 - b)) * ds).round(),
        1,
      );
    }
    return MaterialColor(color.value, swatch);
  }
}

// Department helper methods
extension DepartmentExtension on Department {
  String get name {
    switch (this) {
      case Department.BEI:
        return 'BEI';
      case Department.BCT:
        return 'BCT';
      case Department.BCE:
        return 'BCE';
      case Department.BAG:
        return 'BAG';
      case Department.BEL:
        return 'BEL';
      case Department.BME:
        return 'BME';
      case Department.BAR:
        return 'BAR';
    }
  }

  String get displayName {
    switch (this) {
      case Department.BEI:
        return 'Electronics & Information';
      case Department.BCT:
        return 'Computer';
      case Department.BCE:
        return 'Civil';
      case Department.BAG:
        return 'Agriculture';
      case Department.BEL:
        return 'Electrical';
      case Department.BME:
        return 'Mechanical';
      case Department.BAR:
        return 'Architecture';
    }
  }

  Color get color => AppTheme.getDepartmentColor(this);
}
