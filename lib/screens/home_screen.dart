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

      setState(() {
        _activeTimers = timers;
      });
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

  void _navigateToModeSelection() {
    Navigator.pushNamed(context, '/mode-selection');
  }

  Widget _buildEmptyState() {
    return Column(
      children: [
        const SizedBox(height: 140),
        CustomPaint(
          size: const Size(92, 92),
          painter: EmptyTimerIconPainter(),
        ),
        const SizedBox(height: 40),
        const Text(
          'No active sessions',
          style: TextStyle(
            color: Color(0xFFF4F3EF),
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          "Start a focus session when you're ready",
          style: TextStyle(
            color: Color(0xFF9FBFC1),
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 72),
        Container(
          width: 140,
          height: 48,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF3B7F83), Color(0xFF2F6F73)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(18),
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
                color: Color(0xFF0C0F16),
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
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
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                size: Size.infinite,
                painter: CenterLiftPainter(),
              ),
            ),
            SafeArea(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF4FA3A5),
                      ),
                    )
                  : Column(
                      children: [
                        const SizedBox(height: 32),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Focus Guard',
                                style: TextStyle(
                                  color: Color(0xFFF4F3EF),
                                  fontSize: 20,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              GestureDetector(
                                onTap: _navigateToModeSelection,
                                child: const Text(
                                  '+',
                                  style: TextStyle(
                                    color: Color(0xFF9FBFC1),
                                    fontSize: 22,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 44),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Active Sessions',
                                style: TextStyle(
                                  color: Color(0xFFF4F3EF),
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                '${_activeTimers.length} active',
                                style: const TextStyle(
                                  color: Color(0xFF9FBFC1),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (_activeTimers.isNotEmpty)
                          Expanded(
                            child: ListView.builder(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _activeTimers.length,
                              itemBuilder: (context, index) {
                                final timer = _activeTimers[index];
                                final remainingSeconds =
                                    timer['remainingSeconds'] as int? ?? 0;
                                final durationMinutes =
                                    timer['durationMinutes'] as int? ?? 0;
                                final mode =
                                    timer['mode'] as String? ?? 'FOCUS';
                                final blockedPackages =
                                    (timer['blockedPackages'] as List?)
                                            ?.map((e) => e.toString())
                                            .toList() ??
                                        [];
                                final totalSeconds = durationMinutes * 60;
                                final progress = _getProgress(
                                    remainingSeconds, totalSeconds);

                                return _buildTimerCard(
                                  progress: progress,
                                  remainingSeconds: remainingSeconds,
                                  totalSeconds: totalSeconds,
                                  mode: mode,
                                  blockedPackages: blockedPackages,
                                );
                              },
                            ),
                          )
                        else
                          Expanded(child: _buildEmptyState()),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimerCard({
    required double progress,
    required int remainingSeconds,
    required int totalSeconds,
    required String mode,
    List<String> blockedPackages = const [],
  }) {
    final modeColor = _getModeColor(mode);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: modeColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: modeColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _getModeLabel(mode),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: modeColor,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: CircularProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  strokeWidth: 6,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(modeColor),
                ),
              ),
              Container(
                width: 100,
                height: 100,
                decoration: const BoxDecoration(
                  color: Color(0xFF1A1A2E),
                  shape: BoxShape.circle,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _formatTime(remainingSeconds),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        fontFeatures: [
                          FontFeature.tabularFigures(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'REMAINING',
                      style: TextStyle(
                        fontSize: 8,
                        color: Colors.white54,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (totalSeconds > 0) ...[
            Text(
              'Total: ${totalSeconds ~/ 60} min',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white38,
              ),
            ),
          ],
          if (blockedPackages.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '${blockedPackages.length} app${blockedPackages.length == 1 ? '' : 's'} blocked',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white54,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class CenterLiftPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.45);
    final radius = size.width * 0.55;

    final gradient = RadialGradient(
      colors: [
        const Color(0xFF1C2430).withOpacity(0.6),
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

class EmptyTimerIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = 46.0;

    final circlePaint = Paint()
      ..color = const Color(0xFF161C29)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, circlePaint);

    final borderPaint = Paint()
      ..color = const Color(0xFF2E3A4A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(center, radius, borderPaint);

    final linePaint = Paint()
      ..color = const Color(0xFF6B7C93)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(center.dx - 16, center.dy - 16),
      Offset(center.dx + 16, center.dy + 16),
      linePaint,
    );

    final innerCirclePaint = Paint()
      ..color = Colors.transparent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, 14, innerCirclePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
