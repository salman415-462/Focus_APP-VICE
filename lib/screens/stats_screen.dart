import 'package:flutter/material.dart';
import '../services/method_channel_service.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  List<Map<String, dynamic>> _activeTimers = [];
  Map<String, dynamic> _blockStatus = {
    'isBlockActive': false,
    'bypassActive': false,
  };
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final timers = await MethodChannelService.getActiveTimers();
      final blockStatus = await MethodChannelService.getBlockStatus();

      if (!mounted) return;

      setState(() {
        _activeTimers = timers;
        _blockStatus = blockStatus;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatMinutes(int minutes) {
    if (minutes < 60) {
      return '${minutes}m';
    }
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (mins == 0) {
      return '${hours}h';
    }
    return '${hours}h ${mins}m';
  }

  int _calculateTotalFocusMinutes() {
    int totalMinutes = 0;
    for (final timer in _activeTimers) {
      final mode = timer['mode'] as String? ?? 'FOCUS';
      final durationMinutes = timer['durationMinutes'] as int? ?? 0;
      if (mode == 'FOCUS' || mode == 'POMODORO_FOCUS') {
        totalMinutes += durationMinutes;
      }
    }
    return totalMinutes;
  }

  int _calculateRemainingFocusMinutes() {
    int totalMinutes = 0;
    for (final timer in _activeTimers) {
      final mode = timer['mode'] as String? ?? 'FOCUS';
      final remainingSeconds = timer['remainingSeconds'] as int? ?? 0;
      if (mode == 'FOCUS' || mode == 'POMODORO_FOCUS') {
        totalMinutes += (remainingSeconds / 60).round();
      }
    }
    return totalMinutes;
  }

  List<String> _getActiveModes() {
    final modes = <String>[];
    for (final timer in _activeTimers) {
      final mode = timer['mode'] as String? ?? 'FOCUS';
      if (mode == 'FOCUS' && !modes.contains('Focus')) {
        modes.add('Focus');
      } else if (mode == 'POMODORO_FOCUS' && !modes.contains('Pomodoro')) {
        modes.add('Pomodoro');
      } else if (mode == 'POMODORO_BREAK' && !modes.contains('Break')) {
        modes.add('Break');
      }
    }
    return modes;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFF2C8),
              Color(0xFFFFFDF2),
              Color(0xFFF3F2E8),
              Color(0xFFE9E7D8),
            ],
            stops: [0.0, 0.30, 0.65, 1.0],
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: FlowPainter(),
              ),
            ),
            Positioned.fill(
              child: CustomPaint(
                painter: StatsLeavesPainter(),
              ),
            ),
            SafeArea(
              child: SizedBox(
                width: double.infinity,
                child: _isLoading
                    ? Center(
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
                      )
                    : SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 44),
                            const Padding(
                              padding: EdgeInsets.only(left: 24),
                              child: Text(
                                'Stats',
                                style: TextStyle(
                                  color: Color(0xFF2C2C25),
                                  fontSize: 20,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(height: 22),
                            const Padding(
                              padding: EdgeInsets.only(left: 24),
                              child: Text(
                                'A quiet snapshot',
                                style: TextStyle(
                                  color: Color(0xFF8B8B80),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(height: 38),
                            _buildSectionTitle('Right Now'),
                            const SizedBox(height: 16),
                            _buildRightNowCard(),
                            const SizedBox(height: 32),
                            _buildTodayTitle(),
                            const SizedBox(height: 16),
                            _buildTodayCard(),
                            const SizedBox(height: 32),
                            _buildSystemStateTitle(),
                            const SizedBox(height: 16),
                            _buildSystemStateCard(),
                          ],
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 24),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF7A7A70),
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildTodayTitle() {
    return const Padding(
      padding: EdgeInsets.only(left: 24),
      child: Text(
        'Today',
        style: TextStyle(
          color: Color(0xFF7A7A70),
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildSystemStateTitle() {
    return const Padding(
      padding: EdgeInsets.only(left: 24),
      child: Text(
        'System state',
        style: TextStyle(
          color: Color(0xFF7A7A70),
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildRightNowCard() {
    final activeModes = _getActiveModes();
    final activeModesText =
        activeModes.isEmpty ? 'None' : activeModes.join(' / ');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        width: 312,
        height: 92,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFFFFF), Color(0xFFF6F5EC)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0x1A000000),
              blurRadius: 18,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.only(left: 24, top: 38),
          child: Column(
            children: [
              Row(
                children: [
                  const Text(
                    'Active sessions',
                    style: TextStyle(
                      color: Color(0xFF7A7A70),
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _activeTimers.isEmpty ? 'None' : '${_activeTimers.length}',
                    style: const TextStyle(
                      color: Color(0xFF2C2C25),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 24),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  const Text(
                    'Active mode',
                    style: TextStyle(
                      color: Color(0xFF7A7A70),
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    activeModesText,
                    style: const TextStyle(
                      color: Color(0xFF2C2C25),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 24),
                ],
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTodayCard() {
    final totalFocusMinutes = _calculateTotalFocusMinutes();
    final remainingFocusMinutes = _calculateRemainingFocusMinutes();
    final sessionsStarted = _activeTimers.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        width: 312,
        height: 132,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFFFFF), Color(0xFFF6F5EC)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0x1A000000),
              blurRadius: 18,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.only(left: 24, top: 40),
          child: Column(
            children: [
              Row(
                children: [
                  const Text(
                    'Focus time',
                    style: TextStyle(
                      color: Color(0xFF7A7A70),
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatMinutes(totalFocusMinutes),
                    style: const TextStyle(
                      color: Color(0xFF2C2C25),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 24),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  const Text(
                    'Remaining',
                    style: TextStyle(
                      color: Color(0xFF7A7A70),
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatMinutes(remainingFocusMinutes),
                    style: const TextStyle(
                      color: Color(0xFF2C2C25),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 24),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  const Text(
                    'Sessions started',
                    style: TextStyle(
                      color: Color(0xFF7A7A70),
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$sessionsStarted',
                    style: const TextStyle(
                      color: Color(0xFF2C2C25),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 24),
                ],
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSystemStateCard() {
    final isBlocking = _blockStatus['isBlockActive'] as bool? ?? false;
    final bypassActive = _blockStatus['bypassActive'] as bool? ?? false;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        width: 312,
        height: 96,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFFFFF), Color(0xFFF6F5EC)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0x1A000000),
              blurRadius: 18,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.only(left: 24, top: 36),
          child: Column(
            children: [
              Row(
                children: [
                  const Text(
                    'Blocking active',
                    style: TextStyle(
                      color: Color(0xFF7A7A70),
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    isBlocking ? 'Yes' : 'No',
                    style: const TextStyle(
                      color: Color(0xFF2C2C25),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 24),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  const Text(
                    'Emergency bypass',
                    style: TextStyle(
                      color: Color(0xFF7A7A70),
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    bypassActive ? 'Yes' : 'No',
                    style: const TextStyle(
                      color: Color(0xFF2C2C25),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 24),
                ],
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class FlowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFE3F1EA), Color(0xFFCFE6DC)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 42
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(210, -80)
      ..cubicTo(250, 120, 170, 260, 210, 420)
      ..cubicTo(250, 600, 170, 760, 210, 900);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class StatsLeavesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    _drawBigLeaf(canvas, 260, 64, 18);
    _drawBigLeaf(canvas, -30, 640, -18);
    _drawSmallLeaf(canvas, 44, 152, 0);
    _drawSmallLeaf(canvas, 300, 272, 0);
    _drawSmallLeaf(canvas, 180, 520, 0);
  }

  void _drawBigLeaf(Canvas canvas, double x, double y, double rotation) {
    canvas.save();
    canvas.translate(x + 45, y);
    canvas.rotate(rotation * 3.14159 / 180);
    final paint = Paint()
      ..color = const Color(0x385F7743)
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(0, 0)
      ..cubicTo(20, -34, 70, -34, 90, 0)
      ..cubicTo(70, 20, 20, 20, 0, 0)
      ..close();
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  void _drawSmallLeaf(Canvas canvas, double x, double y, double rotation) {
    canvas.save();
    canvas.translate(x + 14, y);
    canvas.rotate(rotation * 3.14159 / 180);
    final paint = Paint()
      ..color = const Color(0x388DA167)
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(0, 0)
      ..cubicTo(6, -10, 20, -10, 28, 0)
      ..cubicTo(20, 6, 6, 6, 0, 0)
      ..close();
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
