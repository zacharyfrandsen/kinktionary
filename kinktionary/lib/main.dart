import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'data_store.dart';
import 'firebase_options.dart';
import 'screens/age_gate_screen.dart';
import 'screens/home_shell.dart';
import 'widgets/splash_loading_screen.dart';

const _appCheckDebugEnabled = bool.fromEnvironment('APP_CHECK_DEBUG');
const _appCheckDebugToken = String.fromEnvironment('APP_CHECK_DEBUG_TOKEN');
final String? _sharedDebugToken =
    _appCheckDebugToken.isEmpty ? null : _appCheckDebugToken;

Future<void> _requestDebugAppCheckToken() async {
  try {
    await FirebaseAppCheck.instance.getToken();
  } on Object catch (error) {
    debugPrint('App Check debug token unavailable: $error');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const useDebugAppCheck = kDebugMode || _appCheckDebugEnabled;
  final isMobile = defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
  if (isMobile) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await FirebaseAppCheck.instance.activate(
      providerAndroid: useDebugAppCheck
          ? AndroidDebugProvider(debugToken: _sharedDebugToken)
          : const AndroidPlayIntegrityProvider(),
      providerApple: useDebugAppCheck
          ? AppleDebugProvider(debugToken: _sharedDebugToken)
          : const AppleAppAttestWithDeviceCheckFallbackProvider(),
    );
  }
  runApp(const KinktionaryApp());
  if (isMobile && useDebugAppCheck) {
    unawaited(_requestDebugAppCheckToken());
  }
}

class KinktionaryApp extends StatefulWidget {
  const KinktionaryApp({super.key});

  @override
  State<KinktionaryApp> createState() => _KinktionaryAppState();
}

class _KinktionaryAppState extends State<KinktionaryApp> {
  final DataStore store = DataStore();

  @override
  void initState() {
    super.initState();
    store.load();
  }

  @override
  void dispose() {
    store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFFA927FF);
    const mainText = Color(0xFFFFFFFF);

    // Near-black neutrals to match the wallpaper look.
    final darkScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
    ).copyWith(
      surface: const Color(0xFF0F0F0F),
      surfaceContainerLow: const Color(0xFF222226),
      surfaceContainer: const Color(0xFF222226),
      surfaceContainerHigh: const Color(0xFF222226),
    );
    final lightScheme = ColorScheme.fromSeed(seedColor: seed);

    ThemeData buildTheme(ColorScheme scheme) {
      final titleText = scheme.onSecondaryContainer;
      final baseTextTheme = (scheme.brightness == Brightness.dark
              ? ThemeData.dark().textTheme
              : ThemeData.light().textTheme)
          .apply(bodyColor: mainText, displayColor: titleText);
      final textTheme = baseTextTheme.copyWith(
        headlineLarge: baseTextTheme.headlineLarge?.copyWith(color: titleText),
        headlineMedium:
            baseTextTheme.headlineMedium?.copyWith(color: titleText),
        headlineSmall: baseTextTheme.headlineSmall?.copyWith(color: titleText),
        titleLarge: baseTextTheme.titleLarge?.copyWith(color: titleText),
        titleMedium: baseTextTheme.titleMedium?.copyWith(color: titleText),
        titleSmall: baseTextTheme.titleSmall?.copyWith(color: titleText),
      );

      return ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        textTheme: textTheme,
        appBarTheme: AppBarTheme(
          titleTextStyle: textTheme.titleLarge,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
        ),
        listTileTheme: ListTileThemeData(
          titleTextStyle: textTheme.titleMedium,
          subtitleTextStyle: textTheme.bodyMedium,
        ),
        cardTheme: CardThemeData(
          color: scheme.surfaceContainerLow,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: scheme.outlineVariant),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: scheme.surface.withAlpha(0xDD),
          surfaceTintColor: Colors.transparent,
          labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
              color: states.contains(WidgetState.selected)
                  ? scheme.onSecondaryContainer
                  : scheme.onSurfaceVariant)),
        ),
      );
    }

    return MaterialApp(
      title: 'Kinktionary',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(lightScheme),
      darkTheme: buildTheme(darkScheme),
      themeMode: ThemeMode.dark,
      home: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          if (!store.loaded) {
            return const SplashLoadingScreen();
          }
          if (!store.ageConfirmed) return AgeGateScreen(store: store);
          return HomeShell(store: store);
        },
      ),
    );
  }
}
