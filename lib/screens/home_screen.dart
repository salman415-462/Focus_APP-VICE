import 'dart:async';
import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import '../services/method_channel_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> _activeTimers = [];
  bool _isLoading = true;
  Timer? _refreshTimer;
  bool _isBypassActive = false;
  int _bypassRemainingSeconds = 0;
  bool _isNavigating = false;
  bool _isAppBlockingActive = false;
  bool _isPomodoroRhythmActive = false;

  @override
  void initState() {
    super.initState();
    _checkPermissionsAndLoad();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkPermissionsAndLoad() async {
    try {
      final status = await MethodChannelService.getPermissionStatus();
      final allPermissionsEnabled =
          (status['accessibility_enabled'] as bool? ?? false) &&
              (status['overlay_enabled'] as bool? ?? false) &&
              (status['device_admin_enabled'] as bool? ?? false);

      if (allPermissionsEnabled) {
        _loadActiveTimers();
      } else {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/permissions');
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/permissions');
      }
    }
  }

  Future<void> _loadActiveTimers() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final timers = await MethodChannelService.getActiveTimers();
      if (!mounted) return;

      setState(() {
        _activeTimers = timers;
        _isLoading = false;
      });

      _startPolling();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _startPolling() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _refreshTimers(),
    );
  }

  Future<void> _refreshTimers() async {
    if (!mounted) return;

    try {
      final timers = await MethodChannelService.getActiveTimers();
      if (!mounted) return;

      final status = await MethodChannelService.getBlockStatus();
      if (!mounted) return;

      final hasPomodoro = timers.any((t) =>
          t['mode'] == 'POMODORO_FOCUS' || t['mode'] == 'POMODORO_BREAK');

      setState(() {
        _activeTimers = timers;
        _isBypassActive = status['bypassActive'] as bool? ?? false;
        _isAppBlockingActive = status['isBlockActive'] as bool? ?? false;
        _isPomodoroRhythmActive = hasPomodoro;
      });

      _handleBypassCountdown();
    } catch (e) {}
  }

  String _formatTime(int totalSeconds) {
    if (totalSeconds <= 0) return '0:00';
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _getModeLabel(String mode) {
    switch (mode) {
      case 'POMODORO_FOCUS':
        return 'Pomodoro Focus';
      case 'POMODORO_BREAK':
        return 'Pomodoro Break';
      case 'FOCUS':
      default:
        return 'App Blocking';
    }
  }

  String _humanizeAppName(String packageName) {
    final parts = packageName.split('.');
    final lastPart = parts.isNotEmpty ? parts.last : packageName;
    return lastPart[0].toUpperCase() + lastPart.substring(1);
  }

  List<Map<String, dynamic>> _getHeroAndSecondaryTimers() {
    final validTimers = _activeTimers
        .where((t) => (t['remainingSeconds'] as int? ?? 0) > 0)
        .toList()
      ..sort((a, b) => (a['remainingSeconds'] as int)
          .compareTo(b['remainingSeconds'] as int));
    if (validTimers.isEmpty) return [];
    final hero = validTimers.first;
    final secondary = validTimers.skip(1).toList();
    return [hero, ...secondary];
  }

  void _navigateToStats() {
    Navigator.pushNamed(context, '/stats');
  }

  void _navigateToModeSelection() {
    Navigator.pushNamed(context, '/mode-selection');
  }

  void _handleBypassCountdown() {
    if (_isBypassActive && _bypassRemainingSeconds == 0) {
      _bypassRemainingSeconds = 120;
      _startBypassCountdown();
    }
  }

  void _startBypassCountdown() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() {
        if (_bypassRemainingSeconds > 0) {
          _bypassRemainingSeconds--;
        } else {
          _isBypassActive = false;
        }
      });
      if (_isBypassActive && mounted) {
        _startBypassCountdown();
      }
    });
  }

  void _requestBypass() {
    if (_isNavigating) return;

    MethodChannelService.isBypassPinSet().then((isPinSet) {
      if (!mounted || _isNavigating) return;

      if (isPinSet) {
        _showEnterPinDialog();
      } else {
        _showSetPinDialog();
      }
    });
  }

  void _showSetPinDialog() {
    final pinController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFFFDF2),
        title: const Text(
          'Set Bypass PIN',
          style: TextStyle(color: Color(0xFF2C2C25)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Set a PIN to protect emergency bypass.',
              style: TextStyle(color: Color(0xFF7A7A70)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: pinController,
              keyboardType: TextInputType.number,
              maxLength: 8,
              obscureText: true,
              style: const TextStyle(color: Color(0xFF2C2C25)),
              decoration: const InputDecoration(
                labelText: 'Enter PIN (4-8 digits)',
                labelStyle: TextStyle(color: Color(0xFF7A7A70)),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF4E6E3A)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF4E6E3A)),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF7A7A70)),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final pin = pinController.text;
              if (pin.length < 4) {
                _showErrorDialog('PIN must be at least 4 digits');
                return;
              }

              Navigator.pop(context);
              final success = await MethodChannelService.setBypassPin(pin);
              if (!mounted) return;

              if (success) {
                _showEnterPinDialog();
              } else {
                _showErrorDialog('Failed to set PIN');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4E6E3A),
              foregroundColor: const Color(0xFFF4F3EF),
            ),
            child: const Text('Set PIN'),
          ),
        ],
      ),
    );
  }

  void _showEnterPinDialog() {
    final pinController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFFFDF2),
        title: const Text(
          'Enter Bypass PIN',
          style: TextStyle(color: Color(0xFF2C2C25)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter your PIN to activate emergency bypass.',
              style: TextStyle(color: Color(0xFF7A7A70)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: pinController,
              keyboardType: TextInputType.number,
              maxLength: 8,
              obscureText: true,
              style: const TextStyle(color: Color(0xFF2C2C25)),
              decoration: const InputDecoration(
                labelText: 'Enter PIN',
                labelStyle: TextStyle(color: Color(0xFF7A7A70)),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF4E6E3A)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF4E6E3A)),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF7A7A70)),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final pin = pinController.text;
              Navigator.pop(context);
              await _verifyAndTriggerBypass(pin);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B6B6B),
              foregroundColor: const Color(0xFFF4F3EF),
            ),
            child: const Text('Verify PIN'),
          ),
        ],
      ),
    );
  }

  Future<void> _verifyAndTriggerBypass(String pin) async {
    if (_isNavigating) return;

    try {
      final success =
          await MethodChannelService.requestEmergencyBypassWithPin('*', pin);
      if (!mounted || _isNavigating) return;

      if (success) {
        setState(() {
          _isBypassActive = true;
          _bypassRemainingSeconds = 120;
        });
        _startBypassCountdown();
      } else {
        _showErrorDialog('Incorrect PIN. Bypass denied.');
      }
    } catch (e) {
      _showErrorDialog('Error activating bypass: ${e.toString()}');
    }
  }

  void _showErrorDialog(String message) {
    if (_isNavigating || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFFFDF2),
        title: const Text(
          'Error',
          style: TextStyle(color: Color(0xFF2C2C25)),
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

  Widget _buildEmptyState() {
    return Column(
      children: [
        const SizedBox(height: 140),
        Container(
          width: 296,
          height: 200,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.14),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: Color(0xFFE6EFE3),
                  shape: BoxShape.circle,
                ),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Color(0xFF6E8F5E),
                      width: 2,
                    ),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(height: 40),
              const Text(
                'No focus sessions yet',
                style: TextStyle(
                  color: Color(0xFF2C2C25),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'When you\'re ready, begin gently',
                style: TextStyle(
                  color: Color(0xFF7A7A70),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 40),
        Container(
          width: 216,
          height: 52,
          decoration: BoxDecoration(
            color: const Color(0xFF6E8F5E),
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.14),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: _navigateToModeSelection,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
            ),
            child: const Text(
              'Start Session',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroTimerCard({
    required String mode,
    required int remainingSeconds,
    required int totalSeconds,
    List<String> blockedPackages = const [],
  }) {
    final modeLabel = _getModeLabel(mode);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF2),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.14),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Column(
        children: [
          Text(
            modeLabel,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF7A7A70),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _formatTime(remainingSeconds),
            style: const TextStyle(
              fontSize: 64,
              fontWeight: FontWeight.w600,
              color: Color(0xFF242420),
              fontFeatures: [
                FontFeature.tabularFigures(),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Ending first',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF4E6E3A),
            ),
          ),
          if (blockedPackages.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              height: 1,
              color: Color(0xFFE0DED6).withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            _buildBlockedAppsText(blockedPackages),
          ],
        ],
      ),
    );
  }

  Widget _buildBlockedAppsText(List<String> packages) {
    if (packages.isEmpty) return const SizedBox.shrink();

    final humanizedApps = packages.map(_humanizeAppName).toList();
    final displayText = humanizedApps.length == 1
        ? 'Blocking: ${humanizedApps.first}'
        : 'Blocking ${humanizedApps.length} apps';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          displayText,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF7A7A70),
          ),
        ),
        if (humanizedApps.length > 1) ...[
          const SizedBox(height: 4),
          Text(
            humanizedApps.join(' · '),
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF9E9E92),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSecondaryTimerCard({
    required String mode,
    required int remainingSeconds,
    required int totalSeconds,
  }) {
    final modeLabel = _getModeLabel(mode);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  modeLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9E9E92),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatTime(remainingSeconds),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF7A7A70),
                    fontFeatures: [
                      FontFeature.tabularFigures(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Text(
            'Secondary',
            style: TextStyle(
              fontSize: 10,
              color: Color(0xFFB0B0A8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProtectionsCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.6),
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Protections',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF9E9E92),
                ),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'App ${_isAppBlockingActive ? 'on' : 'off'}',
                style: TextStyle(
                  fontSize: 11,
                  color: _isAppBlockingActive
                      ? Color(0xFF4E6E3A).withOpacity(0.7)
                      : Color(0xFF8B6B6B).withOpacity(0.6),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Pomodoro ${_isPomodoroRhythmActive ? 'on' : 'off'}',
                style: TextStyle(
                  fontSize: 11,
                  color: _isPomodoroRhythmActive
                      ? Color(0xFF4E6E3A).withOpacity(0.7)
                      : Color(0xFF8B6B6B).withOpacity(0.6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyBypassAvailable() {
    return GestureDetector(
      onTap: _isNavigating ? null : _requestBypass,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFFB57A7A),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Emergency bypass',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFFB57A7A),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyBypassActive() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Color(0xFFFFF2F0),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Color(0xFFE8D0CC),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: Color(0xFFD4A5A5),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Emergency bypass active',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFFB57A7A),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            _formatTime(_bypassRemainingSeconds),
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFFB57A7A),
              fontWeight: FontWeight.w600,
              fontFeatures: [
                FontFeature.tabularFigures(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sortedTimers = _getHeroAndSecondaryTimers();
    final heroTimer = sortedTimers.isNotEmpty ? sortedTimers.first : null;
    final secondaryTimers =
        sortedTimers.length > 1 ? sortedTimers.skip(1).toList() : [];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFFDF2), Color(0xFFE9E7D8)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                size: Size.infinite,
                painter: ActiveRiverAndLightPainter(
                  hasActiveTimers: heroTimer != null,
                ),
              ),
            ),
            SafeArea(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF6E8F5E),
                      ),
                    )
                  : Column(
                      children: [
                        const SizedBox(height: 24),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Focus in progress',
                                style: TextStyle(
                                  color: Color(0xFF2C2C25),
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: Color(0xFFE6EFE3).withOpacity(0.8),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${_activeTimers.length} active',
                                      style: const TextStyle(
                                        color: Color(0xFF4E6E3A),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  GestureDetector(
                                    onTap: _navigateToStats,
                                    child: const Text(
                                      'Stats',
                                      style: TextStyle(
                                        color: Color(0xFF9E9E92),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  GestureDetector(
                                    onTap: _navigateToModeSelection,
                                    child: const Text(
                                      '+',
                                      style: TextStyle(
                                        color: Color(0xFF9E9E92),
                                        fontSize: 20,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),
                        if (heroTimer != null) ...[
                          Expanded(
                            child: SingleChildScrollView(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 24),
                              child: Column(
                                children: [
                                  _buildHeroTimerCard(
                                    mode:
                                        heroTimer['mode'] as String? ?? 'FOCUS',
                                    remainingSeconds:
                                        heroTimer['remainingSeconds'] as int? ??
                                            0,
                                    totalSeconds:
                                        (heroTimer['durationMinutes'] as int? ??
                                                0) *
                                            60,
                                    blockedPackages:
                                        (heroTimer['blockedPackages'] as List?)
                                                ?.map((e) => e.toString())
                                                .toList() ??
                                            [],
                                  ),
                                  const SizedBox(height: 20),
                                  _buildProtectionsCard(),
                                  if (secondaryTimers.isNotEmpty) ...[
                                    const SizedBox(height: 20),
                                    const Text(
                                      'Other active sessions',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFFB0B0A8),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    ...secondaryTimers.map((timer) => Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 8),
                                          child: _buildSecondaryTimerCard(
                                            mode: timer['mode'] as String? ??
                                                'FOCUS',
                                            remainingSeconds:
                                                timer['remainingSeconds']
                                                        as int? ??
                                                    0,
                                            totalSeconds:
                                                (timer['durationMinutes']
                                                            as int? ??
                                                        0) *
                                                    60,
                                          ),
                                        )),
                                  ],
                                  const SizedBox(height: 28),
                                  _isBypassActive
                                      ? _buildEmergencyBypassActive()
                                      : _buildEmergencyBypassAvailable(),
                                  const SizedBox(height: 80),
                                ],
                              ),
                            ),
                          ),
                        ] else
                          Expanded(child: _buildEmptyState()),
                        const SizedBox(height: 80),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class ActiveRiverAndLightPainter extends CustomPainter {
  final bool hasActiveTimers;

  ActiveRiverAndLightPainter({required this.hasActiveTimers});

  @override
  void paint(Canvas canvas, Size size) {
    final lightPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFF2B0).withOpacity(0.4),
          const Color(0xFFFFF2B0).withOpacity(0),
        ],
        stops: const [0.0, 1.0],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.2, 0),
          radius: size.width * 0.7,
        ),
      )
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height * 0.4),
      lightPaint,
    );

    final riverPaint = Paint()
      ..color = const Color(0xFFB7DDD4).withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 40
      ..strokeCap = StrokeCap.round;

    final riverPath = Path();
    riverPath.moveTo(size.width * 0.61, -80);
    riverPath.cubicTo(
      size.width * 0.72,
      size.height * 0.15,
      size.width * 0.50,
      size.height * 0.325,
      size.width * 0.61,
      size.height * 0.525,
    );
    riverPath.cubicTo(
      size.width * 0.72,
      size.height * 0.75,
      size.width * 0.50,
      size.height * 0.95,
      size.width * 0.61,
      size.height * 1.1,
    );

    canvas.drawPath(riverPath, riverPaint);

    final leafMidPaint = Paint()
      ..color = const Color(0xFF738B4F).withOpacity(0.6)
      ..style = PaintingStyle.fill;

    final leafSmallPaint = Paint()
      ..color = const Color(0xFF8DA167).withOpacity(0.5)
      ..style = PaintingStyle.fill;

    void drawLeafMid(Paint paint, Offset offset, double rotation) {
      canvas.save();
      canvas.translate(offset.dx, offset.dy);
      canvas.rotate(rotation * 0.0174533);
      final leafPath = Path()
        ..moveTo(0, 0)
        ..cubicTo(12, -20, 40, -20, 52, 0)
        ..cubicTo(40, 12, 12, 12, 0, 0);
      canvas.drawPath(leafPath, paint);
      canvas.restore();
    }

    void drawLeafSmall(Paint paint, Offset offset, double rotation) {
      canvas.save();
      canvas.translate(offset.dx, offset.dy);
      canvas.rotate(rotation * 0.0174533);
      final leafPath = Path()
        ..moveTo(0, 0)
        ..cubicTo(6, -10, 20, -10, 28, 0)
        ..cubicTo(20, 6, 6, 6, 0, 0);
      canvas.drawPath(leafPath, paint);
      canvas.restore();
    }

    canvas.save();
    canvas.translate(20, 80);
    drawLeafSmall(leafSmallPaint, const Offset(40, 160), 0);
    drawLeafSmall(leafSmallPaint, const Offset(300, 260), 0);
    canvas.restore();

    canvas.save();
    canvas.translate(10, 60);
    drawLeafMid(leafMidPaint, const Offset(180, 100), 0);
    canvas.restore();

    final foregroundPaint = Paint()
      ..color = const Color(0xFF738B4F).withOpacity(0.5)
      ..style = PaintingStyle.fill;

    canvas.save();
    canvas.rotate(-0.20944);
    drawLeafMid(foregroundPaint, const Offset(30, 520), 0);
    canvas.restore();

    canvas.save();
    canvas.rotate(0.314159);
    drawLeafMid(foregroundPaint, const Offset(290, 580), 0);
    canvas.restore();

    canvas.save();
    canvas.rotate(-0.314159);
    final bigLeafPaint = Paint()
      ..color = const Color(0xFF5F7743).withOpacity(0.6)
      ..style = PaintingStyle.fill;
    final bigLeafPath = Path()
      ..moveTo(-20, 640)
      ..cubicTo(0, 606, 50, 606, 70, 640)
      ..cubicTo(50, 660, 0, 660, -20, 640);
    canvas.drawPath(bigLeafPath, bigLeafPaint);
    canvas.restore();

    canvas.save();
    canvas.rotate(0.383972);
    final bigLeafPath2 = Path()
      ..moveTo(260, 80)
      ..cubicTo(280, 46, 330, 46, 350, 80)
      ..cubicTo(330, 100, 280, 100, 260, 80);
    canvas.drawPath(bigLeafPath2, bigLeafPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
