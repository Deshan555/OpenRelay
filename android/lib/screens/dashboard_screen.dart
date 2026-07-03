import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../providers/app_state.dart';
import '../services/database.dart';
import '../services/websocket_service.dart' show WsConnectionState;
import '../theme.dart';
import '../header_bar.dart';
import '../bottom_nav_bar.dart';
import 'job_details_screen.dart';
import 'about_screen.dart';

/// Main dashboard screen supporting Dashboard, SMS Jobs, Logs, and Settings.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedTab = 0;

  // SMS Jobs tab states
  String _jobsSearchQuery = '';
  String _selectedJobFilter = 'ALL';
  final List<String> _jobFilters = ['ALL', 'SENT', 'FAILED', 'PENDING', 'SCHEDULED'];

  // Logs tab states
  String _logsSearchQuery = '';
  String _selectedLogLevel = 'ALL LEVELS';
  final List<String> _logLevels = ['ALL LEVELS', 'INFO', 'WARN', 'ERROR'];
  DateTime _selectedLogDate = DateTime.now();

  // Settings states
  int _connectionTimeoutSeconds = 20;
  bool _autoReconnect = true;
  int _retryAttempts = 3;

  @override
  void initState() {
    super.initState();
    // Refresh stats on load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().refreshJobStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        return Scaffold(
          appBar: const HeaderBar(),
          body: Column(
            children: [
              Expanded(
                child: _buildSelectedTabContent(appState),
              ),
            ],
          ),
          bottomNavigationBar: BottomNavBar(
            selectedIndex: _selectedTab,
            onTap: (index) {
              setState(() {
                _selectedTab = index;
              });
            },
          ),
        );
      },
    );
  }

  Widget _buildSelectedTabContent(AppState appState) {
    switch (_selectedTab) {
      case 0:
        return _buildDashboardTab(appState);
      case 1:
        return _buildSmsJobsTab(appState);
      case 2:
        return _buildLogsTab(appState);
      case 3:
        return _buildSettingsTab(appState);
      default:
        return _buildDashboardTab(appState);
    }
  }

  // ==========================================
  // DASHBOARD TAB
  // ==========================================
  Widget _buildDashboardTab(AppState appState) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final borderColor = isLight ? AppTheme.border : AppTheme.darkBorder;
    final isRunning = appState.serviceRunning;
    final state = appState.connectionState;

    String statusText = 'OFFLINE';
    if (isRunning) {
      switch (state) {
        case WsConnectionState.connected:
          statusText = 'ONLINE';
          break;
        case WsConnectionState.connecting:
          statusText = 'CONNECTING';
          break;
        case WsConnectionState.disconnected:
          statusText = 'OFFLINE';
          break;
      }
    }

    final sent = appState.jobStats['SENT'] ?? 0;
    final failed = appState.jobStats['FAILED'] ?? 0;
    final pending = appState.jobStats['PENDING'] ?? 0;
    final today = appState.todayCount;

    return RefreshIndicator(
      onRefresh: () => appState.refreshJobStats(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // SERVICE STATUS TITLE
            Text(
              'SERVICE',
              style: GoogleFonts.bebasNeue(
                fontSize: 42,
                fontWeight: FontWeight.bold,
                height: 0.9,
                color: Colors.black,
              ),
            ),
            Text(
              'STATUS',
              style: GoogleFonts.bebasNeue(
                fontSize: 42,
                fontWeight: FontWeight.bold,
                height: 0.9,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 16),

            // CURRENT ENDPOINT AND OFFLINE STATUS ROW
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left column: Endpoint details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CURRENT ENDPOINT',
                        style: GoogleFonts.roboto(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        appState.serverUrl.isNotEmpty
                            ? appState.serverUrl
                            : 'https://f7c8-203-189-188-227.ngrok-free.app',
                        style: GoogleFonts.roboto(
                          fontSize: 13,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                // Right column: Giant clickable status
                GestureDetector(
                  onTap: () => appState.toggleService(),
                  child: Text(
                    statusText,
                    style: GoogleFonts.bebasNeue(
                      fontSize: 56,
                      fontWeight: FontWeight.bold,
                      height: 0.9,
                      color: Colors.black,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(height: 1, color: borderColor),
            const SizedBox(height: 16),

            // 4 STAT COLUMNS (TODAY, SENT, FAILED, PENDING)
            IntrinsicHeight(
              child: Row(
                children: [
                  _buildStatColumn('TODAY', '$today', false, borderColor),
                  Container(width: 1, color: borderColor),
                  _buildStatColumn('SENT', '$sent', false, borderColor),
                  Container(width: 1, color: borderColor),
                  _buildStatColumn('FAILED', '$failed', true, borderColor),
                  Container(width: 1, color: borderColor),
                  _buildStatColumn('PENDING', '$pending', false, borderColor),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(height: 1, color: borderColor),
            const SizedBox(height: 24),

            // DEVICE STATUS HEADER
            Text(
              'DEVICE STATUS',
              style: GoogleFonts.bebasNeue(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 16),

            // DEVICE STATUS TWO COLUMNS (BATTERY | SIGNAL STRENGTH)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Column: Battery
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'BATTERY',
                          style: GoogleFonts.roboto(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 8),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${appState.battery > 0 ? appState.battery : 64}%',
                            style: GoogleFonts.bebasNeue(
                              fontSize: 64,
                              fontWeight: FontWeight.bold,
                              height: 0.9,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Flat Battery Bar (Red left, Black right)
                        _buildBatteryBar(appState.battery > 0 ? appState.battery : 64),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  // Middle vertical divider
                  Container(width: 1, color: borderColor),
                  const SizedBox(width: 20),
                  // Right Column: Signal Strength
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SIGNAL STRENGTH',
                          style: GoogleFonts.roboto(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Signal strength bars
                        _buildSignalBars(appState.signal),
                        const SizedBox(height: 16),
                        Text(
                          appState.signal > 0 ? '${appState.signal}' : '--',
                          style: GoogleFonts.bebasNeue(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Container(height: 1, color: borderColor),
            const SizedBox(height: 24),

            // HOW IT WORKS static guide widget
            Text(
              'HOW IT WORKS',
              style: GoogleFonts.bebasNeue(
                fontSize: 18,
                letterSpacing: 0.8,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: borderColor, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStepRow('1', 'START SERVICE', 'Click the offline/online status text to activate the background WebSocket client connectivity listener.'),
                  const SizedBox(height: 12),
                  _buildStepRow('2', 'CONNECT API', 'Integrate client applications using the REST, GraphQL, or WebSocket endpoints.'),
                  const SizedBox(height: 12),
                  _buildStepRow('3', 'RELAY MESSAGES', 'Received SMS jobs will be queued locally and sent programmatically via your device cellular connection.'),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildStepRow(String num, String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppTheme.primary,
            border: Border.all(color: Colors.black, width: 1),
          ),
          child: Text(
            num,
            style: GoogleFonts.bebasNeue(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.roboto(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: GoogleFonts.roboto(
                  fontSize: 11,
                  color: Colors.black54,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatColumn(String label, String value, bool isRedBar, Color borderColor) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                label,
                style: GoogleFonts.roboto(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                  color: Colors.black,
                ),
              ),
            ),
            const SizedBox(height: 12),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: GoogleFonts.bebasNeue(
                  fontSize: 64,
                  fontWeight: FontWeight.bold,
                  height: 0.9,
                  color: Colors.black,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Short horizontal bar
            Container(
              width: 28,
              height: 4,
              color: isRedBar ? AppTheme.primary : Colors.black,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBatteryBar(int battery) {
    final int redFlex = battery.clamp(0, 100);
    final int blackFlex = 100 - redFlex;

    return SizedBox(
      height: 6,
      child: Row(
        children: [
          if (redFlex > 0)
            Expanded(
              flex: redFlex,
              child: Container(
                color: AppTheme.primary,
              ),
            ),
          if (blackFlex > 0)
            Expanded(
              flex: blackFlex,
              child: Container(
                color: Colors.black,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSignalBars(int signal) {
    // Determine how many bars are filled
    // If signal <= 0 (or default), fill 3 bars to match the SM-G981N offline screen.
    final int filled = signal > 0 ? signal : 3;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(4, (index) {
        final double barHeight = 8.0 + (index * 6.0);
        final bool isFilled = index < filled;
        return Padding(
          padding: const EdgeInsets.only(right: 3.0),
          child: Container(
            width: 4.5,
            height: barHeight,
            color: isFilled ? Colors.black : Colors.grey.shade300,
          ),
        );
      }),
    );
  }

  // ==========================================
  // SMS JOBS TAB
  // ==========================================
  Widget _buildSmsJobsTab(AppState appState) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final borderColor = isLight ? AppTheme.border : AppTheme.darkBorder;

    // Filter jobs
    final filteredJobs = appState.recentJobs.where((job) {
      final recipient = (job['recipient'] as String? ?? '').toLowerCase();
      final msg = (job['message'] as String? ?? '').toLowerCase();
      final status = (job['status'] as String? ?? 'PENDING');
      final query = _jobsSearchQuery.toLowerCase();

      final matchesSearch = recipient.contains(query) || msg.contains(query);
      final matchesFilter = _selectedJobFilter == 'ALL' || status == _selectedJobFilter;

      return matchesSearch && matchesFilter;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 20, right: 20, top: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SMS JOBS',
                      style: GoogleFonts.bebasNeue(
                        fontSize: 42,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: Colors.black,
                      ),
                    ),
                    Text(
                      'Monitor and manage all SMS messages in real time.',
                      style: GoogleFonts.roboto(
                        color: Colors.black54,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: () => _showNewSmsJobDialog(appState),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                child: Text(
                  '+ NEW SMS JOB',
                  style: GoogleFonts.bebasNeue(fontSize: 14, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Filter Tabs row (Image 3 layout)
        Container(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: borderColor, width: 0.5),
              bottom: BorderSide(color: borderColor, width: 0.5),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Row(
            children: _jobFilters.map((filter) {
              final int count = _getJobCountForFilter(appState, filter);
              final bool isSelected = _selectedJobFilter == filter;

              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedJobFilter = filter),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    decoration: BoxDecoration(
                      border: Border(
                        left: filter == _jobFilters.first
                            ? BorderSide(color: borderColor, width: 0.5)
                            : BorderSide.none,
                        right: BorderSide(color: borderColor, width: 0.5),
                        bottom: isSelected ? const BorderSide(color: AppTheme.primary, width: 3.0) : BorderSide.none,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            filter,
                            style: GoogleFonts.bebasNeue(
                              fontSize: 14,
                              color: isSelected ? AppTheme.primary : Colors.grey.shade600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$count',
                          style: GoogleFonts.roboto(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? AppTheme.primary : Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),

        // Search and Filter fields side-by-side
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: TextField(
                    style: GoogleFonts.roboto(fontSize: 13, color: Colors.black),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search, size: 18),
                      hintText: 'Search by number or message',
                      hintStyle: GoogleFonts.roboto(fontSize: 13, color: Colors.grey.shade600),
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.zero,
                        borderSide: BorderSide(color: borderColor),
                      ),
                    ),
                    onChanged: (val) => setState(() => _jobsSearchQuery = val),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  // Toggle dropdown or simple context menu
                  _showFilterSelectMenu(context);
                },
                child: Container(
                  height: 46,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: borderColor, width: 1),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.filter_list, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        'FILTER',
                        style: GoogleFonts.bebasNeue(fontSize: 12, letterSpacing: 0.5),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.keyboard_arrow_down, size: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Jobs Table headers
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: borderColor, width: 1),
                bottom: BorderSide(color: borderColor, width: 1),
              ),
            ),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  _buildTableHeaderCell('DATE & TIME', 90, borderColor),
                  _buildTableHeaderCell('RECIPIENT', 85, borderColor),
                  Expanded(
                    child: _buildTableHeaderCell('MESSAGE', 0, borderColor, isDividerRight: false),
                  ),
                  _buildTableHeaderCell('STATUS', 85, borderColor, isDividerLeft: true),
                ],
              ),
            ),
          ),
        ),

        // Jobs List (rows)
        Expanded(
          child: filteredJobs.isEmpty
              ? Center(
                  child: Text(
                    'No jobs found matching criteria.',
                    style: GoogleFonts.roboto(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  itemCount: filteredJobs.length,
                  itemBuilder: (context, index) {
                    final job = filteredJobs[index];
                    final String rawDate = job['created_at'] as String? ?? '';
                    String formattedTime = '';
                    if (rawDate.isNotEmpty) {
                      try {
                        final dt = DateTime.parse(rawDate);
                        formattedTime = '${dt.day}/${dt.month}/${dt.year}\n${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
                      } catch (_) {
                        formattedTime = rawDate;
                      }
                    }

                    final String recipient = job['recipient'] as String? ?? '--';
                    final String msg = job['message'] as String? ?? '';
                    final String status = job['status'] as String? ?? 'PENDING';

                    final bool isSent = status == 'SENT';
                    final bool isFailed = status == 'FAILED';

                    return GestureDetector(
                      onTap: () async {
                        // Navigate to details screen
                        final tabIndex = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SmsJobDetailsScreen(job: job),
                          ),
                        );
                        if (tabIndex != null && tabIndex is int) {
                          setState(() {
                            _selectedTab = tabIndex;
                          });
                        }
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: borderColor, width: 0.5),
                          ),
                        ),
                        child: IntrinsicHeight(
                          child: Row(
                            children: [
                              // Date/Time cell
                              Container(
                                width: 90,
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                                decoration: BoxDecoration(
                                  border: Border(right: BorderSide(color: borderColor, width: 0.5)),
                                ),
                                child: Text(
                                  formattedTime,
                                  style: GoogleFonts.roboto(fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                              // Recipient cell
                              Container(
                                width: 85,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  border: Border(right: BorderSide(color: borderColor, width: 0.5)),
                                ),
                                child: Text(
                                  recipient,
                                  style: GoogleFonts.roboto(fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                              // Message cell
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  child: Text(
                                    msg,
                                    style: GoogleFonts.roboto(fontSize: 11),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              // Vertical Line before Status
                              Container(width: 0.5, color: borderColor),
                              // Status cell with chevron
                              Container(
                                width: 85,
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            isSent ? Icons.check_circle : (isFailed ? Icons.cancel : Icons.access_time),
                                            color: isSent ? AppTheme.online : (isFailed ? AppTheme.offline : AppTheme.connecting),
                                            size: 12,
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              status,
                                              style: GoogleFonts.bebasNeue(
                                                fontSize: 11,
                                                color: isSent ? AppTheme.online : (isFailed ? AppTheme.offline : AppTheme.connecting),
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.chevron_right, size: 14, color: Colors.black),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildTableHeaderCell(String text, double width, Color borderColor, {bool isDividerRight = true, bool isDividerLeft = false}) {
    return Container(
      width: width > 0 ? width : null,
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
      decoration: BoxDecoration(
        border: Border(
          left: isDividerLeft ? BorderSide(color: borderColor, width: 0.5) : BorderSide.none,
          right: isDividerRight ? BorderSide(color: borderColor, width: 0.5) : BorderSide.none,
        ),
      ),
      child: Text(
        text,
        style: GoogleFonts.bebasNeue(
          fontSize: 11,
          letterSpacing: 0.5,
          color: Colors.grey.shade700,
        ),
      ),
    );
  }

  int _getJobCountForFilter(AppState appState, String filter) {
    if (filter == 'ALL') {
      return appState.recentJobs.length;
    }
    return appState.recentJobs.where((j) => (j['status'] as String? ?? 'PENDING') == filter).length;
  }

  void _showFilterSelectMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (_) {
        return Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _jobFilters.map((filter) {
              return ListTile(
                title: Text(
                  filter,
                  style: GoogleFonts.bebasNeue(fontSize: 16, letterSpacing: 0.5),
                ),
                onTap: () {
                  setState(() {
                    _selectedJobFilter = filter;
                  });
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  void _showNewSmsJobDialog(AppState appState) {
    final phoneController = TextEditingController();
    final messageController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          title: Text(
            'NEW SMS JOB',
            style: GoogleFonts.bebasNeue(fontSize: 24, letterSpacing: 0.5, color: Colors.black),
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: phoneController,
                  decoration: const InputDecoration(
                    labelText: 'RECIPIENT NUMBER',
                    hintText: '0715827357',
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Recipient is required';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: messageController,
                  decoration: const InputDecoration(
                    labelText: 'MESSAGE CONTENT',
                    hintText: 'Hello from gateway',
                  ),
                  maxLines: 3,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Message is required';
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final String jobId = const Uuid().v4().substring(0, 8);
                  await AppDatabase.insertJob(
                    jobId: jobId,
                    recipient: phoneController.text.trim(),
                    message: messageController.text.trim(),
                    status: 'PENDING',
                  );
                  await appState.refreshJobStats();
                  
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Custom SMS job created successfully!')),
                    );
                    Navigator.pop(context);
                  }
                }
              },
              child: const Text('SEND JOB'),
            ),
          ],
        );
      },
    );
  }

  // ==========================================
  // SYSTEM LOGS TAB
  // ==========================================
  Widget _buildLogsTab(AppState appState) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final borderColor = isLight ? AppTheme.border : AppTheme.darkBorder;

    // Filter logs
    final filteredLogs = appState.logs.where((log) {
      final query = _logsSearchQuery.toLowerCase();
      final matchesSearch = log.toLowerCase().contains(query);

      bool matchesLevel = true;
      if (_selectedLogLevel != 'ALL LEVELS') {
        final levelTag = _selectedLogLevel.toUpperCase();
        matchesLevel = log.toUpperCase().contains(']$levelTag') || log.toUpperCase().contains(' $levelTag ');
      }

      return matchesSearch && matchesLevel;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SYSTEM LOGS',
                    style: GoogleFonts.bebasNeue(
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: Colors.black,
                    ),
                  ),
                  Text(
                    'View device activity and system events in real time.',
                    style: GoogleFonts.roboto(
                      color: Colors.black54,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${appState.logs.length}',
                    style: GoogleFonts.bebasNeue(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'LOGS CACHED',
                    style: GoogleFonts.bebasNeue(fontSize: 10, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Search & Filters inputs row (Image 5 layout)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: SizedBox(
                  height: 46,
                  child: TextField(
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search, size: 18),
                      hintText: 'Search logs...',
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.zero,
                        borderSide: BorderSide(color: borderColor),
                      ),
                    ),
                    onChanged: (val) => setState(() => _logsSearchQuery = val),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Calendar dropdown
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedLogDate,
                    firstDate: DateTime(2025),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) {
                    setState(() {
                      _selectedLogDate = picked;
                    });
                  }
                },
                child: Container(
                  height: 46,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: borderColor, width: 1),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        '${_selectedLogDate.day}/${_selectedLogDate.month}/${_selectedLogDate.year}',
                        style: GoogleFonts.bebasNeue(fontSize: 12, letterSpacing: 0.5),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.keyboard_arrow_down, size: 14),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Level dropdown
              GestureDetector(
                onTap: () {
                  _showLogLevelsMenu(context);
                },
                child: Container(
                  height: 46,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: borderColor, width: 1),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.filter_list, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        _selectedLogLevel,
                        style: GoogleFonts.bebasNeue(fontSize: 12, letterSpacing: 0.5),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.keyboard_arrow_down, size: 14),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Logs table headers
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: borderColor, width: 1),
                bottom: BorderSide(color: borderColor, width: 1),
              ),
            ),
            child: Row(
              children: [
                _buildTableHeaderCell('TIME', 75, borderColor),
                _buildTableHeaderCell('LEVEL', 75, borderColor),
                Expanded(
                  child: _buildTableHeaderCell('MESSAGE', 0, borderColor, isDividerRight: false),
                ),
              ],
            ),
          ),
        ),

        // Logs table rows
        Expanded(
          child: filteredLogs.isEmpty
              ? Center(
                  child: Text(
                    'No logs generated yet.',
                    style: GoogleFonts.roboto(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  itemCount: filteredLogs.length,
                  itemBuilder: (context, index) {
                    final log = filteredLogs[index];

                    // Extract Time, Level, Msg
                    // Formats: [14:26:46] INFO Service stopped.
                    String time = '--:--:--';
                    String level = 'INFO';
                    String message = log;

                    try {
                      if (log.startsWith('[') && log.contains(']')) {
                        final closingBracket = log.indexOf(']');
                        time = log.substring(1, closingBracket);
                        
                        final parts = log.substring(closingBracket + 2).split(' ');
                        level = parts[0];
                        message = parts.sublist(1).join(' ');
                      }
                    } catch (_) {}

                    Color levelColor = Colors.black;
                    if (level.toUpperCase() == 'WARN') {
                      levelColor = AppTheme.connecting; // Orange
                    } else if (level.toUpperCase() == 'ERROR') {
                      levelColor = AppTheme.offline; // Red
                    }

                    return Container(
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: borderColor, width: 0.5),
                        ),
                      ),
                      child: IntrinsicHeight(
                        child: Row(
                          children: [
                            // Time cell
                            Container(
                              width: 75,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                border: Border(right: BorderSide(color: borderColor, width: 0.5)),
                              ),
                              child: Text(
                                time,
                                style: GoogleFonts.roboto(fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                            // Level cell
                            Container(
                              width: 75,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                border: Border(right: BorderSide(color: borderColor, width: 0.5)),
                              ),
                              child: Text(
                                level,
                                style: GoogleFonts.roboto(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: levelColor,
                                ),
                              ),
                            ),
                            // Message cell
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text(
                                  message,
                                  style: GoogleFonts.roboto(fontSize: 11),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showLogLevelsMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (_) {
        return Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _logLevels.map((lvl) {
              return ListTile(
                title: Text(
                  lvl,
                  style: GoogleFonts.bebasNeue(fontSize: 16, letterSpacing: 0.5),
                ),
                onTap: () {
                  setState(() {
                    _selectedLogLevel = lvl;
                  });
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  // ==========================================
  // SETTINGS TAB
  // ==========================================
  Widget _buildSettingsTab(AppState appState) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final borderColor = isLight ? AppTheme.border : AppTheme.darkBorder;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            'SETTINGS',
            style: GoogleFonts.bebasNeue(
              fontSize: 42,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
              color: Colors.black,
            ),
          ),
          Text(
            'Configure application, device and system preferences.',
            style: GoogleFonts.roboto(
              color: Colors.black54,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 24),

          // Section "REFERENCE" (Image 2 style)
          Text(
            'REFERENCE',
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
                // Server URL (Edit dialog triggers on tap)
                GestureDetector(
                  onTap: () => _showEditServerUrlDialog(appState),
                  child: _buildSettingsRow(
                    'SERVER URL',
                    appState.serverUrl.isNotEmpty ? appState.serverUrl : 'http://f7c8-203-189-188-227.ngrok-free.app',
                    borderColor,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    // Toggle timeout
                    setState(() {
                      if (_connectionTimeoutSeconds == 10) {
                        _connectionTimeoutSeconds = 20;
                      } else if (_connectionTimeoutSeconds == 20) {
                        _connectionTimeoutSeconds = 30;
                      } else {
                        _connectionTimeoutSeconds = 10;
                      }
                    });
                  },
                  child: _buildSettingsRow(
                    'CONNECTION TIMEOUT',
                    '$_connectionTimeoutSeconds seconds',
                    borderColor,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _autoReconnect = !_autoReconnect;
                    });
                  },
                  child: _buildSettingsRow(
                    'AUTO RECONNECT',
                    _autoReconnect ? 'ON' : 'OFF',
                    borderColor,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    // Toggle retry
                    setState(() {
                      if (_retryAttempts == 1) {
                        _retryAttempts = 3;
                      } else if (_retryAttempts == 3) {
                        _retryAttempts = 5;
                      } else {
                        _retryAttempts = 1;
                      }
                    });
                  },
                  child: _buildSettingsRow(
                    'RETRY ATTEMPTS',
                    '$_retryAttempts',
                    borderColor,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    appState.setUseWhiteTheme(!appState.useWhiteTheme);
                  },
                  child: _buildSettingsRow(
                    'THEME BACKGROUND',
                    appState.useWhiteTheme ? 'WHITE' : 'OFF-WHITE',
                    borderColor,
                    isLast: true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Section "DEVICE INFORMATION"
          Text(
            'DEVICE INFORMATION',
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
                _buildSettingsRow('DEVICE NAME', appState.deviceName.isNotEmpty ? appState.deviceName : 'Samsung S20', borderColor),
                _buildSettingsRow('DEVICE UUID', appState.deviceUuid.isNotEmpty ? appState.deviceUuid : 'TP1A.220624.014', borderColor),
                _buildSettingsRow('HARDWARE MODEL', appState.deviceModel.isNotEmpty ? appState.deviceModel : 'samsung SM-G981N', borderColor, isLast: true),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Section "MORE"
          Text(
            'MORE',
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
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AboutScreen()),
                    );
                  },
                  child: _buildSettingsRow('ABOUT APPLICATION', 'Tap to view metadata', borderColor),
                ),
                _buildSettingsRow('DOCUMENTATION', 'docs.openrelay.dev', borderColor),
                _buildSettingsRow('SUPPORT EMAIL', 'support@openrelay.dev', borderColor, isLast: true),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Reset config danger zone
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton(
              onPressed: () => _confirmReset(appState),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primary,
                side: const BorderSide(color: AppTheme.primary, width: 1.5),
                backgroundColor: Colors.white,
              ),
              child: const Text('RESET SETUP CONFIGURATION'),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSettingsRow(String label, String value, Color borderColor, {bool isLast = false}) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: isLast ? BorderSide.none : BorderSide(color: borderColor, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 150,
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 14.0),
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: borderColor, width: 0.5),
              ),
            ),
            child: Text(
              label,
              style: GoogleFonts.bebasNeue(
                fontSize: 12,
                letterSpacing: 0.5,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 14.0),
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


  void _showEditServerUrlDialog(AppState appState) {
    final urlController = TextEditingController(text: appState.serverUrl);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          title: Text(
            'EDIT SERVER URL',
            style: GoogleFonts.bebasNeue(fontSize: 24, letterSpacing: 0.5, color: Colors.black),
          ),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: 'SERVER URL',
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) return 'URL is required';
                final uri = Uri.tryParse(val.trim());
                if (uri == null || !uri.hasScheme) return 'Enter a valid URL (e.g. http://...)';
                return null;
              },
            ),
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  await appState.updateServerUrl(urlController.text.trim());
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Server URL updated successfully.')),
                    );
                    Navigator.pop(context);
                  }
                }
              },
              child: const Text('SAVE'),
            ),
          ],
        );
      },
    );
  }

  void _confirmReset(AppState appState) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: Text(
          'RESET SETUP?',
          style: GoogleFonts.bebasNeue(fontSize: 24, letterSpacing: 0.5, color: Colors.black),
        ),
        content: const Text(
          'This will clear all saved data and return to the setup screen. The device will need to be re-registered.',
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              final navigator = Navigator.of(context);
              navigator.pop();
              appState.resetSetup().then((_) {
                navigator.pushReplacementNamed('/setup');
              });
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            child: const Text('RESET'),
          ),
        ],
      ),
    );
  }
}
