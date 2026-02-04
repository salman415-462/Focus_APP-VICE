import 'dart:async';
import 'package:flutter/material.dart';
import '../services/method_channel_service.dart';

class PomodoroConfigScreen extends StatefulWidget {
  const PomodoroConfigScreen({super.key});

  @override
  State<PomodoroConfigScreen> createState() => _PomodoroConfigScreenState();
}

class _PomodoroConfigScreenState extends State<PomodoroConfigScreen>
    with SingleTickerProviderStateMixin {
  int _focusDurationMinutes = 25;
  int _breakDurationMinutes = 5;
  int _cycles = 1;
  bool _isStarting = false;

  Timer? _focusTimer;
  Timer? _breakTimer;
  Timer? _cyclesTimer;
  Duration _holdDuration = const Duration(milliseconds: 500);
  Duration _repeatDuration = const Duration(milliseconds: 100);

  int get _totalMinutes =>
      (_focusDurationMinutes + _breakDurationMinutes) * _cycles;
  String get _totalTimeFormatted {
    final hours = _totalMinutes ~/ 60;
    final minutes = _totalMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  String get _focusTimeFormatted {
    final hours = (_focusDurationMinutes * _cycles) ~/ 60;
    final minutes = (_focusDurationMinutes * _cycles) % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  String get _breakTimeFormatted {
    final minutes = _breakDurationMinutes * _cycles;
    return '${minutes}m';
  }

  void _startFocusDecrement() {
    _startAutoDecrement(() {
      if (_focusDurationMinutes > 5) {
        setState(() => _focusDurationMinutes -= 5);
      }
    });
  }

  void _startFocusIncrement() {
    _startAutoIncrement(() {
      if (_focusDurationMinutes < 60) {
        setState(() => _focusDurationMinutes += 5);
      }
    });
  }

  void _startBreakDecrement() {
    _startAutoDecrement(() {
      if (_breakDurationMinutes > 1) {
        setState(() => _breakDurationMinutes -= 1);
      }
    });
  }

  void _startBreakIncrement() {
    _startAutoIncrement(() {
      if (_breakDurationMinutes < 30) {
        setState(() => _breakDurationMinutes += 1);
      }
    });
  }

  void _startCyclesDecrement() {
    _startAutoDecrement(() {
      if (_cycles > 1) {
        setState(() => _cycles -= 1);
      }
    });
  }

  void _startCyclesIncrement() {
    _startAutoIncrement(() {
      if (_cycles < 10) {
        setState(() => _cycles += 1);
      }
    });
  }

  void _startAutoIncrement(VoidCallback action) {
    action();
    Future.delayed(_holdDuration, () {
      _focusTimer = Timer.periodic(_repeatDuration, (timer) {
        action();
      });
    });
  }

  void _startAutoDecrement(VoidCallback action) {
    action();
    Future.delayed(_holdDuration, () {
      _breakTimer = Timer.periodic(_repeatDuration, (timer) {
        action();
      });
    });
  }

  void _stopAllTimers() {
    _focusTimer?.cancel();
    _breakTimer?.cancel();
    _cyclesTimer?.cancel();
    _focusTimer = null;
    _breakTimer = null;
    _cyclesTimer = null;
  }

  @override
  void dispose() {
    _stopAllTimers();
    super.dispose();
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
              Color(0xFFFFF1C6),
              Color(0xFFFFF9E6),
              Color(0xFFF7F6EC),
              Color(0xFFEFEEDC),
              Color(0xFFE6E4D4),
            ],
            stops: [0.0, 0.22, 0.48, 0.72, 1.0],
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: RiverPainter(),
              ),
            ),
            Positioned.fill(
              child: CustomPaint(
                painter: LeavesPainter(),
              ),
            ),
            SafeArea(
              child: SizedBox(
                width: double.infinity,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 44),
                      const Padding(
                        padding: EdgeInsets.only(left: 24),
                        child: Text(
                          'Pomodoro',
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
                          'Set a steady rhythm',
                          style: TextStyle(
                            color: Color(0xFF7A7A70),
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildFocusCard(),
                      const SizedBox(height: 16),
                      _buildBreakCard(),
                      const SizedBox(height: 16),
                      _buildRepeatCard(),
                      const SizedBox(height: 28),
                      _buildSummary(),
                      const SizedBox(height: 32),
                      _buildStartButton(),
                      const SizedBox(height: 24),
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

  Widget _buildFocusCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: 320,
        height: 120,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFFFFF), Color(0xFFF3F2E8)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0x1A000000),
              blurRadius: 20,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.only(left: 36, top: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Focus',
                style: TextStyle(
                  color: Color(0xFF6F7368),
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: 260,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (_focusDurationMinutes > 5) {
                          setState(() => _focusDurationMinutes -= 5);
                        }
                      },
                      onTapDown: (_) => _startFocusDecrement(),
                      onTapUp: (_) => _stopAllTimers(),
                      onTapCancel: _stopAllTimers,
                      child: const Text(
                        '–',
                        style: TextStyle(
                          color: Color(0xFF7A7A70),
                          fontSize: 30,
                        ),
                      ),
                    ),
                    Text(
                      '$_focusDurationMinutes min',
                      style: const TextStyle(
                        color: Color(0xFF2C2C25),
                        fontSize: 38,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        if (_focusDurationMinutes < 60) {
                          setState(() => _focusDurationMinutes += 5);
                        }
                      },
                      onTapDown: (_) => _startFocusIncrement(),
                      onTapUp: (_) => _stopAllTimers(),
                      onTapCancel: _stopAllTimers,
                      child: const Text(
                        '+',
                        style: TextStyle(
                          color: Color(0xFF7A7A70),
                          fontSize: 30,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBreakCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        width: 312,
        height: 96,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFFFFF), Color(0xFFF3F2E8)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0x1A000000),
              blurRadius: 20,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.only(left: 36, top: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Break',
                style: TextStyle(
                  color: Color(0xFF6F7368),
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: 252,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (_breakDurationMinutes > 1) {
                          setState(() => _breakDurationMinutes -= 1);
                        }
                      },
                      onTapDown: (_) => _startBreakDecrement(),
                      onTapUp: (_) => _stopAllTimers(),
                      onTapCancel: _stopAllTimers,
                      child: const Text(
                        '–',
                        style: TextStyle(
                          color: Color(0xFF7A7A70),
                          fontSize: 24,
                        ),
                      ),
                    ),
                    Text(
                      '$_breakDurationMinutes min',
                      style: const TextStyle(
                        color: Color(0xFF2C2C25),
                        fontSize: 30,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        if (_breakDurationMinutes < 30) {
                          setState(() => _breakDurationMinutes += 1);
                        }
                      },
                      onTapDown: (_) => _startBreakIncrement(),
                      onTapUp: (_) => _stopAllTimers(),
                      onTapCancel: _stopAllTimers,
                      child: const Text(
                        '+',
                        style: TextStyle(
                          color: Color(0xFF7A7A70),
                          fontSize: 24,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRepeatCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        width: 312,
        height: 88,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFFFFF), Color(0xFFF3F2E8)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0x1A000000),
              blurRadius: 20,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.only(left: 36, top: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Repeat',
                style: TextStyle(
                  color: Color(0xFF6F7368),
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: 252,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (_cycles > 1) {
                          setState(() => _cycles -= 1);
                        }
                      },
                      onTapDown: (_) => _startCyclesDecrement(),
                      onTapUp: (_) => _stopAllTimers(),
                      onTapCancel: _stopAllTimers,
                      child: const Text(
                        '–',
                        style: TextStyle(
                          color: Color(0xFF7A7A70),
                          fontSize: 22,
                        ),
                      ),
                    ),
                    Text(
                      '$_cycles cycles',
                      style: const TextStyle(
                        color: Color(0xFF2C2C25),
                        fontSize: 26,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        if (_cycles < 10) {
                          setState(() => _cycles += 1);
                        }
                      },
                      onTapDown: (_) => _startCyclesIncrement(),
                      onTapUp: (_) => _stopAllTimers(),
                      onTapCancel: _stopAllTimers,
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
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummary() {
    return Padding(
      padding: const EdgeInsets.only(left: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This session becomes',
            style: TextStyle(
              color: Color(0xFF7A7A70),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _totalTimeFormatted,
            style: const TextStyle(
              color: Color(0xFF2C2C25),
              fontSize: 30,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '• $_focusTimeFormatted focused',
            style: const TextStyle(
              color: Color(0xFF7A7A70),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '• $_breakTimeFormatted rest',
            style: const TextStyle(
              color: Color(0xFF7A7A70),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStartButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: GestureDetector(
        onTap: _isStarting ? null : _startPomodoro,
        child: Container(
          width: 312,
          height: 58,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(29),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF6E8F5E), Color(0xFF4E6E3A)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0x1A000000),
                blurRadius: 20,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Center(
            child: _isStarting
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text(
                    'Start session',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _startPomodoro() async {
    setState(() => _isStarting = true);

    try {
      final success = await MethodChannelService.startPomodoroFocusTimer(
        durationMinutes: _focusDurationMinutes,
      );

      if (!mounted) return;

      if (success) {
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        _showErrorDialog('Failed to start Pomodoro session');
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog('Error starting session: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isStarting = false);
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
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
}

class RiverPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFDFF1EA), Color(0xFFCBE4DA)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 38
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

class LeavesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    _drawBigLeaf(canvas, 255, 64, 18);
    _drawBigLeaf(canvas, -40, 640, -18);
    _drawSmallLeaf(canvas, 52, 164, 0);
    _drawSmallLeaf(canvas, 298, 272, 0);
    _drawSmallLeaf(canvas, 188, 520, 0);
  }

  void _drawBigLeaf(Canvas canvas, double x, double y, double rotation) {
    canvas.save();
    canvas.translate(x + 45, y);
    canvas.rotate(rotation * 3.14159 / 180);
    final paint = Paint()
      ..color = const Color(0x3D5F7743)
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
