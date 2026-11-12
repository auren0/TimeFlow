import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'motion.dart';

/// A user-selectable color story. Seeds feed the Material color harmonizer and
/// a calm tonal-spot scheme.
@immutable
class AppPalette {
  const AppPalette(this.id, this.name, this.seed);

  final String id;
  final String name;
  final Color seed;
}

const List<AppPalette> kPalettes = <AppPalette>[
  AppPalette('indigo', 'Индиго', Color(0xFF5B5BF6)),
  AppPalette('ocean', 'Океан', Color(0xFF0E9FDF)),
  AppPalette('mint', 'Мята', Color(0xFF12B886)),
  AppPalette('sunset', 'Закат', Color(0xFFF76707)),
  AppPalette('rose', 'Роза', Color(0xFFE64980)),
  AppPalette('violet', 'Сирень', Color(0xFF8B5CF6)),
  AppPalette('graphite', 'Графит', Color(0xFF64748B)),
];

AppPalette paletteForIndex(int index) =>
    kPalettes[index.clamp(0, kPalettes.length - 1)];

/// Radii used across the app. Kept compact for a calm, minimal surface.
abstract final class AppRadius {
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double hero = 24;
}

ThemeData buildAppTheme({
  required Brightness brightness,
  required Color seed,
  String? fontFamily,
  bool isOled = false,
}) {
  ColorScheme scheme = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: brightness,
    dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
  );
  if (brightness == Brightness.dark && isOled) {
    scheme = scheme.copyWith(
      surface: Colors.black,
      surfaceDim: Colors.black,
      surfaceBright: const Color(0xFF181818),
      surfaceContainerLowest: Colors.black,
      surfaceContainerLow: const Color(0xFF0C0C0C),
      surfaceContainer: const Color(0xFF141414),
      surfaceContainerHigh: const Color(0xFF1C1C1C),
      surfaceContainerHighest: const Color(0xFF242424),
    );
  }
  final ThemeData base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: fontFamily,
  );

  final bool isDark = brightness == Brightness.dark;
  final TextTheme textTheme = _buildTextTheme(
    base.textTheme,
    scheme,
    fontFamily,
  );

  final RoundedRectangleBorder buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(14),
  );
  final RoundedRectangleBorder indicatorShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(14),
  );
  final RoundedRectangleBorder chipShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(10),
  );
  final RoundedRectangleBorder cardShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppRadius.lg),
  );

  final ButtonStyle filled = FilledButton.styleFrom(
    shape: buttonShape,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    textStyle: textTheme.labelLarge,
    minimumSize: const Size(0, 44),
  );
  final ButtonStyle outlined = OutlinedButton.styleFrom(
    shape: buttonShape,
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    textStyle: textTheme.labelLarge,
    minimumSize: const Size(0, 44),
    side: BorderSide(color: scheme.outlineVariant),
  );
  final ButtonStyle text = TextButton.styleFrom(
    shape: buttonShape,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    textStyle: textTheme.labelLarge,
    minimumSize: const Size(0, 40),
  );

  return base.copyWith(
    textTheme: textTheme,
    scaffoldBackgroundColor: scheme.surface,
    canvasColor: scheme.surface,
    splashFactory: defaultTargetPlatform == TargetPlatform.android
        ? InkSparkle.splashFactory
        : InkRipple.splashFactory,
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    appBarTheme: AppBarThemeData(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.headlineSmall?.copyWith(
        color: scheme.onSurface,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
      ),
    ),
    cardTheme: CardThemeData(
      color: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: cardShape,
      clipBehavior: Clip.antiAlias,
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 64,
      elevation: 0,
      backgroundColor: scheme.surfaceContainer,
      surfaceTintColor: Colors.transparent,
      indicatorColor: scheme.primaryContainer,
      indicatorShape: indicatorShape,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      iconTheme: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
        final bool selected = states.contains(WidgetState.selected);
        return IconThemeData(
          size: 25,
          color: selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
        );
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((
        Set<WidgetState> states,
      ) {
        final bool selected = states.contains(WidgetState.selected);
        return textTheme.labelMedium?.copyWith(
          fontSize: 11,
          letterSpacing: 0,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
        );
      }),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: scheme.surfaceContainer,
      elevation: 0,
      indicatorColor: scheme.primaryContainer,
      useIndicator: true,
      indicatorShape: indicatorShape,
      selectedIconTheme: IconThemeData(
        size: 25,
        color: scheme.onPrimaryContainer,
      ),
      unselectedIconTheme: IconThemeData(
        size: 25,
        color: scheme.onSurfaceVariant,
      ),
      selectedLabelTextStyle: textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
      ),
      unselectedLabelTextStyle: textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w500,
        color: scheme.onSurfaceVariant,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(style: filled),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        shape: buttonShape,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: textTheme.labelLarge,
        minimumSize: const Size(0, 44),
        backgroundColor: scheme.secondaryContainer,
        foregroundColor: scheme.onSecondaryContainer,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(style: outlined),
    textButtonTheme: TextButtonThemeData(style: text),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(shape: const CircleBorder()),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStatePropertyAll<OutlinedBorder>(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
          EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        ),
        textStyle: WidgetStatePropertyAll<TextStyle?>(textTheme.labelLarge),
        backgroundColor: WidgetStateProperty.resolveWith<Color>((
          Set<WidgetState> states,
        ) {
          if (states.contains(WidgetState.selected)) {
            return scheme.secondaryContainer;
          }
          return scheme.surfaceContainerHigh;
        }),
        foregroundColor: WidgetStateProperty.resolveWith<Color>((
          Set<WidgetState> states,
        ) {
          if (states.contains(WidgetState.selected)) {
            return scheme.onSecondaryContainer;
          }
          return scheme.onSurfaceVariant;
        }),
        side: const WidgetStatePropertyAll<BorderSide>(BorderSide.none),
        visualDensity: VisualDensity.compact,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHigh,
      hintStyle: textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: chipShape,
      side: BorderSide.none,
      backgroundColor: scheme.surfaceContainerHigh,
      selectedColor: scheme.secondaryContainer,
      labelStyle: textTheme.labelMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
        if (states.contains(WidgetState.selected)) {
          return scheme.onPrimary;
        }
        return isDark ? scheme.surfaceContainerHighest : scheme.surface;
      }),
      trackColor: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
        if (states.contains(WidgetState.selected)) {
          return scheme.primary;
        }
        return scheme.surfaceContainerHighest;
      }),
      trackOutlineColor: const WidgetStatePropertyAll<Color>(
        Colors.transparent,
      ),
      thumbIcon: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
        if (states.contains(WidgetState.selected)) {
          return const Icon(FluentIcons.checkmark_24_regular, size: 16);
        }
        return null;
      }),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      titleTextStyle: textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      contentTextStyle: textTheme.bodyLarge?.copyWith(
        color: scheme.onSurfaceVariant,
        height: 1.45,
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      showDragHandle: true,
      dragHandleColor: scheme.onSurfaceVariant.withValues(alpha: 0.4),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      clipBehavior: Clip.antiAlias,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: scheme.onInverseSurface,
      ),
      actionTextColor: scheme.inversePrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      insetPadding: const EdgeInsets.all(16),
      elevation: 2,
    ),
    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 500),
      decoration: BoxDecoration(
        color: scheme.inverseSurface,
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      textStyle: textTheme.bodySmall?.copyWith(color: scheme.onInverseSurface),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant.withValues(alpha: 0.5),
      thickness: 1,
      space: 1,
    ),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      iconColor: scheme.onSurfaceVariant,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      linearTrackColor: scheme.surfaceContainerHighest,
      linearMinHeight: 6,
      circularTrackColor: scheme.surfaceContainerHighest,
    ),
    scrollbarTheme: ScrollbarThemeData(
      thickness: const WidgetStatePropertyAll<double>(8),
      radius: const Radius.circular(8),
      thumbColor: WidgetStatePropertyAll<Color>(
        scheme.outlineVariant.withValues(alpha: 0.7),
      ),
      crossAxisMargin: 4,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: scheme.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: scheme.primary,
      selectionColor: scheme.primary.withValues(alpha: 0.25),
      selectionHandleColor: scheme.primary,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        TargetPlatform.android: ExpressivePageTransitionsBuilder(),
        TargetPlatform.fuchsia: ExpressivePageTransitionsBuilder(),
        TargetPlatform.windows: ExpressivePageTransitionsBuilder(),
        TargetPlatform.linux: ExpressivePageTransitionsBuilder(),
      },
    ),
  );
}

TextTheme _buildTextTheme(
  TextTheme base,
  ColorScheme scheme,
  String? fontFamily,
) {
  final List<FontFeature> tabular = <FontFeature>[
    const FontFeature.tabularFigures(),
  ];
  return base
      .copyWith(
        displayLarge: base.displayLarge?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: -1.2,
          height: 1.05,
          fontFamily: fontFamily,
          fontFeatures: tabular,
        ),
        displayMedium: base.displayMedium?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: -0.9,
          height: 1.06,
          fontFamily: fontFamily,
          fontFeatures: tabular,
        ),
        displaySmall: base.displaySmall?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: -0.6,
          height: 1.1,
          fontFamily: fontFamily,
          fontFeatures: tabular,
        ),
        headlineLarge: base.headlineLarge?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: -0.4,
          fontFamily: fontFamily,
        ),
        headlineMedium: base.headlineMedium?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
          fontFamily: fontFamily,
        ),
        headlineSmall: base.headlineSmall?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
          fontFamily: fontFamily,
        ),
        titleLarge: base.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: -0.1,
          fontFamily: fontFamily,
        ),
        titleMedium: base.titleMedium?.copyWith(
          fontWeight: FontWeight.w500,
          letterSpacing: 0,
          fontFamily: fontFamily,
        ),
        titleSmall: base.titleSmall?.copyWith(
          fontWeight: FontWeight.w500,
          fontFamily: fontFamily,
        ),
        bodyLarge: base.bodyLarge?.copyWith(
          height: 1.4,
          fontFamily: fontFamily,
        ),
        bodyMedium: base.bodyMedium?.copyWith(
          height: 1.42,
          fontFamily: fontFamily,
        ),
        bodySmall: base.bodySmall?.copyWith(
          height: 1.35,
          fontFamily: fontFamily,
        ),
        labelLarge: base.labelLarge?.copyWith(
          fontWeight: FontWeight.w500,
          letterSpacing: 0.1,
          fontFamily: fontFamily,
        ),
        labelMedium: base.labelMedium?.copyWith(
          fontWeight: FontWeight.w500,
          letterSpacing: 0.15,
          fontFamily: fontFamily,
        ),
        labelSmall: base.labelSmall?.copyWith(
          fontWeight: FontWeight.w500,
          letterSpacing: 0.2,
          fontFamily: fontFamily,
        ),
      )
      .apply(
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
        fontFamily: fontFamily,
      );
}

/// A page transition that mimics the Material 3 Expressive push motion:
/// a short horizontal travel, a gentle scale-up and a quick fade.
class ExpressivePageTransitionsBuilder extends PageTransitionsBuilder {
  const ExpressivePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (route.isFirst) {
      return child;
    }
    final Animation<double> curved = CurvedAnimation(
      parent: animation,
      curve: AppMotion.emphasizedDecel,
      reverseCurve: AppMotion.emphasizedAccel,
    );
    final Animation<double> fade = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.0, 0.55, curve: Curves.easeOut),
    );
    return FadeTransition(
      opacity: fade,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.055, 0.0),
          end: Offset.zero,
        ).animate(curved),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.965, end: 1.0).animate(curved),
          child: child,
        ),
      ),
    );
  }
}
