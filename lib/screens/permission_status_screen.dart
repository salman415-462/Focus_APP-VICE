import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/method_channel_service.dart';

class PermissionStatusScreen extends StatefulWidget {
  const PermissionStatusScreen({super.key});

  @override
  State<PermissionStatusScreen> createState() => _PermissionStatusScreenState();
}

class _PermissionStatusScreenState extends State<PermissionStatusScreen>
    with WidgetsBindingObserver {
  bool _isCheckingPermissions = true;
  bool _accessibilityEnabled = false;
  bool _serviceRunning = false;
  bool _overlayEnabled = false;
  bool _adminEnabled = false;
  bool _hasError = false;
  Timer? _retryTimer;
  Timer? _fallbackRefreshTimer;
  DateTime _lastRefreshTime = DateTime.now();
  static const Duration _fallbackRefreshInterval = Duration(seconds: 2);
  static const int _maxRetryAttempts = 3;
  int _retryAttempts = 0;

  static const MethodChannel _refreshChannel =
      MethodChannel('core.blocker/channel');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupMethodChannelListener();
    _checkPermissions();
    _startFallbackRefreshTimer();
  }

  @override
  void dispose() {
    _stopFallbackRefreshTimer();
    _retryTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _setupMethodChannelListener() {
    _refreshChannel.setMethodCallHandler((call) async {
      if (call.method == 'refreshPermissions') {
        if (mounted) {
          _retryAttempts = 0;
          await _checkPermissionsWithRetry();
        }
      }
    });
  }

  void _startFallbackRefreshTimer() {
    _stopFallbackRefreshTimer();
    _fallbackRefreshTimer = Timer.periodic(
      _fallbackRefreshInterval,
      (_) {
        if (mounted) {
          _performFallbackRefresh();
        }
      },
    );
  }

  void _stopFallbackRefreshTimer() {
    _fallbackRefreshTimer?.cancel();
    _fallbackRefreshTimer = null;
  }

  void _performFallbackRefresh() {
    final now = DateTime.now();
    final timeSinceLastRefresh = now.difference(_lastRefreshTime);
    if (timeSinceLastRefresh >= _fallbackRefreshInterval) {
      _retryAttempts = 0;
      _checkPermissionsWithRetry();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _retryAttempts = 0;
      _checkPermissionsWithRetry();
    }
  }

  Future<void> _checkPermissionsWithRetry() async {
    _retryTimer?.cancel();

    await _checkPermissions();

    if (!mounted) return;

    if (!_allPermissionsEnabled && _retryAttempts < _maxRetryAttempts) {
      _retryAttempts++;
      _retryTimer = Timer(const Duration(milliseconds: 500), () async {
        if (!mounted) return;
        await _checkPermissions();
      });
    }
  }

  void _checkPermissionsWithDelay() {
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) {
        _retryAttempts = 0;
        _checkPermissionsWithRetry();
      }
    });
  }

  Future<void> _checkPermissions() async {
    _lastRefreshTime = DateTime.now();

    setState(() {
      _isCheckingPermissions = true;
      _hasError = false;
    });

    try {
      final status = await MethodChannelService.getPermissionStatus();
      if (!mounted) return;

      setState(() {
        _accessibilityEnabled = status['accessibility_enabled'] as bool;
        _serviceRunning = status['service_running'] as bool;
        _overlayEnabled = status['overlay_enabled'] as bool;
        _adminEnabled = status['device_admin_enabled'] as bool;
        _isCheckingPermissions = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isCheckingPermissions = false;
        _hasError = true;
      });
    }
  }

  bool get _allPermissionsEnabled {
    return _accessibilityEnabled && _overlayEnabled && _adminEnabled;
  }

  void _openAccessibilitySettings() async {
    final success = await MethodChannelService.openAccessibilitySettings();
    if (!success && mounted) {
      _showFallbackHint(
        'Accessibility Settings',
        'Please open Settings > Accessibility and enable Focus Guard.',
      );
    }
    if (mounted) {
      _retryAttempts = 0;
      _checkPermissionsWithDelay();
    }
  }

  void _openOverlaySettings() async {
    final success = await MethodChannelService.openOverlaySettings();
    if (!success && mounted) {
      _showFallbackHint(
        'Overlay Permission',
        'Please open Settings > Apps > Focus Guard > Permissions and enable "Display over other apps".',
      );
    }
    if (mounted) {
      _retryAttempts = 0;
      _checkPermissionsWithDelay();
    }
  }

  void _openAdminSettings() async {
    await MethodChannelService.openDeviceAdminSettings();
    if (mounted) {
      _retryAttempts = 0;
      _checkPermissionsWithDelay();
    }
  }

  void _showFallbackHint(String title, String message) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFFFDF2),
        title: Text(
          title,
          style: const TextStyle(color: Color(0xFF2C2C25)),
        ),
        content: Text(
          message,
          style: const TextStyle(color: Color(0xFF7A7A70)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'OK',
              style: TextStyle(color: Color(0xFF4E6E3A)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionCard({
    required String title,
    required String description,
    required bool isEnabled,
    required VoidCallback onTap,
    required String statusText,
    required Color statusColor,
    required Color indicatorColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 96,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: const Color(0x1A000000),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 24),
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: indicatorColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF2C2C25),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      color: Color(0xFF7A7A70),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              statusText,
              style: TextStyle(
                color: statusColor,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 24),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFFDF2),
              Color(0xFFE9E7D8),
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.5, -0.8),
                    radius: 1.8,
                    colors: [
                      const Color(0xB3FFFFFF),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            _buildDecorativeLeaves(),
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 52),
                  const Padding(
                    padding: EdgeInsets.only(left: 24),
                    child: Text(
                      'Almost ready',
                      style: TextStyle(
                        color: Color(0xFF2C2C25),
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 26),
                  const Padding(
                    padding: EdgeInsets.only(left: 24),
                    child: Text(
                      'This helps keep distractions away.',
                      style: TextStyle(
                        color: Color(0xFF7A7A70),
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(height: 88),
                  if (_hasError)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF2F0),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFE8D0CC),
                            width: 1,
                          ),
                        ),
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFFD4A5A5),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Text(
                                'Could not check permissions. Assuming disabled.',
                                style: TextStyle(
                                  color: Color(0xFFB57A7A),
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (_hasError) const SizedBox(height: 16),
                  _isCheckingPermissions
                      ? Expanded(
                          child: Center(
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: const Color(0x4D6E8F5E),
                                shape: BoxShape.circle,
                              ),
                              child: const CircularProgressIndicator(
                                color: Color(0xFF6E8F5E),
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                        )
                      : Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Column(
                              children: [
                                _buildPermissionCard(
                                  title: 'Awareness',
                                  description: 'Notices app switches',
                                  isEnabled: _accessibilityEnabled,
                                  onTap: _openAccessibilitySettings,
                                  statusText: _accessibilityEnabled
                                      ? 'Allowed'
                                      : 'Not Allowed',
                                  statusColor: _accessibilityEnabled
                                      ? const Color(0xFF6E8F5E)
                                      : const Color(0xFFB57A7A),
                                  indicatorColor: _accessibilityEnabled
                                      ? const Color(0xFFE6EFE3)
                                      : const Color(0xFFFFF2F0),
                                ),
                                const SizedBox(height: 20),
                                _buildPermissionCard(
                                  title: 'Overlays',
                                  description: 'Shows block screen',
                                  isEnabled: _overlayEnabled,
                                  onTap: _openOverlaySettings,
                                  statusText: _overlayEnabled
                                      ? 'Allowed'
                                      : 'Not Allowed',
                                  statusColor: _overlayEnabled
                                      ? const Color(0xFF4E6E3A)
                                      : const Color(0xFFB57A7A),
                                  indicatorColor: _overlayEnabled
                                      ? const Color(0xFF6E8F5E)
                                      : const Color(0xFFFFF2F0),
                                ),
                                const SizedBox(height: 20),
                                _buildPermissionCard(
                                  title: 'Protection',
                                  description: 'Prevents shutdown',
                                  isEnabled: _adminEnabled,
                                  onTap: _openAdminSettings,
                                  statusText:
                                      _adminEnabled ? 'Allowed' : 'Not Allowed',
                                  statusColor: _adminEnabled
                                      ? const Color(0xFF4E6E3A)
                                      : const Color(0xFFB57A7A),
                                  indicatorColor: _adminEnabled
                                      ? const Color(0xFF6E8F5E)
                                      : const Color(0xFFFFF2F0),
                                ),
                                const Spacer(),
                                _buildContinueButton(),
                                const SizedBox(height: 40),
                              ],
                            ),
                          ),
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDecorativeLeaves() {
    return Stack(
      children: [
        Positioned(
          right: 20,
          top: 70,
          child: Transform.rotate(
            angle: 18 * 3.14159 / 180,
            child: CustomPaint(
              size: const Size(90, 45),
              painter: LeafPainter(color: const Color(0x385F7743)),
            ),
          ),
        ),
        Positioned(
          left: -20,
          bottom: 180,
          child: Transform.rotate(
            angle: -18 * 3.14159 / 180,
            child: CustomPaint(
              size: const Size(90, 45),
              painter: LeafPainter(color: const Color(0x385F7743)),
            ),
          ),
        ),
        Positioned(
          left: 40,
          top: 140,
          child: CustomPaint(
            size: const Size(28, 14),
            painter: LeafPainter(color: const Color(0x388DA167)),
          ),
        ),
        Positioned(
          right: 20,
          top: 240,
          child: CustomPaint(
            size: const Size(28, 14),
            painter: LeafPainter(color: const Color(0x388DA167)),
          ),
        ),
        Positioned(
          left: 180,
          top: 520,
          child: CustomPaint(
            size: const Size(28, 14),
            painter: LeafPainter(color: const Color(0x388DA167)),
          ),
        ),
      ],
    );
  }

  Widget _buildContinueButton() {
    return GestureDetector(
      onTap: _isCheckingPermissions
          ? null
          : () {
              if (_allPermissionsEnabled) {
                Navigator.pushReplacementNamed(context, '/home');
              } else {
                _showPermissionWarning();
              }
            },
      child: Container(
        width: 216,
        height: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF6E8F5E),
              Color(0xFF4E6E3A),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0x1A000000),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: const Center(
          child: Text(
            'Continue',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  void _showPermissionWarning() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFFFDF2),
        title: const Text(
          'Permissions Required',
          style: TextStyle(color: Color(0xFF2C2C25)),
        ),
        content: const Text(
          'All permissions must be enabled before you can continue. Please enable the missing permissions above.',
          style: TextStyle(color: Color(0xFF7A7A70)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'OK',
              style: TextStyle(color: Color(0xFF4E6E3A)),
            ),
          ),
        ],
      ),
    );
  }
}

class LeafPainter extends CustomPainter {
  final Color color;

  LeafPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;

    final centerX = size.width / 2;

    final path = Path();
    path.moveTo(centerX, 0);
    path.cubicTo(
      centerX + size.width * 0.222,
      -size.height * 0.756,
      centerX + size.width * 0.778,
      -size.height * 0.756,
      centerX + size.width,
      0,
    );
    path.cubicTo(
      centerX + size.width * 0.778,
      size.height * 0.444,
      centerX + size.width * 0.222,
      size.height * 0.444,
      centerX,
      0,
    );
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant LeafPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
