import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/app_state.dart';
import '../logo_painter.dart';
import '../theme.dart';

/// First-launch setup screen.
/// User enters server URL, device name, and grants permissions.
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _serverUrlController = TextEditingController();
  final _deviceNameController = TextEditingController();

  bool _isLoading = false;
  bool _isTesting = false;
  bool _serverReachable = false;
  String? _errorMessage;

  // Permission states
  bool _smsGranted = false;
  bool _phoneGranted = false;
  bool _notificationGranted = false;
  bool _locationGranted = false;

  int _currentStep = 0; // 0 = permissions, 1 = server config, 2 = connecting

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    
    // Auto-populate device name field with the detected device model
    final appState = context.read<AppState>();
    if (appState.deviceModel.isNotEmpty) {
      _deviceNameController.text = appState.deviceModel;
    }
  }

  Future<void> _checkPermissions() async {
    _smsGranted = await Permission.sms.isGranted;
    _phoneGranted = await Permission.phone.isGranted;
    _notificationGranted = await Permission.notification.isGranted;
    _locationGranted = await Permission.location.isGranted;
    if (mounted) setState(() {});
  }

  Future<void> _requestPermissions() async {
    final smsStatus = await Permission.sms.request();
    final phoneStatus = await Permission.phone.request();
    final notifStatus = await Permission.notification.request();
    final locationStatus = await Permission.location.request();

    setState(() {
      _smsGranted = smsStatus.isGranted;
      _phoneGranted = phoneStatus.isGranted;
      _notificationGranted = notifStatus.isGranted;
      _locationGranted = locationStatus.isGranted;
    });

    if (_smsGranted && _phoneGranted && _locationGranted) {
      setState(() => _currentStep = 1);
    }
  }

  Future<void> _testConnection() async {
    if (_serverUrlController.text.trim().isEmpty) return;

    setState(() {
      _isTesting = true;
      _serverReachable = false;
      _errorMessage = null;
    });

    final appState = context.read<AppState>();
    final reachable = await appState.testConnection(_serverUrlController.text.trim());

    if (mounted) {
      setState(() {
        _isTesting = false;
        _serverReachable = reachable;
        if (!reachable) {
          _errorMessage = 'Could not reach server. Check the URL and ensure the backend is running.';
        }
      });
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _currentStep = 2;
    });

    try {
      final appState = context.read<AppState>();
      await appState.registerDevice(
        serverUrl: _serverUrlController.text.trim(),
        deviceName: _deviceNameController.text.trim(),
      );

      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/dashboard');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _currentStep = 1;
          _errorMessage = 'Registration failed: ${e.toString()}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              // Logo / Title
              _buildHeader(),
              const SizedBox(height: 48),
              // Step indicator
              _buildStepIndicator(),
              const SizedBox(height: 32),
              // Content
              if (_currentStep == 0) _buildPermissionsStep(),
              if (_currentStep == 1) _buildServerConfigStep(),
              if (_currentStep == 2) _buildConnectingStep(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        CustomPaint(
          size: const Size(80, 80),
          painter: AntennaLogoPainter(color: AppTheme.primary),
        ),
        const SizedBox(height: 24),
        Text(
          'OPENRELAY',
          style: GoogleFonts.bebasNeue(
            fontSize: 40,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'SMS GATEWAY',
          style: GoogleFonts.roboto(
            color: AppTheme.primary,
            fontWeight: FontWeight.w900,
            letterSpacing: 3.0,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildStepIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _stepDot(0, 'Permissions'),
        _stepLine(0),
        _stepDot(1, 'Configure'),
        _stepLine(1),
        _stepDot(2, 'Connect'),
      ],
    );
  }

  Widget _stepDot(int step, String label) {
    final isActive = _currentStep >= step;
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isActive ? AppTheme.primary : Colors.white,
            border: Border.all(
              color: AppTheme.border,
              width: 1.5,
            ),
          ),
          child: Center(
            child: isActive && _currentStep > step
                ? const FaIcon(FontAwesomeIcons.check, size: 12, color: Colors.white)
                : Text(
                    '${step + 1}',
                    style: TextStyle(
                      color: isActive ? Colors.white : Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: GoogleFonts.bebasNeue(
            fontSize: 11,
            color: isActive ? AppTheme.primary : Colors.black,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _stepLine(int afterStep) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 60,
        height: 2,
        color: AppTheme.border,
      ),
    );
  }

  Widget _buildPermissionsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'REQUIRED PERMISSIONS',
          style: GoogleFonts.bebasNeue(fontSize: 20, letterSpacing: 0.5, color: Colors.black),
        ),
        const SizedBox(height: 8),
        Text(
          'OpenRelay needs these permissions to send and receive SMS on your behalf.',
          style: GoogleFonts.roboto(
            color: Colors.black87,
            height: 1.5,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 24),
        _permissionTile(
          icon: FontAwesomeIcons.commentSms,
          title: 'SMS',
          subtitle: 'Send and receive SMS messages',
          granted: _smsGranted,
        ),
        const SizedBox(height: 12),
        _permissionTile(
          icon: FontAwesomeIcons.mobile,
          title: 'Phone State',
          subtitle: 'Read carrier and signal info',
          granted: _phoneGranted,
        ),
        const SizedBox(height: 12),
        _permissionTile(
          icon: FontAwesomeIcons.solidBell,
          title: 'Notifications',
          subtitle: 'Show service status notification',
          granted: _notificationGranted,
        ),
        const SizedBox(height: 12),
        _permissionTile(
          icon: FontAwesomeIcons.locationDot,
          title: 'GPS Location',
          subtitle: 'Send device location updates to backend',
          granted: _locationGranted,
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: (_smsGranted && _phoneGranted && _locationGranted)
                ? () => setState(() => _currentStep = 1)
                : _requestPermissions,
            icon: FaIcon(
              (_smsGranted && _phoneGranted && _locationGranted) ? FontAwesomeIcons.arrowRight : FontAwesomeIcons.shieldHalved,
              size: 16,
            ),
            label: Text(
              (_smsGranted && _phoneGranted && _locationGranted) ? 'CONTINUE' : 'GRANT PERMISSIONS',
            ),
          ),
        ),
      ],
    );
  }

  Widget _permissionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool granted,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: AppTheme.border,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: granted ? AppTheme.accentGreen.withOpacity(0.12) : AppTheme.primary.withOpacity(0.12),
              border: Border.all(color: AppTheme.border, width: 1),
            ),
            child: Center(
              child: FaIcon(icon, color: granted ? AppTheme.accentGreen : AppTheme.primary, size: 20),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: Colors.black54, fontSize: 12)),
              ],
            ),
          ),
          FaIcon(
            granted ? FontAwesomeIcons.solidCircleCheck : FontAwesomeIcons.circle,
            color: granted ? AppTheme.accentGreen : Colors.black45,
            size: 22,
          ),
        ],
      ),
    );
  }

  Widget _buildServerConfigStep() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SERVER CONFIGURATION',
            style: GoogleFonts.bebasNeue(
              fontSize: 20,
              letterSpacing: 0.5,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter your OpenRelay backend server URL and give this device a name.',
            style: GoogleFonts.roboto(
              color: Colors.black87,
              height: 1.5,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _serverUrlController,
            decoration: InputDecoration(
              labelText: 'Server URL',
              hintText: 'http://192.168.1.100:8000',
              prefixIcon: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: FaIcon(FontAwesomeIcons.server, size: 16),
              ),
              suffixIcon: _isTesting
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : _serverReachable
                      ? const Icon(Icons.check_circle, color: AppTheme.accentGreen)
                      : IconButton(
                          icon: const FaIcon(FontAwesomeIcons.wifi, size: 16),
                          onPressed: _testConnection,
                          tooltip: 'Test connection',
                        ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Server URL is required';
              final uri = Uri.tryParse(value);
              if (uri == null || !uri.hasScheme) return 'Enter a valid URL (e.g. http://...)';
              return null;
            },
            keyboardType: TextInputType.url,
            onChanged: (_) => setState(() => _serverReachable = false),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _deviceNameController,
            decoration: const InputDecoration(
              labelText: 'Device Name',
              hintText: 'My Android Phone',
              prefixIcon: Padding(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: FaIcon(FontAwesomeIcons.mobileScreen, size: 16),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Device name is required';
              return null;
            },
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.accentRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.accentRed.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const FaIcon(FontAwesomeIcons.circleExclamation, color: AppTheme.accentRed, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: AppTheme.accentRed, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _register,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const FaIcon(FontAwesomeIcons.rocket, size: 16),
              label: Text(_isLoading ? 'Registering...' : 'Register & Connect'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => setState(() => _currentStep = 0),
              child: const Text('← Back to permissions'),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.05, end: 0);
  }

  Widget _buildConnectingStep() {
    return Column(
      children: [
        const SizedBox(height: 40),
        SizedBox(
          width: 80,
          height: 80,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            color: AppTheme.primary,
            backgroundColor: Theme.of(context).brightness == Brightness.light ? const Color(0xFFE2E8F0) : AppTheme.darkBorder,
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'Connecting to Server...',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Text(
          'Registering this device with your OpenRelay server.',
          style: TextStyle(color: AppTheme.textSecondary),
          textAlign: TextAlign.center,
        ),
      ],
    ).animate().fadeIn(duration: 400.ms);
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    _deviceNameController.dispose();
    super.dispose();
  }
}
