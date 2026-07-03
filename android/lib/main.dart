import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'providers/app_state.dart';
import 'screens/setup_screen.dart';
import 'screens/dashboard_screen.dart';
import 'logo_painter.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Force portrait orientation
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Set system UI overlay style with transparent status bar
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
  ));

  runApp(const OpenRelayApp());
}

class OpenRelayApp extends StatelessWidget {
  const OpenRelayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState()..initialize(),
      child: Consumer<AppState>(
        builder: (context, appState, _) {
          return MaterialApp(
            title: 'OpenRelay',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme.copyWith(
              scaffoldBackgroundColor: appState.useWhiteTheme ? Colors.white : AppTheme.background,
              appBarTheme: AppTheme.lightTheme.appBarTheme.copyWith(
                backgroundColor: appState.useWhiteTheme ? Colors.white : AppTheme.background,
              ),
            ),
            themeMode: ThemeMode.light,
            routes: {
              '/setup': (_) => const SetupScreen(),
              '/dashboard': (_) => const DashboardScreen(),
            },
            home: const _AppRouter(),
          );
        },
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
            backgroundColor: appState.useWhiteTheme ? Colors.white : AppTheme.background,
            body: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(120, 120),
                        painter: AntennaLogoPainter(color: AppTheme.primary),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'OPENRELAY',
                        style: GoogleFonts.bebasNeue(
                          fontSize: 56,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: 50,
                        height: 4,
                        color: AppTheme.primary,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'RELIABLE. SECURE. REAL-TIME.',
                        style: GoogleFonts.roboto(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.0,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 60,
                    color: AppTheme.primary,
                    alignment: Alignment.center,
                    child: Text(
                      'CONNECT. DELIVER. AUTOMATE.',
                      style: GoogleFonts.roboto(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
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
