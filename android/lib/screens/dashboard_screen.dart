import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../services/websocket_service.dart' show WsConnectionState;
import '../theme.dart';

/// Main dashboard screen — shows device status, stats, and recent SMS jobs.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with TickerProviderStateMixin {
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    // Refresh data on screen load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().refreshJobStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.primary, AppTheme.accent],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.cell_tower_rounded, size: 18, color: Colors.white),
                ),
                const SizedBox(width: 12),
                const Text('OpenRelay'),
              ],
            ),
            actions: [
              // Service toggle
              _buildServiceToggle(appState),
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) {
                  if (value == 'settings') _showSettings(appState);
                  if (value == 'logs') _showLogs(appState);
                  if (value == 'reset') _confirmReset(appState);
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'settings', child: Text('Settings')),
                  const PopupMenuItem(value: 'logs', child: Text('View Logs')),
                  const PopupMenuItem(value: 'reset', child: Text('Reset Setup')),
                ],
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () => appState.refreshJobStats(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildConnectionCard(appState),
                  const SizedBox(height: 16),
                  _buildStatsGrid(appState),
                  const SizedBox(height: 16),
                  _buildDeviceInfoCard(appState),
                  const SizedBox(height: 16),
                  _buildRecentJobsCard(appState),
                ],
              ),
            ),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _selectedTab,
            onDestinationSelected: (idx) => setState(() => _selectedTab = idx),
            backgroundColor: AppTheme.surface,
            indicatorColor: AppTheme.primary.withValues(alpha: 0.2),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
              NavigationDestination(icon: Icon(Icons.sms_rounded), label: 'SMS Jobs'),
              NavigationDestination(icon: Icon(Icons.terminal_rounded), label: 'Logs'),
            ],
          ),
        );
      },
    );
  }

  Widget _buildServiceToggle(AppState appState) {
    final isRunning = appState.serviceRunning;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        onTap: () => appState.toggleService(),
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: (isRunning ? AppTheme.accentGreen : AppTheme.accentRed).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: (isRunning ? AppTheme.accentGreen : AppTheme.accentRed).withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isRunning ? AppTheme.accentGreen : AppTheme.accentRed,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                isRunning ? 'ON' : 'OFF',
                style: TextStyle(
                  color: isRunning ? AppTheme.accentGreen : AppTheme.accentRed,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionCard(AppState appState) {
    final state = appState.connectionState;
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (state) {
      case WsConnectionState.connected:
        statusColor = AppTheme.online;
        statusText = 'Connected';
        statusIcon = Icons.cloud_done_rounded;
        break;
      case WsConnectionState.connecting:
        statusColor = AppTheme.connecting;
        statusText = 'Connecting...';
        statusIcon = Icons.cloud_sync_rounded;
        break;
      case WsConnectionState.disconnected:
        statusColor = appState.serviceRunning ? AppTheme.accentRed : AppTheme.textMuted;
        statusText = appState.serviceRunning ? 'Disconnected' : 'Service Stopped';
        statusIcon = Icons.cloud_off_rounded;
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            statusColor.withValues(alpha: 0.12),
            statusColor.withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(statusIcon, color: statusColor, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  appState.serverUrl.isNotEmpty
                      ? appState.serverUrl
                      : 'No server configured',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (state == WsConnectionState.connecting)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildStatsGrid(AppState appState) {
    final sent = appState.jobStats['SENT'] ?? 0;
    final failed = appState.jobStats['FAILED'] ?? 0;
    final pending = appState.jobStats['PENDING'] ?? 0;
    final today = appState.todayCount;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: [
        _statCard('Today', '$today', Icons.today_rounded, AppTheme.accent),
        _statCard('Sent', '$sent', Icons.check_circle_rounded, AppTheme.accentGreen),
        _statCard('Failed', '$failed', Icons.error_rounded, AppTheme.accentRed),
        _statCard('Pending', '$pending', Icons.schedule_rounded, AppTheme.pending),
      ],
    ).animate().fadeIn(delay: 100.ms, duration: 400.ms);
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 22),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
          Text(
            label,
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceInfoCard(AppState appState) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.smartphone_rounded, color: AppTheme.textSecondary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Device Info',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _infoRow('Name', appState.deviceName),
          _infoRow('UUID', appState.deviceUuid),
          _infoRow('Model', appState.deviceModel),
          _infoRow('Android', appState.androidVersion),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 12),
          // Battery and Signal
          Row(
            children: [
              Expanded(
                child: _sensorIndicator(
                  icon: _getBatteryIcon(appState.battery),
                  label: 'Battery',
                  value: '${appState.battery}%',
                  color: appState.battery > 20 ? AppTheme.accentGreen : AppTheme.accentRed,
                  progress: appState.battery / 100,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _sensorIndicator(
                  icon: Icons.signal_cellular_alt_rounded,
                  label: 'Signal',
                  value: appState.signal > 0 ? '${appState.signal}' : '--',
                  color: AppTheme.accent,
                  progress: appState.signal > 0 ? appState.signal / 4 : 0,
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms, duration: 400.ms);
  }

  IconData _getBatteryIcon(int level) {
    if (level > 80) return Icons.battery_full_rounded;
    if (level > 60) return Icons.battery_5_bar_rounded;
    if (level > 40) return Icons.battery_4_bar_rounded;
    if (level > 20) return Icons.battery_2_bar_rounded;
    return Icons.battery_alert_rounded;
  }

  Widget _sensorIndicator({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required double progress,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: color)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            backgroundColor: AppTheme.surfaceLight,
            color: color,
            minHeight: 4,
          ),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : '--',
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentJobsCard(AppState appState) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.history_rounded, color: AppTheme.textSecondary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Recent SMS Jobs',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => appState.refreshJobStats(),
                child: const Text('Refresh'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (appState.recentJobs.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.inbox_rounded, size: 40, color: AppTheme.textMuted),
                    const SizedBox(height: 8),
                    Text(
                      'No SMS jobs yet',
                      style: TextStyle(color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
            )
          else
            ...appState.recentJobs.take(10).map((job) => _jobTile(job)),
        ],
      ),
    ).animate().fadeIn(delay: 300.ms, duration: 400.ms);
  }

  Widget _jobTile(Map<String, dynamic> job) {
    final status = job['status'] as String? ?? 'UNKNOWN';
    Color statusColor;
    IconData statusIcon;

    switch (status) {
      case 'SENT':
        statusColor = AppTheme.accentGreen;
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'FAILED':
        statusColor = AppTheme.accentRed;
        statusIcon = Icons.error_rounded;
        break;
      case 'SENDING':
        statusColor = AppTheme.accent;
        statusIcon = Icons.send_rounded;
        break;
      default:
        statusColor = AppTheme.pending;
        statusIcon = Icons.schedule_rounded;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  job['recipient'] as String? ?? 'Unknown',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                Text(
                  job['message'] as String? ?? '',
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: statusColor,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSettings(AppState appState) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Settings',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 24),
            _infoRow('Server', appState.serverUrl),
            _infoRow('UUID', appState.deviceUuid),
            _infoRow('Name', appState.deviceName),
            _infoRow('Version', '0.1.0'),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _showLogs(AppState appState) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Logs',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: appState.logs.isEmpty
                    ? const Center(child: Text('No logs yet', style: TextStyle(color: AppTheme.textMuted)))
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: appState.logs.length,
                        itemBuilder: (_, index) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            appState.logs[index],
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmReset(AppState appState) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard,
        title: const Text('Reset Setup?'),
        content: const Text(
          'This will clear all saved data and return to the setup screen. The device will need to be re-registered.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final navigator = Navigator.of(context);
              navigator.pop();
              appState.resetSetup().then((_) {
                navigator.pushReplacementNamed('/setup');
              });
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentRed),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}
