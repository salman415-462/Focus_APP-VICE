import 'package:flutter/material.dart';
import '../services/method_channel_service.dart';
import '../services/selected_apps_store.dart';

final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

class VerticalTimeDial extends StatefulWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;

  const VerticalTimeDial({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    required this.min,
    required this.max,
  });

  @override
  State<VerticalTimeDial> createState() => _VerticalTimeDialState();
}

class _VerticalTimeDialState extends State<VerticalTimeDial> {
  double _accumulatedDelta = 0.0;
  static const double _stepSize = 18.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF7A7A70),
          ),
        ),
        const SizedBox(height: 4),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragUpdate: (details) {
            _accumulatedDelta += details.delta.dy;
            int newValue = widget.value;
            if (_accumulatedDelta >= _stepSize) {
              newValue = (widget.value + 1).clamp(widget.min, widget.max);
              _accumulatedDelta = 0.0;
            } else if (_accumulatedDelta <= -_stepSize) {
              newValue = (widget.value - 1).clamp(widget.min, widget.max);
              _accumulatedDelta = 0.0;
            }
            if (newValue != widget.value) {
              widget.onChanged(newValue);
            }
          },
          child: Container(
            height: 78,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.14),
                  offset: const Offset(0, 10),
                  blurRadius: 18,
                ),
              ],
            ),
            child: ClipRect(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.keyboard_arrow_up,
                      color: const Color(0xFF9A9A8E), size: 14),
                  Text(
                    widget.value.toString().padLeft(2, '0'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF2C2C25),
                    ),
                  ),
                  Icon(Icons.keyboard_arrow_down,
                      color: const Color(0xFF9A9A8E), size: 14),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

enum ScheduleType {
  oneTime,
  daily,
  weekdays,
  customDuration,
}

class ScheduleConfigScreen extends StatefulWidget {
  const ScheduleConfigScreen({super.key});

  @override
  State<ScheduleConfigScreen> createState() => _ScheduleConfigScreenState();
}

class _ScheduleConfigScreenState extends State<ScheduleConfigScreen>
    with RouteAware {
  ScheduleType _scheduleType = ScheduleType.daily;
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 17, minute: 0);
  bool _isSaving = false;
  String? _errorMessage;

  bool _isNavigating = false;

  int _durationMinutes = 480;

  int _customDurationHours = 0;
  int _customDurationMinutes = 30;

  int _activeSessionCount = 0;

  @override
  void initState() {
    super.initState();
    _checkSessionStatus();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void didPopNext() {
    _checkSessionStatus();
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  Future<void> _checkSessionStatus() async {
    try {
      final timers = await MethodChannelService.getActiveTimers();
      if (!mounted) return;

      setState(() {
        _activeSessionCount = timers.length;
      });
    } catch (e) {}
  }

  Future<void> _selectStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: const Color(0xFFFFFDF2),
              dialBackgroundColor: const Color(0xFFF3F2E8),
              hourMinuteColor: const Color(0xFF16213E),
              hourMinuteTextColor: Colors.white,
              dayPeriodColor: const Color(0xFF6E8F5E),
              dayPeriodTextColor: Colors.white,
              entryModeIconColor: const Color(0xFF4E6E3A),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() {
        _startTime = picked;
        _calculateDuration();
      });
    }
  }

  Future<void> _selectEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: const Color(0xFFFFFDF2),
              dialBackgroundColor: const Color(0xFFF3F2E8),
              hourMinuteColor: const Color(0xFF16213E),
              hourMinuteTextColor: Colors.white,
              dayPeriodColor: const Color(0xFF6E8F5E),
              dayPeriodTextColor: Colors.white,
              entryModeIconColor: const Color(0xFF4E6E3A),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() {
        _endTime = picked;
        _calculateDuration();
      });
    }
  }

  void _calculateDuration() {
    final startMinutes = _startTime.hour * 60 + _startTime.minute;
    final endMinutes = _endTime.hour * 60 + _endTime.minute;
    if (endMinutes > startMinutes) {
      _durationMinutes = endMinutes - startMinutes;
    }
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatDurationHours(int minutes) {
    final hours = minutes ~/ 60;
    return '$hours hours';
  }

  String _formatCustomEndTime() {
    final now = DateTime.now();
    final endTime = now.add(
        Duration(hours: _customDurationHours, minutes: _customDurationMinutes));
    final hour = endTime.hour.toString().padLeft(2, '0');
    final minute = endTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  List<String> _getBlockedPackages() {
    return SelectedAppsStore().blockedPackages;
  }

  Future<void> _saveSchedule() async {
    if (_isNavigating) return;

    if (_durationMinutes <= 0) {
      setState(() {
        _errorMessage = 'Invalid time range selected.';
      });
      return;
    }

    final blockedPackages = _getBlockedPackages();
    if (blockedPackages.isEmpty) {
      setState(() {
        _errorMessage = 'Please select at least one app to block';
        _isSaving = false;
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      bool timerStarted;
      if (_scheduleType == ScheduleType.customDuration) {
        final totalMinutes =
            (_customDurationHours * 60) + _customDurationMinutes;
        if (totalMinutes <= 0) {
          setState(() {
            _errorMessage = 'Invalid duration selected.';
            _isSaving = false;
          });
          return;
        }
        timerStarted = await MethodChannelService.startCustomDurationTimer(
          durationMinutes: totalMinutes,
          blockedPackages: blockedPackages,
        );
      } else {
        timerStarted = await MethodChannelService.startOneTimeTimer(
          durationMinutes: _durationMinutes,
          blockedPackages: blockedPackages,
        );
      }

      if (!mounted || _isNavigating) return;

      if (!timerStarted) {
        setState(() {
          _errorMessage = 'Failed to start timer. Please try again.';
          _isSaving = false;
        });
        return;
      }

      final activeTimers = await MethodChannelService.getActiveTimers();
      if (!mounted || _isNavigating) return;

      if (activeTimers.isEmpty) {
        setState(() {
          _errorMessage = 'Timer creation failed. Please try again.';
          _isSaving = false;
        });
        return;
      }

      setState(() {
        _isSaving = true;
        _isNavigating = true;
      });

      Navigator.popUntil(context, (route) => route.isFirst);
      setState(() {
        _isSaving = false;
        _isNavigating = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error starting timer: ${e.toString()}';
        _isSaving = false;
      });
    }
  }

  Widget _buildScheduleTypeCard({
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 312,
        height: 64,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.14),
              offset: const Offset(0, 10),
              blurRadius: 18,
            ),
          ],
        ),
        child: Row(
          children: [
            if (isSelected)
              Container(
                width: 6,
                height: 64,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF6E8F5E), Color(0xFF4E6E3A)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.horizontal(
                    left: Radius.circular(3),
                  ),
                ),
              ),
            Expanded(
              child: Container(
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: isSelected
                      ? const BorderRadius.horizontal(
                          right: Radius.circular(22),
                        )
                      : BorderRadius.circular(22),
                ),
                padding: const EdgeInsets.only(left: 28, right: 16),
                child: Row(
                  children: [
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF6E8F5E)
                            : Colors.transparent,
                        shape: BoxShape.circle,
                        border: !isSelected
                            ? Border.all(
                                color: const Color(0xFF9A9A8E), width: 2)
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
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF2C2C25),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF7A7A70),
                            ),
                          ),
                        ],
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

  Widget _buildCustomDurationInput() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.14),
            offset: const Offset(0, 10),
            blurRadius: 18,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Custom Duration',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF7A7A70),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox(
                width: 120,
                child: VerticalTimeDial(
                  label: 'Hours',
                  value: _customDurationHours,
                  onChanged: (value) {
                    setState(() {
                      _customDurationHours = value;
                    });
                  },
                  min: 0,
                  max: 23,
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 120,
                child: VerticalTimeDial(
                  label: 'Minutes',
                  value: _customDurationMinutes,
                  onChanged: (value) {
                    setState(() {
                      _customDurationMinutes = value;
                    });
                  },
                  min: 0,
                  max: 59,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Start Time:',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF7A7A70),
                ),
              ),
              Text(
                'Now',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF2C2C25),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'End Time:',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF7A7A70),
                ),
              ),
              Text(
                _formatCustomEndTime(),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF2C2C25),
                ),
              ),
            ],
          ),
        ],
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
            colors: [Color(0xFFFFFDF2), Color(0xFFE9E7D8)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _ScheduleLeafPainter(),
              ),
            ),
            SafeArea(
              child: Stack(
                children: [
                  SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 120),
                    child: Padding(
                      padding:
                          const EdgeInsets.only(left: 24, right: 24, top: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeader(),
                          const SizedBox(height: 24),
                          _buildSubtitle(),
                          const SizedBox(height: 36),
                          _buildRhythmLabel(),
                          const SizedBox(height: 16),
                          _buildScheduleTypeCard(
                            title: 'One-time',
                            subtitle: 'Single session',
                            isSelected: _scheduleType == ScheduleType.oneTime,
                            onTap: () {
                              if (mounted) {
                                setState(() {
                                  _scheduleType = ScheduleType.oneTime;
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 8),
                          _buildScheduleTypeCard(
                            title: 'Daily',
                            subtitle: 'Repeats every day',
                            isSelected: _scheduleType == ScheduleType.daily,
                            onTap: () {
                              if (mounted) {
                                setState(() {
                                  _scheduleType = ScheduleType.daily;
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 8),
                          _buildScheduleTypeCard(
                            title: 'Weekdays',
                            subtitle: 'Mon–Fri',
                            isSelected: _scheduleType == ScheduleType.weekdays,
                            onTap: () {
                              if (mounted) {
                                setState(() {
                                  _scheduleType = ScheduleType.weekdays;
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 8),
                          _buildScheduleTypeCard(
                            title: 'Custom duration',
                            subtitle: 'Set your own time',
                            isSelected:
                                _scheduleType == ScheduleType.customDuration,
                            onTap: () {
                              if (mounted) {
                                setState(() {
                                  _scheduleType = ScheduleType.customDuration;
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 28),
                          _buildBoundaryLabel(),
                          const SizedBox(height: 16),
                          _buildTimeBoundary(),
                          if (_scheduleType != ScheduleType.customDuration) ...[
                            const SizedBox(height: 40),
                            _buildDurationSection(),
                          ],
                          if (_scheduleType == ScheduleType.customDuration) ...[
                            const SizedBox(height: 24),
                            _buildCustomDurationInput(),
                          ],
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 20),
                            _buildErrorBanner(),
                          ],
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 24,
                    left: 24,
                    right: 24,
                    child: _buildCTAButton(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        GestureDetector(
          onTap: _isNavigating
              ? null
              : () {
                  if (mounted && !_isNavigating) {
                    Navigator.pop(context);
                  }
                },
          child: const Text(
            '‹',
            style: TextStyle(
              color: Color(0xFF2C2C25),
              fontSize: 28,
            ),
          ),
        ),
        const SizedBox(width: 32),
        const Text(
          'Schedule',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: Color(0xFF2C2C25),
          ),
        ),
      ],
    );
  }

  Widget _buildSubtitle() {
    return const Text(
      'Decide the shape of this quiet time',
      style: TextStyle(
        fontSize: 14,
        color: Color(0xFF7A7A70),
      ),
    );
  }

  Widget _buildRhythmLabel() {
    return const Text(
      'Focus rhythm',
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: Color(0xFF2C2C25),
      ),
    );
  }

  Widget _buildBoundaryLabel() {
    return const Text(
      'Time boundary',
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: Color(0xFF2C2C25),
      ),
    );
  }

  Widget _buildTimeBoundary() {
    return Container(
      width: 312,
      height: 88,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.14),
            offset: const Offset(0, 10),
            blurRadius: 18,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Start',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF7A7A70),
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _selectStartTime,
                  child: Text(
                    _formatTimeOfDay(_startTime),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF2C2C25),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 60,
            color: const Color(0xFFE0DED6),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'End',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF7A7A70),
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _selectEndTime,
                  child: Text(
                    _formatTimeOfDay(_endTime),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF2C2C25),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDurationSection() {
    return Column(
      children: [
        const Text(
          'Duration',
          style: TextStyle(
            fontSize: 13,
            color: Color(0xFF7A7A70),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _formatDurationHours(_durationMinutes),
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w500,
            color: Color(0xFF2C2C25),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Focus will be held until this ends',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: Color(0xFF9A9A8E),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      width: double.infinity,
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFF2A1B1B),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(
        child: Text(
          _errorMessage!,
          style: const TextStyle(
            color: Color(0xFFE6B4B4),
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildCTAButton() {
    return GestureDetector(
      onTap: _isSaving || _isNavigating ? null : _saveSchedule,
      child: Container(
        width: 216,
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6E8F5E), Color(0xFF4E6E3A)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.14),
              offset: const Offset(0, 10),
              blurRadius: 18,
            ),
          ],
        ),
        child: Center(
          child: _isSaving
              ? const CircularProgressIndicator(
                  color: Colors.white,
                )
              : const Text(
                  'Begin focus',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }
}

class _ScheduleLeafPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final lightPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFFFFF).withOpacity(0.85),
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
      Rect.fromLTWH(0, 0, size.width, 260),
      lightPaint,
    );

    final leafPaint = Paint()
      ..color = const Color(0xFF8DA167)
      ..style = PaintingStyle.fill
      ..filterQuality = FilterQuality.high;

    final smallLeafPath = Path()
      ..moveTo(0, 0)
      ..cubicTo(6, -10, 20, -10, 28, 0)
      ..cubicTo(20, 6, 6, 6, 0, 0)
      ..close();

    canvas.save();
    canvas.translate(60, 160);
    canvas.scale(1.0);
    canvas.drawPath(
        smallLeafPath, leafPaint..color = leafPaint.color.withOpacity(0.16));
    canvas.restore();

    canvas.save();
    canvas.translate(280, 220);
    canvas.scale(1.0);
    canvas.drawPath(
        smallLeafPath, leafPaint..color = leafPaint.color.withOpacity(0.16));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
