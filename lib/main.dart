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
    return ListenableBuilder(
      listenable: AppAppearance.listenable,
      builder: (context, _) {
        final theme = AppTheme.dark(
          accent: AppAppearance.accent.value,
          secondary: AppAppearance.secondary.value,
        );
        return MaterialApp(
          title: 'Kinktionary',
          debugShowCheckedModeBanner: false,
          theme: theme,
          darkTheme: theme,
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
      },
    );
  }
}
