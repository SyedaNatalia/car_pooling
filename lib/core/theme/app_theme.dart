import 'package:flutter/material.dart';

class AppTheme {
  // ── Navy Blue palette ──────────────────────────────────────
  static const Color primary      = Color(0xFF270d7d); 
  static const Color primaryLight = Color(0xFFEAE8F5); 

  // ── Supporting colors (unchanged) ─────────────────────────
  static const Color secondary    = Color(0xFF0EA5E9);
  static const Color success      = Color(0xFF22C55E);
  static const Color warning      = Color(0xFFF59E0B);
  static const Color error        = Color(0xFFEF4444);

  // ── Text colors ────────────────────────────────────────────
  static const Color textDark     = Color(0xFF1E293B);
  static const Color textMedium   = Color(0xFF64748B);
  static const Color textLight    = Color(0xFF94A3B8);

  // ── Backgrounds ────────────────────────────────────────────
  static const Color bgLight      = Color(0xFFF8F9FF); 
  static const Color bgWhite      = Color(0xFFFFFFFF); 
  static const Color border       = Color(0xFFDEE4E5);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: bgLight,
      fontFamily: 'Inter',

      appBarTheme: const AppBarTheme(
        backgroundColor: bgWhite,        
        foregroundColor: primary,         
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: primary,                 
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,       
          foregroundColor: Colors.white,  
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,    
          minimumSize: const Size(double.infinity, 52),
          side: const BorderSide(color: primary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bgWhite,          
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: error),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: const TextStyle(color: textMedium),
      ),

      cardTheme: CardThemeData(
        color: bgWhite,      
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: border),
        ),
      ),

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: bgWhite,     
        selectedItemColor: primary, 
        unselectedItemColor: textLight,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: primary,   
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      ),
    );
  }
}