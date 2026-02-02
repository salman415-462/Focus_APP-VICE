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
  bool _overlayEnabled = false;
  bool _adminEnabled = false;
  bool _hasError = false;
  bool _wasInSettings = false;
  Timer? _retryTimer;

  static const MethodChannel _refreshChannel =
      MethodChannel('core.blocker/channel');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupMethodChannelListener();
    _checkPermissions();
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _setupMethodChannelListener() {
    _refreshChannel.setMethodCallHandler((call) async {
      if (call.method == 'refreshPermissions') {
        if (mounted) {
          _wasInSettings = false;
          await _checkPermissionsWithRetry();
        }
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissionsWithRetry();
    }
  }

  Future<void> _checkPermissionsWithRetry() async {
    _retryTimer?.cancel();

    await _checkPermissions();

    if (!mounted) return;

    _retryTimer = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted) return;
      await _checkPermissions();
    });
  }

  Future<void> _checkPermissions() async {
    setState(() {
      _isCheckingPermissions = true;
      _hasError = false;
    });

    try {
      final status = await MethodChannelService.getPermissionStatus();
      if (!mounted) return;

      setState(() {
        _accessibilityEnabled = status['accessibility_enabled'] as bool;
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
    _wasInSettings = true;
    final success = await MethodChannelService.openAccessibilitySettings();
    if (!success && mounted) {
      _wasInSettings = false;
      _showFallbackHint(
        'Accessibility Settings',
        'Please open Settings > Accessibility and enable Focus Guard.',
      );
    }
  }

  void _openOverlaySettings() async {
    _wasInSettings = true;
    final success = await MethodChannelService.openOverlaySettings();
    if (!success && mounted) {
      _wasInSettings = false;
      _showFallbackHint(
        'Overlay Permission',
        'Please open Settings > Apps > Focus Guard > Permissions and enable "Display over other apps".',
      );
    }
  }

  void _openAdminSettings() async {
    _wasInSettings = true;
    await MethodChannelService.openDeviceAdminSettings();
  }

  void _showFallbackHint(String title, String message) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF151B28),
        title: Text(
          title,
          style: const TextStyle(color: Color(0xFFF4F3EF)),
        ),
        content: Text(
          message,
          style: const TextStyle(color: Color(0xFF9FBFC1)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'OK',
              style: TextStyle(color: Color(0xFF4FA3A5)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionTile({
    required String title,
    required String description,
    required bool isEnabled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 88,
        decoration: BoxDecoration(
          color: const Color(0xFF161C29),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isEnabled
                ? const Color(0xFF2F6F73).withOpacity(0.6)
                : const Color(0xFF2E3A3D).withOpacity(0.6),
            width: 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isEnabled
                    ? const Color(0xFF2F6F73)
                    : const Color(0xFF2F3A3C),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  isEnabled ? '✓' : '!',
                  style: TextStyle(
                    color: isEnabled
                        ? const Color(0xFF0C0F16)
                        : const Color(0xFFE36D6D),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFFF4F3EF),
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      color: Color(0xFF9FBFC1),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              isEnabled ? 'Enabled' : 'Enable',
              style: TextStyle(
                color: isEnabled
                    ? const Color(0xFF8FD6D6)
                    : const Color(0xFF4FA3A5),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0C0F16), Color(0xFF141722)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                height: 120,
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF141A26), Color(0xFF0C0F16)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 32),
                    const Padding(
                      padding: EdgeInsets.only(left: 24),
                      child: Text(
                        'Permissions',
                        style: TextStyle(
                          color: Color(0xFFF4F3EF),
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 26),
                    const Padding(
                      padding: EdgeInsets.only(left: 24),
                      child: Text(
                        'Required to protect your focus',
                        style: TextStyle(
                          color: Color(0xFF9FBFC1),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Padding(
                padding: EdgeInsets.only(left: 24),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Required permissions',
                    style: TextStyle(
                      color: Color(0xFFF4F3EF),
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_hasError) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF4D1A1A),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: const Row(
                      children: [
                        Icon(Icons.warning, color: Color(0xFFCF6679)),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Could not check permissions. Assuming disabled.',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              _isCheckingPermissions
                  ? const Expanded(
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF4FA3A5),
                        ),
                      ),
                    )
                  : Expanded(
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: _buildPermissionTile(
                              title: 'Accessibility Service',
                              description: 'Detects and blocks distractions',
                              isEnabled: _accessibilityEnabled,
                              onTap: _openAccessibilitySettings,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: _buildPermissionTile(
                              title: 'Overlay permission',
                              description: 'Shows focus protection',
                              isEnabled: _overlayEnabled,
                              onTap: _openOverlaySettings,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: _buildPermissionTile(
                              title: 'Device admin',
                              description: 'Prevents disabling protection',
                              isEnabled: _adminEnabled,
                              onTap: _openAdminSettings,
                            ),
                          ),
                          const Spacer(),
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton(
                                onPressed: _isCheckingPermissions
                                    ? null
                                    : () {
                                        if (_allPermissionsEnabled) {
                                          Navigator.pushReplacementNamed(
                                              context, '/home');
                                        } else {
                                          _showPermissionWarning();
                                        }
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2F6F73),
                                  foregroundColor: const Color(0xFF0C0F16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: const Text(
                                  'Continue',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ],
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
        backgroundColor: const Color(0xFF151B28),
        title: const Text(
          'Permissions Required',
          style: TextStyle(color: Color(0xFFF4F3EF)),
        ),
        content: const Text(
          'All permissions must be enabled before you can continue. Please enable the missing permissions above.',
          style: TextStyle(color: Color(0xFF9FBFC1)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'OK',
              style: TextStyle(color: Color(0xFF4FA3A5)),
            ),
          ),
        ],
      ),
    );
  }
}
