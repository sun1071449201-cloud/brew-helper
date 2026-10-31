import 'package:flutter/material.dart';

/// 全局 Material 3 主题：统一配色、卡片圆角/阴影/边距、字阶与页面过渡动画。
/// 支持多色板：啤酒琥珀（默认）、麦芽金、酒花绿、窖藏蓝灰。
class AppTheme {
  static const _seeds = <String, Color>{
    'amber': Color(0xFF9A5B13),
    'malt': Color(0xFF8D6E00),
    'hop': Color(0xFF4E6B2A),
    'slate': Color(0xFF44546A),
  };

  static const seedNames = {
    'amber': '啤酒琥珀',
    'malt': '麦芽金',
    'hop': '酒花绿',
    'slate': '窖藏蓝灰',
  };

  static Color seedOf(String name) => _seeds[name] ?? _seeds['amber']!;
  static Color seed = _seeds['amber']!;

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme =
        ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
    final isDark = brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      // 页面切换平滑过渡（Android 用缩放淡入）。
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      // 卡片统一：14 圆角、低阴影、留白舒适。
      cardTheme: CardTheme(
        elevation: isDark ? 1.0 : 1.5,
        shadowColor: scheme.shadow.withOpacity(0.20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        clipBehavior: Clip.antiAlias,
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
      ),
      // 字阶：标题层级清晰，正文舒展。
      textTheme: Typography.blackMountainView.copyWith(
        displaySmall: const TextStyle(
            fontSize: 34, fontWeight: FontWeight.w700, height: 1.25),
        headlineSmall: const TextStyle(
            fontSize: 22, fontWeight: FontWeight.w700, height: 1.3),
        titleLarge: const TextStyle(
            fontSize: 17, fontWeight: FontWeight.w600, height: 1.35),
        titleMedium: const TextStyle(
            fontSize: 15, fontWeight: FontWeight.w600, height: 1.4),
        titleSmall: const TextStyle(
            fontSize: 13.5, fontWeight: FontWeight.w600, height: 1.4),
        bodyLarge: const TextStyle(fontSize: 15.5, height: 1.6),
        bodyMedium: const TextStyle(fontSize: 14, height: 1.5),
        bodySmall: const TextStyle(fontSize: 12, height: 1.45),
        labelLarge: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w600, height: 1.3),
        labelMedium: const TextStyle(fontSize: 11.5, height: 1.3),
        labelSmall: const TextStyle(fontSize: 10.5, height: 1.25),
      ).apply(
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withOpacity(0.7),
        thickness: 1,
        space: 20,
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
      chipTheme: ChipThemeData(
        side: BorderSide(color: scheme.outlineVariant.withOpacity(0.6)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
