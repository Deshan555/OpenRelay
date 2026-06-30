import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
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
        // Animated icon
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.primary, AppTheme.accent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.4),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(Icons.cell_tower_rounded, size: 40, color: Colors.white),
        ).animate().fadeIn(duration: 600.ms).scale(
          begin: const Offset(0.8, 0.8),
          end: const Offset(1.0, 1.0),
          curve: Curves.easeOutBack,
          duration: 600.ms,
        ),
        const SizedBox(height: 24),
        Text(
          'OpenRelay',
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
          ),
        ).animate().fadeIn(delay: 200.ms, duration: 500.ms).slideY(begin: 0.2, end: 0),
        const SizedBox(height: 8),
        Text(
          'SMS Gateway',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppTheme.accent,
            fontWeight: FontWeight.w500,
            letterSpacing: 2,
          ),
        ).animate().fadeIn(delay: 400.ms, duration: 500.ms),
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
    ).animate().fadeIn(delay: 500.ms, duration: 400.ms);
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
            color: isActive ? AppTheme.primary : AppTheme.surfaceLight,
            shape: BoxShape.circle,
            border: Border.all(
              color: isActive ? AppTheme.primary : AppTheme.surfaceBorder,
              width: 2,
            ),
          ),
          child: Center(
            child: isActive && _currentStep > step
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : Text(
                    '${step + 1}',
                    style: TextStyle(
                      color: isActive ? Colors.white : AppTheme.textMuted,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isActive ? AppTheme.textSecondary : AppTheme.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _stepLine(int afterStep) {
    final isActive = _currentStep > afterStep;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 60,
        height: 2,
        color: isActive ? AppTheme.primary : AppTheme.surfaceBorder,
      ),
    );
  }

  Widget _buildPermissionsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Required Permissions',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          'OpenRelay needs these permissions to send and receive SMS on your behalf.',
          style: TextStyle(color: AppTheme.textSecondary, height: 1.5),
        ),
        const SizedBox(height: 24),
        _permissionTile(
          icon: Icons.sms_rounded,
          title: 'SMS',
          subtitle: 'Send and receive SMS messages',
          granted: _smsGranted,
        ),
        const SizedBox(height: 12),
        _permissionTile(
          icon: Icons.phone_android_rounded,
          title: 'Phone State',
          subtitle: 'Read carrier and signal info',
          granted: _phoneGranted,
        ),
        const SizedBox(height: 12),
        _permissionTile(
          icon: Icons.notifications_rounded,
          title: 'Notifications',
          subtitle: 'Show service status notification',
          granted: _notificationGranted,
        ),
        const SizedBox(height: 12),
        _permissionTile(
          icon: Icons.location_on_rounded,
          title: 'GPS Location',
          subtitle: 'Send device location updates to backend',
          granted: _locationGranted,
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: (_smsGranted && _phoneGranted && _locationGranted)
                ? () => setState(() => _currentStep = 1)
                : _requestPermissions,
            icon: Icon(
              (_smsGranted && _phoneGranted && _locationGranted) ? Icons.arrow_forward : Icons.security_rounded,
            ),
            label: Text(
              (_smsGranted && _phoneGranted && _locationGranted) ? 'Continue' : 'Grant Permissions',
            ),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.05, end: 0);
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
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: granted ? AppTheme.accentGreen.withValues(alpha: 0.3) : AppTheme.surfaceBorder,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: (granted ? AppTheme.accentGreen : AppTheme.primary).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: granted ? AppTheme.accentGreen : AppTheme.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
              ],
            ),
          ),
          Icon(
            granted ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            color: granted ? AppTheme.accentGreen : AppTheme.textMuted,
            size: 24,
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
            'Server Configuration',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter your OpenRelay backend server URL and give this device a name.',
            style: TextStyle(color: AppTheme.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _serverUrlController,
            decoration: InputDecoration(
              labelText: 'Server URL',
              hintText: 'http://192.168.1.100:8000',
              prefixIcon: const Icon(Icons.dns_rounded),
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
                          icon: const Icon(Icons.wifi_find_rounded),
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
              prefixIcon: Icon(Icons.smartphone_rounded),
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
                color: AppTheme.accentRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.accentRed.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppTheme.accentRed, size: 20),
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
                  : const Icon(Icons.rocket_launch_rounded),
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
            backgroundColor: AppTheme.surfaceBorder,
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
