import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';
import '../header_bar.dart';
import '../logo_painter.dart';

/// A static screen displaying application information, version metadata, and developer credits.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final borderColor = isLight ? AppTheme.border : AppTheme.darkBorder;

    return Scaffold(
      appBar: const HeaderBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Back button
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.arrow_back, size: 16, color: Colors.black),
                  const SizedBox(width: 8),
                  Text(
                    'BACK TO SETTINGS',
                    style: GoogleFonts.bebasNeue(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              'ABOUT OPENRELAY',
              style: GoogleFonts.bebasNeue(
                fontSize: 42,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
                color: Colors.black,
              ),
            ),
            Text(
              'Self-hosted cellular SMS gateway companion.',
              style: GoogleFonts.roboto(
                color: Colors.black54,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 24),

            // Branding Section with Large Antenna Logo
            Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: borderColor, width: 1.5),
                ),
                child: Column(
                  children: [
                    CustomPaint(
                      size: const Size(80, 80),
                      painter: AntennaLogoPainter(color: AppTheme.primary),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'OPENRELAY companion',
                      style: GoogleFonts.bebasNeue(
                        fontSize: 22,
                        letterSpacing: 1.0,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'VER 0.1.0 (BETA)',
                      style: GoogleFonts.roboto(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Project Description static card
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: borderColor, width: 1.0),
              ),
              child: Text(
                'OpenRelay turns your spare Android device into a programmatically accessible SMS modem gateway. By running a local WebSocket service client, you can send, receive, and query messages in real time using standard developer APIs (REST, WebSocket, GraphQL) without any subscription costs.',
                style: GoogleFonts.roboto(
                  fontSize: 13,
                  height: 1.5,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Application Details Table
            Text(
              'APPLICATION DETAILS',
              style: GoogleFonts.bebasNeue(
                fontSize: 18,
                letterSpacing: 0.8,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),

            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: borderColor, width: 1),
              ),
              child: Column(
                children: [
                  _buildAboutRow('APPLICATION NAME', 'OpenRelay Mobile', borderColor),
                  _buildAboutRow('BUILD VERSION', '0.1.0+1', borderColor),
                  _buildAboutRow('DEVELOPER', 'OpenRelay Team', borderColor),
                  _buildAboutRow('LICENSE', 'Apache License 2.0', borderColor),
                  _buildAboutRow('GITHUB REPOSITORY', 'github.com/openrelay/app', borderColor),
                  _buildAboutRow('OFFICIAL WEBSITE', 'openrelay.dev', borderColor, isLast: true),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Copyright notice
            Center(
              child: Text(
                '© 2026 OpenRelay Project. All rights reserved.',
                style: GoogleFonts.roboto(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutRow(String label, String value, Color borderColor, {bool isLast = false}) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: isLast ? BorderSide.none : BorderSide(color: borderColor, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 140,
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: borderColor, width: 0.5),
              ),
            ),
            child: Text(
              label,
              style: GoogleFonts.bebasNeue(
                fontSize: 11,
                letterSpacing: 0.5,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
              child: Text(
                value,
                style: GoogleFonts.roboto(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
