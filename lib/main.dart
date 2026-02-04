import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/mode_selection_screen.dart';
import 'screens/app_selection_screen.dart';
import 'screens/schedule_config_screen.dart';
import 'screens/pomodoro_config_screen.dart';

import 'screens/permission_status_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/stats_screen.dart';

void main() {
  runApp(const FocusGuardApp());
}

class FocusGuardApp extends StatelessWidget {
  const FocusGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Focus Guard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF0F3460),
        scaffoldBackgroundColor: const Color(0xFF0F0F1A),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF16213E),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        cardTheme: CardTheme(
          color: const Color(0xFF16213E),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0F3460),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF16213E),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF0F3460), width: 2),
          ),
        ),
        textTheme: const TextTheme(
          titleLarge: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
          titleMedium: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          bodyLarge: TextStyle(
            color: Colors.white,
            fontSize: 16,
          ),
          bodyMedium: TextStyle(
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
        // UI Consistency: Add TimePicker and Progress themes
        timePickerTheme: TimePickerThemeData(
          backgroundColor: const Color(0xFFFFFDF2),
          dialBackgroundColor: const Color(0xFFF3F2E8),
          hourMinuteColor: const Color(0xFF16213E),
          hourMinuteTextColor: Colors.white,
          dayPeriodColor: const Color(0xFF6E8F5E),
          dayPeriodTextColor: Colors.white,
          entryModeIconColor: const Color(0xFF4E6E3A),
          helpTextStyle: TextStyle(
            color: const Color(0xFF7A7A70),
            fontSize: 14,
          ),
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: Color(0xFF6E8F5E),
          linearTrackColor: Color(0xFFE6EFE3),
          refreshBackgroundColor: Color(0xFFE6EFE3),
        ),
        // UI Consistency: Custom dialog button style
        dialogTheme: DialogTheme(
          backgroundColor: const Color(0xFFFFFDF2),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          titleTextStyle: const TextStyle(
            color: Color(0xFF2C2C25),
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
          contentTextStyle: const TextStyle(
            color: Color(0xFF7A7A70),
            fontSize: 14,
          ),
        ),
        useMaterial3: true,
      ),
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/home': (context) => const HomeScreen(),
        '/mode-selection': (context) => const ModeSelectionScreen(),
        '/app-selection': (context) => const AppSelectionScreen(),
        '/schedule-config': (context) => const ScheduleConfigScreen(),
        '/pomodoro-config': (context) => const PomodoroConfigScreen(),
        '/permissions': (context) => const PermissionStatusScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/stats': (context) => const StatsScreen(),
      },
    );
  }
}
