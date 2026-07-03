import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'theme.dart';

/// Reusable Bottom Navigation Bar matching the custom brutalist design screenshots.
class BottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onTap;

  const BottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final borderColor = isLight ? AppTheme.border : AppTheme.darkBorder;
    final inactiveBgColor = isLight ? Colors.white : AppTheme.darkSurface;
    final inactiveTextColor = isLight ? Colors.black : Colors.white;

    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: inactiveBgColor,
        border: Border(
          top: BorderSide(color: borderColor, width: 1),
        ),
      ),
      child: Row(
        children: [
          _buildNavItem(0, Icons.grid_view_sharp, 'DASHBOARD', borderColor, inactiveBgColor, inactiveTextColor),
          _buildNavItem(1, Icons.mail_outlined, 'SMS JOBS', borderColor, inactiveBgColor, inactiveTextColor),
          _buildNavItem(2, Icons.description_outlined, 'LOGS', borderColor, inactiveBgColor, inactiveTextColor),
          _buildNavItem(3, Icons.settings_outlined, 'SETTINGS', borderColor, inactiveBgColor, inactiveTextColor),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData icon,
    String label,
    Color borderColor,
    Color inactiveBgColor,
    Color inactiveTextColor,
  ) {
    final isSelected = selectedIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primary : inactiveBgColor,
            border: Border(
              right: index < 3 ? BorderSide(color: borderColor, width: 1) : BorderSide.none,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : inactiveTextColor,
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.bebasNeue(
                  fontSize: 12,
                  letterSpacing: 0.8,
                  color: isSelected ? Colors.white : inactiveTextColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
