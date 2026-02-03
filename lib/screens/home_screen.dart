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
    } catch (e) {
      // Silently handle timer refresh errors
    }
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

  void _navigateToStats() {
    Navigator.pushNamed(context, '/stats');
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

  @override
  Widget build(BuildContext context) {
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
                painter: RiverAndLightPainter(),
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
                        const SizedBox(height: 32),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Vise',
                                style: TextStyle(
                                  color: Color(0xFF2C2C25),
                                  fontSize: 20,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  GestureDetector(
                                    onTap: _navigateToStats,
                                    child: const Text(
                                      'Stats',
                                      style: TextStyle(
                                        color: Color(0xFF7A7A70),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                  GestureDetector(
                                    onTap: _navigateToModeSelection,
                                    child: const Text(
                                      '+',
                                      style: TextStyle(
                                        color: Color(0xFF7A7A70),
                                        fontSize: 22,
                                      ),
                                    ),
                                  ),
                                ],
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
                                'Active sessions',
                                style: TextStyle(
                                  color: Color(0xFF2C2C25),
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                '${_activeTimers.length} active',
                                style: const TextStyle(
                                  color: Color(0xFF7A7A70),
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
                        const SizedBox(height: 80),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.14),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
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
                  color: Colors.white,
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
                        color: Color(0xFF2C2C25),
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
                        color: Color(0xFF7A7A70),
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
                color: Color(0xFF7A7A70),
              ),
            ),
          ],
          if (blockedPackages.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '${blockedPackages.length} app${blockedPackages.length == 1 ? '' : 's'} blocked',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF7A7A70),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class RiverAndLightPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final lightPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFFFFF).withOpacity(0.8),
          const Color(0xFFFFFFFF).withOpacity(0),
        ],
        stops: const [0.0, 1.0],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.3, 0),
          radius: size.width * 0.7,
        ),
      )
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height * 0.4),
      lightPaint,
    );

    final riverPaint = Paint()
      ..color = const Color(0xFFB7DDD4).withOpacity(0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 36
      ..strokeCap = StrokeCap.round;

    final riverPath = Path();
    riverPath.moveTo(size.width * 0.61, -40);
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
      size.height * 1.075,
    );

    canvas.drawPath(riverPath, riverPaint);

    final leafMidPaint = Paint()
      ..color = const Color(0xFF738B4F)
      ..style = PaintingStyle.fill;

    final leafSmallPaint = Paint()
      ..color = const Color(0xFF8DA167)
      ..style = PaintingStyle.fill;

    void drawLeafMid(Paint paint, Offset offset, double rotation) {
      canvas.save();
      canvas.translate(offset.dx, offset.dy);
      canvas.rotate(rotation * 3.14159 / 180);
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
      canvas.rotate(rotation * 3.14159 / 180);
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
      ..color = const Color(0xFF738B4F)
      ..style = PaintingStyle.fill;

    canvas.save();
    canvas.rotate(-12 * 3.14159 / 180);
    drawLeafMid(foregroundPaint, const Offset(30, 520), 0);
    canvas.restore();

    canvas.save();
    canvas.rotate(18 * 3.14159 / 180);
    drawLeafMid(foregroundPaint, const Offset(290, 580), 0);
    canvas.restore();

    canvas.save();
    canvas.rotate(-18 * 3.14159 / 180);
    final bigLeafPaint = Paint()
      ..color = const Color(0xFF5F7743)
      ..style = PaintingStyle.fill;
    final bigLeafPath = Path()
      ..moveTo(-20, 640)
      ..cubicTo(0, 606, 50, 606, 70, 640)
      ..cubicTo(50, 660, 0, 660, -20, 640);
    canvas.drawPath(bigLeafPath, bigLeafPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
