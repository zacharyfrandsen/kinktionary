import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'appearance.dart';
import 'data_store.dart';
import 'firebase_options.dart';
import 'screens/age_gate_screen.dart';
import 'screens/home_shell.dart';
import 'theme.dart';
import 'widgets/pattern_background.dart';
import 'widgets/splash_loading_screen.dart';

const _appCheckDebugEnabled = bool.fromEnvironment('APP_CHECK_DEBUG');
const _appCheckDebugToken = String.fromEnvironment('APP_CHECK_DEBUG_TOKEN');

/// reCAPTCHA site key registered for the web app in Firebase App Check.
/// Pass it with `--dart-define=APP_CHECK_RECAPTCHA_SITE_KEY=...`; without one,
/// the web build starts without App Check rather than failing every request.
const _webAppCheckSiteKey =
    String.fromEnvironment('APP_CHECK_RECAPTCHA_SITE_KEY');
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
  final isMobile = !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  // Every platform initialises Firebase, including the web build, so the
  // website runs the same auth, Firestore and storage code as the app.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  if (kIsWeb) {
    if (_webAppCheckSiteKey.isNotEmpty) {
      await FirebaseAppCheck.instance.activate(
        providerWeb: ReCaptchaV3Provider(_webAppCheckSiteKey),
      );
    } else if (useDebugAppCheck) {
      // A registered token skips the console round-trip; without one the SDK
      // generates a token and prints it so it can be registered by hand.
      await FirebaseAppCheck.instance.activate(
        providerWeb: WebDebugProvider(debugToken: _sharedDebugToken),
      );
    } else {
      debugPrint('App Check is not active on web: no reCAPTCHA site key was '
          'supplied via APP_CHECK_RECAPTCHA_SITE_KEY.');
    }
  } else if (isMobile) {
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
  /// Pre-loaded state for tests and benchmarks; the app builds its own when
  /// nothing is passed in.
  final DataStore? store;

  const KinktionaryApp({super.key, this.store});

  @override
  State<KinktionaryApp> createState() => _KinktionaryAppState();
}

class _KinktionaryAppState extends State<KinktionaryApp> {
  late final DataStore store = widget.store ?? DataStore();

  /// Building a theme costs milliseconds and hands every widget below a new
  /// ThemeData, so it is rebuilt only when a colour actually changes.
  ThemeData? _theme;
  Color? _themeAccent;
  Color? _themeSecondary;

  @override
  void initState() {
    super.initState();
    if (!store.loaded) store.load();
  }

  @override
  void dispose() {
    store.dispose();
    super.dispose();
  }

  ThemeData _currentTheme() {
    final accent = AppAppearance.accent.value;
    final secondary = AppAppearance.secondary.value;
    final cached = _theme;
    if (cached != null &&
        accent == _themeAccent &&
        secondary == _themeSecondary) {
      return cached;
    }
    _themeAccent = accent;
    _themeSecondary = secondary;
    return _theme = AppTheme.dark(accent: accent, secondary: secondary);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppAppearance.listenable,
      builder: (context, _) {
        final theme = _currentTheme();
        return MaterialApp(
          title: 'Kinktionary',
          debugShowCheckedModeBanner: false,
          theme: theme,
          darkTheme: theme,
          themeMode: ThemeMode.dark,
          // One wallpaper for the whole app, above the navigator: every screen
          // is a transparent Scaffold over this same surface, so scrolling any
          // list moves it and switching section picks up where it left off.
          builder: (context, child) => PatternBackground(
            child: child ?? const SizedBox.shrink(),
          ),
          home: _StoreGate(store: store),
        );
      },
    );
  }
}

/// Chooses between the splash, the age gate and the shell.
///
/// Each screen is built once and then reused, so a store notification costs an
/// identity check here instead of rebuilding every screen in the app.
class _StoreGate extends StatefulWidget {
  final DataStore store;
  const _StoreGate({required this.store});

  @override
  State<_StoreGate> createState() => _StoreGateState();
}

class _StoreGateState extends State<_StoreGate> {
  late final Widget _splash = SplashLoadingScreen(store: widget.store);
  late final Widget _ageGate = AgeGateScreen(store: widget.store);
  late final Widget _shell = HomeShell(store: widget.store);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        if (!widget.store.loaded) return _splash;
        if (!widget.store.ageConfirmed) return _ageGate;
        return _shell;
      },
    );
  }
}
