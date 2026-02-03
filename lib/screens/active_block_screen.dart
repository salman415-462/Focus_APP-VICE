import 'dart:async';
import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import '../services/method_channel_service.dart';

class ActiveBlockScreen extends StatefulWidget {
  const ActiveBlockScreen({super.key});

  @override
  State<ActiveBlockScreen> createState() => _ActiveBlockScreenState();
}

class _ActiveBlockScreenState extends State<ActiveBlockScreen> {
  bool _isLoading = true;
  bool _hasError = false;
  bool _isBypassActive = false;
  int _bypassRemainingSeconds = 0;
  List<Map<String, dynamic>> _activeTimers = [];
  bool _showSecondaryTimers = false;

  int _pomodoroFocusDuration = 25;
  int _pomodoroBreakDuration = 5;
  int _pomodoroCycles = 4;
  int _currentCycle = 1;

  bool _isNavigating = false;

  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadBlockStatus();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _initializePomodoroState() {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null) {
      _pomodoroFocusDuration = args['pomodoroFocusDuration'] ?? 25;
      _pomodoroBreakDuration = args['pomodoroBreakDuration'] ?? 5;
      _pomodoroCycles = args['pomodoroCycles'] ?? 4;
      _currentCycle = 1;
    }
  }

  Future<void> _loadBlockStatus() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final timers = await MethodChannelService.getActiveTimers();
      if (!mounted) return;

      final status = await MethodChannelService.getBlockStatus();
      if (!mounted) return;

      setState(() {
        _activeTimers = timers;
        _isBypassActive = status['bypassActive'] as bool? ?? false;

        if (_isBypassActive && _bypassRemainingSeconds == 0) {
          _bypassRemainingSeconds = 120;
          _startBypassCountdown();
        }

        _isLoading = false;
      });

      if (_activeTimers.isEmpty && !_isBypassActive) {
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted || _isNavigating) return;
        _isNavigating = true;
        Navigator.pop(context);
        return;
      }

      _startPolling();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
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
    if (!mounted || _isNavigating) return;

    try {
      final timers = await MethodChannelService.getActiveTimers();
      if (!mounted || _isNavigating) return;

      final status = await MethodChannelService.getBlockStatus();
      if (!mounted || _isNavigating) return;

      setState(() {
        _activeTimers = timers;
        _isBypassActive = status['bypassActive'] as bool? ?? false;
      });

      _handleTimerExpiration();

      if (_activeTimers.isEmpty && !_isBypassActive) {
        _refreshTimer?.cancel();
        _isNavigating = true;
        Navigator.pop(context);
      }
    } catch (e) {}
  }

  void _handleTimerExpiration() {
    final expiredPomodoroTimers = _activeTimers.where((timer) {
      final remainingSeconds = timer['remainingSeconds'] as int? ?? 0;
      final mode = timer['mode'] as String? ?? '';
      return remainingSeconds <= 0 &&
          (mode == 'POMODORO_FOCUS' || mode == 'POMODORO_BREAK');
    }).toList();

    for (final expiredTimer in expiredPomodoroTimers) {
      final mode = expiredTimer['mode'] as String? ?? '';
      if (mode == 'POMODORO_FOCUS') {
        if (_currentCycle < _pomodoroCycles) {
          _startBreakTimer();
        } else {
          _showSessionEndedDialog();
        }
      } else if (mode == 'POMODORO_BREAK') {
        if (_currentCycle < _pomodoroCycles) {
          _currentCycle++;
          _startFocusTimer();
        } else {
          _showSessionEndedDialog();
        }
      }
    }
  }

  Future<void> _startFocusTimer() async {
    try {
      await MethodChannelService.startPomodoroFocusTimer(
        durationMinutes: _pomodoroFocusDuration,
      );
    } catch (e) {}
  }

  Future<void> _startBreakTimer() async {
    try {
      await MethodChannelService.startPomodoroBreakTimer(
        durationMinutes: _pomodoroBreakDuration,
      );
    } catch (e) {}
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
        return 'Break';
      case 'FOCUS':
      default:
        return 'Focus Session';
    }
  }

  Color _getModeColor(String mode) {
    switch (mode) {
      case 'POMODORO_FOCUS':
        return const Color(0xFFE53935);
      case 'POMODORO_BREAK':
        return const Color(0xFF4CAF50);
      case 'FOCUS':
      default:
        return const Color(0xFF2F6F73);
    }
  }

  double _getProgress(int remainingSeconds, int totalSeconds) {
    if (totalSeconds <= 0) return 0;
    return remainingSeconds / totalSeconds;
  }

  void _requestBypass() {
    if (_isNavigating) return;

    // Check if PIN is set
    MethodChannelService.isBypassPinSet().then((isPinSet) {
      if (!mounted || _isNavigating) return;

      if (isPinSet) {
        // PIN is set, show Enter PIN dialog
        _showEnterPinDialog();
      } else {
        // PIN is not set, show Set PIN dialog
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
        backgroundColor: const Color(0xFF151B28),
        title: const Text(
          'Set Bypass PIN',
          style: TextStyle(color: Color(0xFFF4F3EF)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Set a PIN to protect emergency bypass. You will need this PIN to use bypass.',
              style: TextStyle(color: Color(0xFF9FBFC1)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: pinController,
              keyboardType: TextInputType.number,
              maxLength: 8,
              obscureText: true,
              style: const TextStyle(color: Color(0xFFF4F3EF)),
              decoration: const InputDecoration(
                labelText: 'Enter PIN (4-8 digits)',
                labelStyle: TextStyle(color: Color(0xFF9FBFC1)),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF4FA3A5)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF4FA3A5)),
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
              style: TextStyle(color: Color(0xFF9FBFC1)),
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
              backgroundColor: const Color(0xFF4FA3A5),
              foregroundColor: const Color(0xFF0C0F16),
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
        backgroundColor: const Color(0xFF151B28),
        title: const Text(
          'Enter Bypass PIN',
          style: TextStyle(color: Color(0xFFF4F3EF)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter your PIN to activate emergency bypass.',
              style: TextStyle(color: Color(0xFF9FBFC1)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: pinController,
              keyboardType: TextInputType.number,
              maxLength: 8,
              obscureText: true,
              style: const TextStyle(color: Color(0xFFF4F3EF)),
              decoration: const InputDecoration(
                labelText: 'Enter PIN',
                labelStyle: TextStyle(color: Color(0xFF9FBFC1)),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF4FA3A5)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF4FA3A5)),
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
              style: TextStyle(color: Color(0xFF9FBFC1)),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final pin = pinController.text;
              Navigator.pop(context);
              await _verifyAndTriggerBypass(pin);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B5A5A),
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

  Future<void> _triggerBypass() async {
    if (_isNavigating) return;

    try {
      final success = await MethodChannelService.requestEmergencyBypass('*');
      if (!mounted || _isNavigating) return;

      if (success) {
        setState(() {
          _isBypassActive = true;
          _bypassRemainingSeconds = 120;
        });
        _startBypassCountdown();
      } else {
        _showErrorDialog(
            'Could not activate bypass. One may already be active.');
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
        backgroundColor: const Color(0xFF151B28),
        title: const Text(
          'Error',
          style: TextStyle(color: Color(0xFFF4F3EF)),
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

  void _showSessionEndedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF151B28),
        title: const Text(
          'Session Ended',
          style: TextStyle(color: Color(0xFFF4F3EF)),
        ),
        content: const Text(
          'Your focus session has ended. You can now use your apps normally.',
          style: TextStyle(color: Color(0xFF9FBFC1)),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _exitScreen();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4FA3A5),
              foregroundColor: const Color(0xFF0C0F16),
            ),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _exitScreen() {
    if (_isNavigating) return;
    _isNavigating = true;
    _refreshTimer?.cancel();
    Navigator.pushReplacementNamed(context, '/home');
  }

  void _confirmExit() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF151B28),
        title: const Text(
          'End Session?',
          style: TextStyle(color: Color(0xFFF4F3EF)),
        ),
        content: const Text(
          'Are you sure you want to end your focus session early?',
          style: TextStyle(color: Color(0xFF9FBFC1)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF9FBFC1)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _exitScreen();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B5A5A),
              foregroundColor: const Color(0xFFF4F3EF),
            ),
            child: const Text('End Session'),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveControlItem({
    required String title,
    required String subtitle,
    required bool isSelected,
  }) {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1B2230), Color(0xFF151B28)],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF4FA3A5) : Colors.transparent,
              shape: BoxShape.circle,
              border: !isSelected
                  ? Border.all(color: const Color(0xFF9FBFC1), width: 2)
                  : null,
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
                    fontSize: 14,
                    color: Color(0xFFF4F3EF),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9FBFC1),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C0F16),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C0F16),
        elevation: 0,
        title: const Text(
          'Focus Active',
          style: TextStyle(
            color: Color(0xFFF4F3EF),
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFFF4F3EF)),
          onPressed: _isNavigating ? null : () => Navigator.pop(context),
        ),
        actions: [
          if (_activeTimers.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1B2230),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.timer, color: Color(0xFF4FA3A5), size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '${_activeTimers.length} active',
                    style: const TextStyle(
                      color: Color(0xFFF4F3EF),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF4FA3A5),
              ),
            )
          : SafeArea(
              child: Stack(
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF0C0F16), Color(0xFF141722)],
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Center(
                      child: CustomPaint(
                        size: const Size(800, 800),
                        painter: FocusFieldPainter(),
                      ),
                    ),
                  ),
                  SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          if (_hasError) ...[
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF4D1A1A),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  const Icon(Icons.warning,
                                      color: Color(0xFFCF6679)),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Could not load block status.',
                                      style: TextStyle(
                                          color: Colors.white.withOpacity(0.9)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (_activeTimers.isEmpty && !_isBypassActive) ...[
                            const SizedBox(height: 120),
                            Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Color(0xFF1B2230),
                                    Color(0xFF151B28)
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                children: [
                                  const Icon(
                                    Icons.timer_off,
                                    size: 64,
                                    color: Color(0xFF9FBFC1),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'No Active Focus Session',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFFF4F3EF),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Redirecting...',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.white.withOpacity(0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 120),
                          ],
                          if (_activeTimers.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            _buildPrimaryTimer(),
                            const SizedBox(height: 16),
                            const Text(
                              'Time remaining',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF9FBFC1),
                              ),
                            ),
                            const SizedBox(height: 32),
                            Container(
                              height: 1,
                              color: const Color(0xFF243036),
                            ),
                            const SizedBox(height: 16),
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Active controls',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFFF4F3EF),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildActiveControlItem(
                              title: 'App Blocking',
                              subtitle: 'Selected apps restricted',
                              isSelected: true,
                            ),
                            const SizedBox(height: 8),
                            _buildActiveControlItem(
                              title: 'Pomodoro',
                              subtitle: 'Focus interval running',
                              isSelected: false,
                            ),
                            const SizedBox(height: 80),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (_activeTimers.isNotEmpty)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Color(0xFF0C0F16)],
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Emergency bypass',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF8B5A5A),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton(
                                onPressed: _isBypassActive || _isNavigating
                                    ? null
                                    : _requestBypass,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isBypassActive
                                      ? const Color(0xFF2A2A3E)
                                      : const Color(0xFF8B5A5A),
                                  foregroundColor: const Color(0xFFF4F3EF),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  _isBypassActive
                                      ? 'Bypass (${_formatTime(_bypassRemainingSeconds)})'
                                      : 'Emergency Bypass (2 min)',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildPrimaryTimer() {
    // Use the earliest-ending timer as primary, others run in background
    // Use explicit loop instead of reduce() to avoid type issues with MethodChannel maps
    Map<String, dynamic>? primaryTimer;

    if (_activeTimers.isNotEmpty) {
      primaryTimer = _activeTimers.first;

      for (final timer in _activeTimers.skip(1)) {
        final currentRemaining = primaryTimer!['remainingSeconds'] as int? ?? 0;
        final nextRemaining = timer['remainingSeconds'] as int? ?? 0;

        if (nextRemaining < currentRemaining) {
          primaryTimer = timer;
        }
      }
    }

    final remainingSeconds = primaryTimer?['remainingSeconds'] as int? ?? 0;
    final durationMinutes = primaryTimer?['durationMinutes'] as int? ?? 0;
    final mode = primaryTimer?['mode'] as String? ?? 'FOCUS';
    final totalSeconds = durationMinutes * 60;
    final progress = _getProgress(remainingSeconds, totalSeconds);
    final modeColor = _getModeColor(mode);

    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 108,
              height: 108,
              child: CircularProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                strokeWidth: 4,
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(modeColor),
              ),
            ),
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: modeColor,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  _formatTime(remainingSeconds),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0C0F16),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_activeTimers.length > 1) ...[
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {
              setState(() {
                _showSecondaryTimers = !_showSecondaryTimers;
              });
            },
            child: Text(
              _showSecondaryTimers
                  ? 'Hide ${_activeTimers.length - 1} active'
                  : '+${_activeTimers.length - 1} more active',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF9FBFC1),
              ),
            ),
          ),
          if (_showSecondaryTimers)
            ..._activeTimers.skip(1).map(_buildSecondaryTimerItem).toList(),
        ],
      ],
    );
  }

  List<String> _getAppNamesFromPackages(List<String> packages) {
    return packages;
  }

  Widget _buildSecondaryTimerItem(Map<String, dynamic> timer) {
    final remaining = timer['remainingSeconds'] as int? ?? 0;
    final minutes = remaining ~/ 60;
    final seconds = remaining % 60;
    final mode = timer['mode'] as String? ?? 'FOCUS';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              mode,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF9FBFC1),
              ),
            ),
            Text(
              '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFFE5E7EB),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FocusFieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.32);
    final radius = size.width * 0.45;

    final gradient = RadialGradient(
      colors: [
        const Color(0xFF1E2E30).withOpacity(0.65),
        const Color(0xFF0C0F16).withOpacity(0),
      ],
    );

    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
