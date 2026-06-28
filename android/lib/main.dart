import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/app_state.dart';
import 'screens/setup_screen.dart';
import 'screens/dashboard_screen.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Force portrait orientation
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Set system UI overlay style for dark theme
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppTheme.surface,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  runApp(const OpenRelayApp());
}

class OpenRelayApp extends StatelessWidget {
  const OpenRelayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState()..initialize(),
      child: MaterialApp(
        title: 'OpenRelay',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        routes: {
          '/setup': (_) => const SetupScreen(),
          '/dashboard': (_) => const DashboardScreen(),
        },
        home: const _AppRouter(),
      ),
    );
  }
}

/// Routes to the correct screen based on setup state.
class _AppRouter extends StatelessWidget {
  const _AppRouter();

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        // Show loading while initializing
        if (!appState.initialized) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.primary, AppTheme.accent],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.cell_tower_rounded, size: 32, color: Colors.white),
                  ),
                  const SizedBox(height: 24),
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
              ),
            ),
          );
        }

        // Route based on setup completion
        if (appState.isSetupComplete) {
          return const DashboardScreen();
        } else {
          return const SetupScreen();
        }
      },
    );
  }
}
