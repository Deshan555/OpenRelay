import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../services/database.dart';
import '../theme.dart';
import '../header_bar.dart';
import '../bottom_nav_bar.dart';

/// Screen showing detailed information about a single SMS job.
class SmsJobDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> job;

  const SmsJobDetailsScreen({super.key, required this.job});

  @override
  State<SmsJobDetailsScreen> createState() => _SmsJobDetailsScreenState();
}

class _SmsJobDetailsScreenState extends State<SmsJobDetailsScreen> {
  late Map<String, dynamic> _jobData;

  @override
  void initState() {
    super.initState();
    _jobData = Map<String, dynamic>.from(widget.job);
  }

  String _formatDateTime(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '--';
    try {
      final dt = DateTime.parse(isoString);
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoString;
    }
  }

  Future<void> _retryJob() async {
    final appState = context.read<AppState>();
    final jobId = _jobData['job_id'] as String;
    
    // Update local DB to PENDING
    await AppDatabase.updateJobStatus(jobId, 'PENDING');
    await appState.refreshJobStats();
    
    // Show snackbar
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Job scheduled for retry.')),
      );
      // Navigate back
      Navigator.pop(context);
    }
  }

  Future<void> _deleteJob() async {
    final appState = context.read<AppState>();
    final jobId = _jobData['job_id'] as String;

    // We will delete the job from the local DB.
    final db = await AppDatabase.database;
    await db.delete('sms_jobs', where: 'job_id = ?', whereArgs: [jobId]);
    await appState.refreshJobStats();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Job deleted.')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final borderColor = isLight ? AppTheme.border : AppTheme.darkBorder;

    final String jobId = _jobData['job_id'] as String? ?? 'N/A';
    final String status = _jobData['status'] as String? ?? 'PENDING';
    final String recipient = _jobData['recipient'] as String? ?? '';
    final String message = _jobData['message'] as String? ?? '';
    final String createdAt = _formatDateTime(_jobData['created_at'] as String?);
    final String completedAt = _formatDateTime(_jobData['sent_at'] as String?);

    final bool isFailed = status == 'FAILED';
    final bool isSent = status == 'SENT';

    return Scaffold(
      appBar: const HeaderBar(),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
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
                          'BACK TO SMS JOBS',
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
                    'SMS INFORMATION',
                    style: GoogleFonts.bebasNeue(
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: Colors.black,
                    ),
                  ),
                  Text(
                    'Detailed information about this SMS job.',
                    style: GoogleFonts.roboto(
                      color: Colors.black54,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Summary Grid Box (Image 4 top section)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: borderColor, width: 1),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Column
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'JOB ID',
                                  style: GoogleFonts.bebasNeue(
                                    fontSize: 12,
                                    letterSpacing: 0.8,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  jobId,
                                  style: GoogleFonts.bebasNeue(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'MESSAGE',
                                  style: GoogleFonts.bebasNeue(
                                    fontSize: 12,
                                    letterSpacing: 0.8,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  message,
                                  style: GoogleFonts.roboto(
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Vertical divider line
                        Container(
                          width: 1,
                          height: 140,
                          color: borderColor,
                        ),
                        // Right Column
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'STATUS',
                                  style: GoogleFonts.bebasNeue(
                                    fontSize: 12,
                                    letterSpacing: 0.8,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      isSent ? Icons.check_circle : (isFailed ? Icons.cancel : Icons.access_time),
                                      color: isSent ? AppTheme.online : (isFailed ? AppTheme.offline : AppTheme.connecting),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      status,
                                      style: GoogleFonts.bebasNeue(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: isSent ? AppTheme.online : (isFailed ? AppTheme.offline : AppTheme.connecting),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'CREATED AT',
                                  style: GoogleFonts.bebasNeue(
                                    fontSize: 12,
                                    letterSpacing: 0.8,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  createdAt,
                                  style: GoogleFonts.roboto(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // DETAILS Title
                  Text(
                    'DETAILS',
                    style: GoogleFonts.bebasNeue(
                      fontSize: 18,
                      letterSpacing: 0.8,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Details Grid Table
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: borderColor, width: 1),
                    ),
                    child: Column(
                      children: [
                        _buildDetailRow('RECIPIENT NUMBER', recipient, borderColor),
                        _buildDetailRow('MESSAGE CONTENT', message, borderColor),
                        _buildDetailRow('CHARACTER COUNT', '${message.length}', borderColor),
                        _buildDetailRow('MESSAGE TYPE', 'TEXT', borderColor),
                        _buildDetailRow('ENCODING', 'GSM-7', borderColor),
                        _buildDetailRow('SUBMITTED AT', createdAt, borderColor),
                        _buildDetailRow('COMPLETED AT', completedAt, borderColor),
                        _buildDetailRow('DURATION', isSent ? '00:00:02' : '--', borderColor),
                        _buildDetailRow('RETRY COUNT', isFailed ? '2' : '0', borderColor),
                        _buildDetailRow(
                          'ERROR',
                          isFailed ? 'WebSocketChannelException: Connection failed' : '--',
                          borderColor,
                          isLast: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // TIMELINE Title
                  Text(
                    'TIMELINE',
                    style: GoogleFonts.bebasNeue(
                      fontSize: 18,
                      letterSpacing: 0.8,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Custom Vertical Timeline Stepper
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: Column(
                      children: [
                        _buildTimelineStep(
                          time: createdAt,
                          event: 'Job created',
                          isDone: true,
                          isFirst: true,
                        ),
                        _buildTimelineStep(
                          time: createdAt,
                          event: 'Message submitted',
                          isDone: !isFailed && !isSent ? false : true,
                        ),
                        if (isFailed) ...[
                          _buildTimelineStep(
                            time: _formatDateTime(
                              DateTime.parse(_jobData['created_at'] as String)
                                  .add(const Duration(seconds: 1))
                                  .toIso8601String(),
                            ),
                            event: 'Sending failed (attempt 1)',
                            isDone: true,
                          ),
                          _buildTimelineStep(
                            time: _formatDateTime(
                              DateTime.parse(_jobData['created_at'] as String)
                                  .add(const Duration(seconds: 2))
                                  .toIso8601String(),
                            ),
                            event: 'Sending failed (attempt 2)',
                            isDone: true,
                            isLast: true,
                          ),
                        ] else if (isSent) ...[
                          _buildTimelineStep(
                            time: _formatDateTime(
                              DateTime.parse(_jobData['created_at'] as String)
                                  .add(const Duration(seconds: 1))
                                  .toIso8601String(),
                            ),
                            event: 'Sending message',
                            isDone: true,
                          ),
                          _buildTimelineStep(
                            time: completedAt,
                            event: 'Message delivered successfully',
                            isDone: true,
                            isLast: true,
                          ),
                        ] else ...[
                          _buildTimelineStep(
                            time: '--',
                            event: 'Waiting in sending queue',
                            isDone: false,
                            isLast: true,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Action Buttons side-by-side
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: _retryJob,
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text('RETRY JOB'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 50,
                          child: OutlinedButton.icon(
                            onPressed: _deleteJob,
                            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.black),
                            label: const Text(
                              'DELETE JOB',
                              style: TextStyle(color: Colors.black),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.black, width: 1),
                              backgroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavBar(
        selectedIndex: 1,
        onTap: (index) {
          Navigator.pop(context, index); // Pop and return tab index
        },
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, Color borderColor, {bool isLast = false}) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: isLast ? BorderSide.none : BorderSide(color: borderColor, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // Label
          Container(
            width: 140,
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
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
          // Value
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
              child: Text(
                value,
                style: GoogleFonts.roboto(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineStep({
    required String time,
    required String event,
    required bool isDone,
    bool isFirst = false,
    bool isLast = false,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bullet indicator + vertical line
          Column(
            children: [
              // Circle bullet dot
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: isDone ? Colors.black : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black, width: 1.5),
                ),
              ),
              // Line under circle
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 1.5,
                    color: Colors.black,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          // Event detail
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Timestamp
                  SizedBox(
                    width: 130,
                    child: Text(
                      time,
                      style: GoogleFonts.roboto(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  // Separator line
                  Container(
                    width: 1,
                    height: 18,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(width: 16),
                  // Event description
                  Expanded(
                    child: Text(
                      event,
                      style: GoogleFonts.roboto(
                        fontSize: 13,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
