import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  AppTheme._();

  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color primaryBlueDark = Color(0xFF1D4ED8);
  static const Color primaryBlueLight = Color(0xFF3B82F6);
  static const Color primaryBlueExtraLight = Color(0xFFEBF4FF);
  static const Color primaryContainer = Color(0xFFEBF4FF);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onPrimaryContainer = Color(0xFF0F172A);

  static const Color glucoseNormal = Color(0xFF059669);
  static const Color glucoseLow = Color(0xFFDC2626);
  static const Color glucoseHigh = Color(0xFFEA580C);
  static const Color glucoseVeryHigh = Color(0xFFB91C1C);
  static const Color glucoseCritical = Color(0xFF7C2D12);

  static const Color successGreen = Color(0xFF059669);
  static const Color warningOrange = Color(0xFFEA580C);
  static const Color errorRed = Color(0xFFDC2626);
  static const Color infoBlue = Color(0xFF0284C7);

  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF1F5F9);
  static const Color surfaceContainer = Color(0xFFF1F5F9);
  static const Color surfaceContainerHigh = Color(0xFFE2E8F0);
  static const Color onSurface = Color(0xFF0F172A);
  static const Color onSurfaceVariant = Color(0xFF475569);

  static const Color background = Color(0xFFF8FAFC);
  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color backgroundWhite = Color(0xFFFFFFFF);
  static const Color onBackground = Color(0xFF0F172A);

  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textTertiary = Color(0xFF64748B);
  static const Color textDisabled = Color(0xFF94A3B8);

  static const Color neutralGray = Color(0xFF94A3B8);
  static const Color neutralLightGray = Color(0xFFCBD5E1);
  static const Color neutralGrayLight = Color(0xFF94A3B8);
  static const Color neutralGrayDark = Color(0xFF475569);

  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color borderMedium = Color(0xFFCBD5E1);
  static const Color borderDark = Color(0xFF94A3B8);

  static const Color scanColor = Color(0xFF8B5CF6);
  static const Color insightsColor = Color(0xFF06B6D4);
  static const Color profileColor = Color(0xFF10B981);
  static const Color mealColor = Color(0xFFF59E0B);
  static const Color medicationColor = Color(0xFF3B82F6);
  static const Color exerciseColor = Color(0xFFEF4444);
  static const Color sleepColor = Color(0xFF6366F1);

  static const Color moodGreat = Color(0xFF22C55E);
  static const Color moodGood = Color(0xFF84CC16);
  static const Color moodOkay = Color(0xFFF59E0B);
  static const Color moodTired = Color(0xFFEF4444);
  static const Color moodStressed = Color(0xFF8B5CF6);

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryBlue, primaryBlueDark],
  );

  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [successGreen, Color(0xFF047857)],
  );

  static const LinearGradient warningGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [warningOrange, Color(0xFFDC2626)],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [backgroundWhite, Color(0xFFFAFBFF)],
  );

  static const LinearGradient glucoseGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFECFDF5), Color(0xFFF0FDF4)],
  );

  static const String fontFamily = 'SF Pro Display';

  static const TextStyle displayLarge = TextStyle(
    fontSize: 57,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.25,
    color: textPrimary,
    fontFamily: fontFamily,
  );

  static const TextStyle displayMedium = TextStyle(
    fontSize: 45,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    color: textPrimary,
    fontFamily: fontFamily,
  );

  static const TextStyle displaySmall = TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    color: textPrimary,
    fontFamily: fontFamily,
  );

  static const TextStyle headlineLarge = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    color: textPrimary,
    fontFamily: fontFamily,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.25,
    color: textPrimary,
    fontFamily: fontFamily,
  );

  static const TextStyle headlineSmall = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    color: textPrimary,
    fontFamily: fontFamily,
  );

  static const TextStyle titleLarge = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    color: textPrimary,
    fontFamily: fontFamily,
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.15,
    color: textPrimary,
    fontFamily: fontFamily,
  );

  static const TextStyle titleSmall = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    color: textPrimary,
    fontFamily: fontFamily,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.5,
    color: textPrimary,
    fontFamily: fontFamily,
    height: 1.5,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.25,
    color: textSecondary,
    fontFamily: fontFamily,
    height: 1.4,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.4,
    color: textTertiary,
    fontFamily: fontFamily,
    height: 1.3,
  );

  static const TextStyle labelLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    color: textPrimary,
    fontFamily: fontFamily,
  );

  static const TextStyle labelMedium = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    color: textSecondary,
    fontFamily: fontFamily,
  );

  static const TextStyle labelSmall = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    color: textTertiary,
    fontFamily: fontFamily,
  );

  static const TextStyle appBarTitleStyle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: backgroundWhite,
    letterSpacing: -0.5,
  );

  static const TextStyle headingLarge = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    letterSpacing: -0.5,
  );

  static const TextStyle headingMedium = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    letterSpacing: -0.3,
  );

  static const TextStyle headingSmall = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    letterSpacing: -0.2,
  );

  static const TextStyle captionStyle = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: neutralGray,
    letterSpacing: 0.1,
  );

  static const TextStyle buttonTextStyle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
  );

  static const TextStyle glucoseValueStyle = TextStyle(
    fontSize: 56,
    fontWeight: FontWeight.w800,
    letterSpacing: -2,
    height: 1.0,
  );

  static const TextStyle glucoseValueLarge = TextStyle(
    fontSize: 72,
    fontWeight: FontWeight.w900,
    letterSpacing: -3,
    height: 0.9,
  );

  static const TextStyle glucoseUnitStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: textSecondary,
  );

  static const TextStyle glucoseStatusStyle = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: backgroundWhite,
  );

  static const TextStyle glucoseTimestampStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: textTertiary,
  );

  static const TextStyle cardTitleStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    letterSpacing: -0.1,
  );

  static const TextStyle cardSubtitleStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: textSecondary,
  );

  static const List<BoxShadow> elevation1 = [
    BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 2,
      offset: Offset(0, 1),
    ),
  ];

  static const List<BoxShadow> elevation2 = [
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 4,
      offset: Offset(0, 2),
    ),
  ];

  static const List<BoxShadow> elevation3 = [
    BoxShadow(
      color: Color(0x1F000000),
      blurRadius: 8,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> elevation4 = [
    BoxShadow(
      color: Color(0x29000000),
      blurRadius: 12,
      offset: Offset(0, 6),
    ),
  ];

  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.04),
      blurRadius: 20,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: Colors.black.withOpacity(0.02),
      blurRadius: 40,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> get lightShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.04),
      blurRadius: 10,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> get mediumShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.06),
      blurRadius: 15,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get bottomNavShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.1),
      blurRadius: 20,
      offset: const Offset(0, -5),
    ),
  ];

  static List<BoxShadow> get glucoseCardShadow => [
    BoxShadow(
      color: primaryBlue.withOpacity(0.1),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];

  static const BorderRadius radiusXS = BorderRadius.all(Radius.circular(4));
  static const BorderRadius radiusS = BorderRadius.all(Radius.circular(8));
  static const BorderRadius radiusM = BorderRadius.all(Radius.circular(12));
  static const BorderRadius radiusL = BorderRadius.all(Radius.circular(16));
  static const BorderRadius radiusXL = BorderRadius.all(Radius.circular(24));
  static const BorderRadius radiusXXL = BorderRadius.all(Radius.circular(32));

  static const BorderRadius cardBorderRadius = BorderRadius.all(Radius.circular(16));
  static const BorderRadius buttonBorderRadius = BorderRadius.all(Radius.circular(14));
  static const BorderRadius inputBorderRadius = BorderRadius.all(Radius.circular(16));
  static const BorderRadius chipBorderRadius = BorderRadius.all(Radius.circular(12));
  static const BorderRadius smallBorderRadius = BorderRadius.all(Radius.circular(8));
  static const BorderRadius largeBorderRadius = BorderRadius.all(Radius.circular(20));

  static const double spacingXS = 4;
  static const double spacingS = 8;
  static const double spacingM = 16;
  static const double spacingL = 24;
  static const double spacingXL = 32;
  static const double spacingXXL = 48;

  static const double iconSizeSmall = 16;
  static const double iconSizeMedium = 24;
  static const double iconSizeLarge = 32;
  static const double iconSizeXLarge = 48;

  static const Duration fastAnimation = Duration(milliseconds: 200);
  static const Duration normalAnimation = Duration(milliseconds: 300);
  static const Duration slowAnimation = Duration(milliseconds: 500);
  static const Duration extraSlowAnimation = Duration(milliseconds: 800);

  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;
  static const double desktopBreakpoint = 1200;

  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < mobileBreakpoint;
  }

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= mobileBreakpoint && width < desktopBreakpoint;
  }

  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= desktopBreakpoint;
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryBlue,
      scaffoldBackgroundColor: backgroundLight,
      
      colorScheme: const ColorScheme.light(
        primary: primaryBlue,
        onPrimary: onPrimary,
        primaryContainer: primaryContainer,
        onPrimaryContainer: onPrimaryContainer,
        secondary: successGreen,
        onSecondary: backgroundWhite,
        secondaryContainer: Color(0xFFECFDF5),
        onSecondaryContainer: textPrimary,
        surface: surface,
        onSurface: onSurface,
        surfaceVariant: surfaceVariant,
        onSurfaceVariant: onSurfaceVariant,
        background: background,
        onBackground: onBackground,
        error: errorRed,
        onError: backgroundWhite,
        outline: borderLight,
        outlineVariant: borderMedium,
      ),

      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: primaryBlue,
        foregroundColor: backgroundWhite,
        titleTextStyle: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: backgroundWhite,
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(
          color: backgroundWhite,
          size: 24,
        ),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: backgroundWhite,
          elevation: 0,
          shadowColor: primaryBlue.withOpacity(0.3),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: buttonBorderRadius,
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryBlue,
          backgroundColor: primaryBlueExtraLight,
          side: BorderSide(color: primaryBlue.withOpacity(0.2)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: buttonBorderRadius,
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryBlue,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: inputBorderRadius,
          borderSide: const BorderSide(color: borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: inputBorderRadius,
          borderSide: const BorderSide(color: borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: inputBorderRadius,
          borderSide: const BorderSide(color: primaryBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: inputBorderRadius,
          borderSide: const BorderSide(color: errorRed),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: inputBorderRadius,
          borderSide: const BorderSide(color: errorRed, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        labelStyle: const TextStyle(
          color: textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: const TextStyle(
          color: neutralGray,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        errorStyle: const TextStyle(
          color: errorRed,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryBlue,
        foregroundColor: backgroundWhite,
        elevation: 6,
        focusElevation: 8,
        hoverElevation: 8,
        highlightElevation: 12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: surfaceVariant,
        selectedColor: primaryBlueExtraLight,
        labelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textPrimary,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: chipBorderRadius,
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: borderLight,
        thickness: 1,
        space: 1,
      ),

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: backgroundWhite,
        selectedItemColor: primaryBlue,
        unselectedItemColor: neutralGray,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return primaryBlue;
          }
          return Colors.transparent;
        }),
        checkColor: MaterialStateProperty.all(backgroundWhite),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return primaryBlue;
          }
          return neutralGray;
        }),
        trackColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return primaryBlue.withOpacity(0.3);
          }
          return neutralLightGray;
        }),
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primaryBlue,
        linearTrackColor: borderLight,
        circularTrackColor: borderLight,
      ),


      fontFamily: fontFamily,
      textTheme: const TextTheme(
        displayLarge: displayLarge,
        displayMedium: displayMedium,
        displaySmall: displaySmall,
        headlineLarge: headlineLarge,
        headlineMedium: headlineMedium,
        headlineSmall: headlineSmall,
        titleLarge: titleLarge,
        titleMedium: titleMedium,
        titleSmall: titleSmall,
        bodyLarge: bodyLarge,
        bodyMedium: bodyMedium,
        bodySmall: bodySmall,
        labelLarge: labelLarge,
        labelMedium: labelMedium,
        labelSmall: labelSmall,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primaryBlueLight,
      scaffoldBackgroundColor: const Color(0xFF0F172A),
      
      colorScheme: const ColorScheme.dark(
        primary: primaryBlueLight,
        onPrimary: Color(0xFF000000),
        primaryContainer: Color(0xFF1E293B),
        onPrimaryContainer: Color(0xFFE2E8F0),
        secondary: successGreen,
        onSecondary: Color(0xFF000000),
        secondaryContainer: Color(0xFF064E3B),
        onSecondaryContainer: Color(0xFFE2E8F0),
        surface: Color(0xFF1E293B),
        onSurface: Color(0xFFF8FAFC),
        onSurfaceVariant: Color(0xFF94A3B8),
        error: errorRed,
        onError: Color(0xFFF8FAFC),
        outline: Color(0xFF334155),
        outlineVariant: Color(0xFF475569),
      ),

      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: Color(0xFF1E293B),
        foregroundColor: Color(0xFFF8FAFC),
        titleTextStyle: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: Color(0xFFF8FAFC),
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(
          color: Color(0xFFF8FAFC),
          size: 24,
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlueLight,
          foregroundColor: const Color(0xFF0F172A),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: buttonBorderRadius,
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF334155),
        border: OutlineInputBorder(
          borderRadius: inputBorderRadius,
          borderSide: const BorderSide(color: Color(0xFF475569)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: inputBorderRadius,
          borderSide: const BorderSide(color: Color(0xFF475569)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: inputBorderRadius,
          borderSide: const BorderSide(color: primaryBlueLight, width: 2),
        ),
        labelStyle: const TextStyle(
          color: Color(0xFF94A3B8),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: const TextStyle(
          color: Color(0xFF64748B),
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
      ),

      fontFamily: fontFamily,
    );
  }

  static Color getGlucoseColor(double glucoseLevel) {
    if (glucoseLevel < 54) {
      return glucoseCritical;
    } else if (glucoseLevel < 70) {
      return glucoseLow;
    } else if (glucoseLevel <= 180) {
      return glucoseNormal;
    } else if (glucoseLevel <= 250) {
      return glucoseHigh;
    } else {
      return glucoseVeryHigh;
    }
  }

  static String getGlucoseStatus(double glucoseLevel) {
    if (glucoseLevel < 54) {
      return 'Critical Low';
    } else if (glucoseLevel < 70) {
      return 'Low';
    } else if (glucoseLevel <= 180) {
      return 'In Range';
    } else if (glucoseLevel <= 250) {
      return 'High';
    } else {
      return 'Very High';
    }
  }

  static String getGlucoseAdvice(double glucoseLevel) {
    if (glucoseLevel < 54) {
      return 'Seek immediate medical attention';
    } else if (glucoseLevel < 70) {
      return 'Treat low blood sugar immediately';
    } else if (glucoseLevel <= 180) {
      return 'Keep up the good work!';
    } else if (glucoseLevel <= 250) {
      return 'Consider adjusting medication or diet';
    } else {
      return 'Contact your healthcare provider';
    }
  }

  static IconData getGlucoseIcon(double glucoseLevel) {
    if (glucoseLevel < 70) return Icons.trending_down_rounded;
    if (glucoseLevel > 180) return Icons.trending_up_rounded;
    return Icons.check_circle_rounded;
  }

  static Color getMoodColor(String mood) {
    switch (mood.toLowerCase()) {
      case 'great':
        return moodGreat;
      case 'good':
        return moodGood;
      case 'okay':
        return moodOkay;
      case 'tired':
        return moodTired;
      case 'stressed':
        return moodStressed;
      default:
        return moodOkay;
    }
  }

  static Color getGlucoseColorFromReading(bool isLow, bool isHigh) {
    if (isLow) return glucoseLow;
    if (isHigh) return glucoseHigh;
    return glucoseNormal;
  }

  static LinearGradient getGlucoseGradient(double glucoseLevel) {
    final color = getGlucoseColor(glucoseLevel);
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        color.withOpacity(0.1),
        color.withOpacity(0.05),
      ],
    );
  }
}
