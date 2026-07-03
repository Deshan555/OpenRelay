import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'providers/app_state.dart';
import 'services/websocket_service.dart' show WsConnectionState;
import 'theme.dart';

/// Reusable OpenRelay Header Bar matching the brutalist design screenshots.
class HeaderBar extends StatelessWidget implements PreferredSizeWidget {
  const HeaderBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        final state = appState.connectionState;
        final isRunning = appState.serviceRunning;

        Color badgeColor;
        String statusText;

        if (!isRunning) {
          badgeColor = AppTheme.offline;
          statusText = 'OFFLINE';
        } else {
          switch (state) {
            case WsConnectionState.connected:
              badgeColor = AppTheme.online;
              statusText = 'ONLINE';
              break;
            case WsConnectionState.connecting:
              badgeColor = AppTheme.connecting;
              statusText = 'CONNECTING';
              break;
            case WsConnectionState.disconnected:
              badgeColor = AppTheme.offline;
              statusText = 'OFFLINE';
              break;
          }
        }

        return SafeArea(
          bottom: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 12.0, bottom: 12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'OPENRELAY',
                      style: GoogleFonts.bebasNeue(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).brightness == Brightness.light
                            ? Colors.black
                            : Colors.white,
                        letterSpacing: 1.0,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      color: badgeColor,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            statusText,
                            style: GoogleFonts.roboto(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                height: 1,
                color: Theme.of(context).brightness == Brightness.light
                    ? AppTheme.border
                    : AppTheme.darkBorder,
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(68.0);
}
