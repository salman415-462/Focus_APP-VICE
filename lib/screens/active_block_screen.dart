import 'dart:async';
import 'dart:ui' show PathMetric, PathMetrics, Tangent, Offset;
import 'package:flutter/material.dart';
import '../services/method_channel_service.dart';

class ActiveBlockScreen extends StatefulWidget {
  const ActiveBlockScreen({super.key});

  @override
  State<ActiveBlockScreen> createState() => _ActiveBlockScreenState();
}

class _ActiveBlockScreenState extends State<ActiveBlockScreen>
    with SingleTickerProviderStateMixin {
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
  AnimationController? _riverController;

  @override
  void initState() {
    super.initState();
    _loadBlockStatus();
    _riverController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _riverController?.dispose();
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

  bool _hasAppBlockingActive() {
    return _activeTimers.any((timer) {
      final mode = timer['mode'] as String? ?? '';
      return mode == 'FOCUS' ||
          mode == 'POMODORO_FOCUS' ||
          mode == 'POMODORO_BREAK';
    });
  }

  bool _hasPomodoroActive() {
    return _activeTimers.any((timer) {
      final mode = timer['mode'] as String? ?? '';
      return mode == 'POMODORO_FOCUS' || mode == 'POMODORO_BREAK';
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
              'Set a PIN to protect emergency bypass. You will need this PIN to use bypass.',
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

  void _showSessionEndedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFFFDF2),
        title: const Text(
          'Session Ended',
          style: TextStyle(color: Color(0xFF2C2C25)),
        ),
        content: const Text(
          'Your focus session has ended. You can now use your apps normally.',
          style: TextStyle(color: Color(0xFF7A7A70)),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _exitScreen();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4E6E3A),
              foregroundColor: const Color(0xFFF4F3EF),
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
        backgroundColor: const Color(0xFFFFFDF2),
        title: const Text(
          'End Session?',
          style: TextStyle(color: Color(0xFF2C2C25)),
        ),
        content: const Text(
          'Are you sure you want to end your focus session early?',
          style: TextStyle(color: Color(0xFF7A7A70)),
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
            onPressed: () {
              Navigator.pop(context);
              _exitScreen();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B6B6B),
              foregroundColor: const Color(0xFFF4F3EF),
            ),
            child: const Text('End Session'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final scaleFactor = screenWidth / 360;

    return Scaffold(
      backgroundColor: Colors.transparent,
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
        child: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: SunlightPainter(),
                ),
              ),
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _riverController!,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: RiverPainter(
                        animationValue: _riverController!.value * 320,
                      ),
                    );
                  },
                ),
              ),
              Positioned.fill(
                child: SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: MediaQuery.of(context).size.height,
                    ),
                    child: Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 24 * scaleFactor),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 24 * scaleFactor),
                          _buildHeader(scaleFactor),
                          if (_hasError) ...[
                            SizedBox(height: 16 * scaleFactor),
                            _buildErrorBanner(scaleFactor),
                          ],
                          if (_activeTimers.isEmpty && !_isBypassActive) ...[
                            SizedBox(height: 120 * scaleFactor),
                            _buildEmptyState(scaleFactor),
                            SizedBox(height: 120 * scaleFactor),
                          ],
                          if (_activeTimers.isNotEmpty) ...[
                            SizedBox(height: 150 * scaleFactor),
                            _buildTimerCard(scaleFactor),
                            SizedBox(height: 40 * scaleFactor),
                            _buildActiveControlsCard(scaleFactor),
                            SizedBox(height: 168 * scaleFactor),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (_activeTimers.isNotEmpty)
                Positioned(
                  bottom: 80 * scaleFactor,
                  left: 0,
                  right: 0,
                  child: _buildEmergencyBypass(scaleFactor),
                ),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: LeavesPainter(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(double scaleFactor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Focus in progress',
          style: TextStyle(
            fontSize: 18 * scaleFactor,
            color: const Color(0xFF2C2C25).withOpacity(0.85),
          ),
        ),
        Container(
          padding: EdgeInsets.symmetric(
              horizontal: 12 * scaleFactor, vertical: 4 * scaleFactor),
          decoration: BoxDecoration(
            color: const Color(0xFFE6EFE3),
            borderRadius: BorderRadius.circular(14 * scaleFactor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 10 * scaleFactor,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            '${_activeTimers.length} active',
            style: TextStyle(
              fontSize: 13 * scaleFactor,
              color: const Color(0xFF4E6E3A).withOpacity(0.9),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorBanner(double scaleFactor) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE6EFE3),
        borderRadius: BorderRadius.circular(8 * scaleFactor),
      ),
      padding: EdgeInsets.all(12 * scaleFactor),
      child: Row(
        children: [
          const Icon(Icons.warning, color: Color(0xFF4E6E3A)),
          SizedBox(width: 12 * scaleFactor),
          Expanded(
            child: Text(
              'Could not load block status.',
              style: TextStyle(
                color: const Color(0xFF2C2C25).withOpacity(0.7),
                fontSize: 13 * scaleFactor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(double scaleFactor) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF2),
        borderRadius: BorderRadius.circular(32 * scaleFactor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12 * scaleFactor,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: EdgeInsets.all(32 * scaleFactor),
      child: Column(
        children: [
          Icon(
            Icons.timer_off,
            size: 64 * scaleFactor,
            color: const Color(0xFF7A7A70).withOpacity(0.8),
          ),
          SizedBox(height: 16 * scaleFactor),
          Text(
            'No Active Focus Session',
            style: TextStyle(
              fontSize: 20 * scaleFactor,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF2C2C25),
            ),
          ),
          SizedBox(height: 8 * scaleFactor),
          Text(
            'Redirecting...',
            style: TextStyle(
              fontSize: 14 * scaleFactor,
              color: const Color(0xFF2C2C25).withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimerCard(double scaleFactor) {
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

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF2),
        borderRadius: BorderRadius.circular(32 * scaleFactor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 14 * scaleFactor,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: EdgeInsets.symmetric(
          horizontal: 54 * scaleFactor, vertical: 40 * scaleFactor),
      child: Column(
        children: [
          Text(
            _formatTime(remainingSeconds),
            style: TextStyle(
              fontSize: 48 * scaleFactor,
              color: const Color(0xFF242420).withOpacity(0.9),
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 14 * scaleFactor),
          Text(
            'remaining',
            style: TextStyle(
              fontSize: 14 * scaleFactor,
              color: const Color(0xFF7A7A70).withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveControlsCard(double scaleFactor) {
    final appBlockingActive = _hasAppBlockingActive();
    final pomodoroActive = _hasPomodoroActive();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(32 * scaleFactor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12 * scaleFactor,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: EdgeInsets.symmetric(
          horizontal: 24 * scaleFactor, vertical: 24 * scaleFactor),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Protections active',
            style: TextStyle(
              fontSize: 15 * scaleFactor,
              color: const Color(0xFF2C2C25).withOpacity(0.85),
            ),
          ),
          SizedBox(height: 20 * scaleFactor),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'App blocking',
                style: TextStyle(
                  fontSize: 13 * scaleFactor,
                  color: const Color(0xFF7A7A70).withOpacity(0.8),
                ),
              ),
              Text(
                appBlockingActive ? 'On' : 'Off',
                style: TextStyle(
                  fontSize: 13 * scaleFactor,
                  color: appBlockingActive
                      ? const Color(0xFF4E6E3A).withOpacity(0.85)
                      : const Color(0xFF7A7A70).withOpacity(0.7),
                ),
              ),
            ],
          ),
          SizedBox(height: 18 * scaleFactor),
          Container(
            height: 1,
            color: const Color(0xFFE0DED6).withOpacity(0.6),
          ),
          SizedBox(height: 18 * scaleFactor),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Pomodoro rhythm',
                style: TextStyle(
                  fontSize: 13 * scaleFactor,
                  color: const Color(0xFF7A7A70).withOpacity(0.8),
                ),
              ),
              Text(
                pomodoroActive ? 'On' : 'Off',
                style: TextStyle(
                  fontSize: 13 * scaleFactor,
                  color: pomodoroActive
                      ? const Color(0xFF4E6E3A).withOpacity(0.85)
                      : const Color(0xFF7A7A70).withOpacity(0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyBypass(double scaleFactor) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24 * scaleFactor),
      child: Column(
        children: [
          GestureDetector(
            onTap: _isBypassActive || _isNavigating ? null : _requestBypass,
            child: Text(
              'Emergency bypass',
              style: TextStyle(
                fontSize: 13 * scaleFactor,
                color: const Color(0xFF8B6B6B).withOpacity(0.75),
                decoration: TextDecoration.underline,
              ),
            ),
          ),
          SizedBox(height: 8 * scaleFactor),
          SizedBox(
            width: double.infinity,
            height: 48 * scaleFactor,
            child: ElevatedButton(
              onPressed:
                  _isBypassActive || _isNavigating ? null : _requestBypass,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isBypassActive
                    ? const Color(0xFFE0DED6).withOpacity(0.6)
                    : const Color(0xFF9C8585).withOpacity(0.7),
                foregroundColor: const Color(0xFFF4F3EF).withOpacity(0.9),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12 * scaleFactor),
                ),
                shadowColor: Colors.black.withOpacity(0.05),
                elevation: 4,
              ),
              child: Text(
                _isBypassActive
                    ? 'Bypass (${_formatTime(_bypassRemainingSeconds)})'
                    : 'Emergency Bypass (2 min)',
                style: TextStyle(
                  fontSize: 14 * scaleFactor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SunlightPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.2, 0);
    final radius = size.width * 1.4;

    final gradient = RadialGradient(
      colors: [
        const Color(0xFFFFF2B0).withOpacity(0.35),
        const Color(0xFFFFF2B0).withOpacity(0),
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

class RiverPainter extends CustomPainter {
  final double animationValue;

  RiverPainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    path.moveTo(220, -80);
    path.cubicTo(260, 120, 180, 260, 220, 420);
    path.cubicTo(260, 600, 180, 760, 220, 900);

    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        const Color(0xFFD9F2EC).withOpacity(0.35),
        const Color(0xFFB7DDD4).withOpacity(0.25),
      ],
    );

    final paint = Paint()
      ..shader =
          gradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 36
      ..strokeCap = StrokeCap.round;

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final dashArray = <double>[80, 80];

    Path dashPath = Path();
    PathMetrics pathMetrics = path.computeMetrics();
    bool drawDash = true;
    double currentDashLength = 0;

    for (PathMetric metric in pathMetrics) {
      double length = metric.length;
      double distance = 0;

      while (distance < length) {
        if (drawDash) {
          double remainingDash = dashArray[0] - currentDashLength;
          double segmentLength = remainingDash.clamp(0, length - distance);

          Tangent? tangent = metric.getTangentForOffset(distance);
          if (tangent != null) {
            dashPath.moveTo(tangent.position.dx, tangent.position.dy);
          }

          Tangent? endTangent =
              metric.getTangentForOffset(distance + segmentLength);
          if (endTangent != null) {
            dashPath.lineTo(endTangent.position.dx, endTangent.position.dy);
          }

          distance += segmentLength;
          currentDashLength += segmentLength;

          if (currentDashLength >= dashArray[0]) {
            drawDash = false;
            currentDashLength = 0;
          }
        } else {
          double gapLength = dashArray[1].clamp(0, length - distance);
          distance += gapLength;
          drawDash = true;
        }
      }
    }

    canvas.drawPath(dashPath, paint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class LeavesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / 360;
    final scaleY = size.height / 800;

    final bigLeafPaint = Paint()
      ..color = const Color(0xFF5F7743).withOpacity(0.65)
      ..style = PaintingStyle.fill;

    canvas.save();
    canvas.scale(scaleX, scaleY);
    canvas.translate(-30, 640);
    canvas.rotate(-18 * 3.14159 / 180);
    _drawBigLeaf(canvas, bigLeafPaint);
    canvas.restore();

    canvas.save();
    canvas.scale(scaleX, scaleY);
    canvas.translate(260, 80);
    canvas.rotate(22 * 3.14159 / 180);
    _drawBigLeaf(canvas, bigLeafPaint);
    canvas.restore();
  }

  void _drawBigLeaf(Canvas canvas, Paint paint) {
    final path = Path();
    path.moveTo(0, 0);
    path.cubicTo(20, -34, 70, -34, 90, 0);
    path.cubicTo(70, 20, 20, 20, 0, 0);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
