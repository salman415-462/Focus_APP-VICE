import 'package:flutter/material.dart';
import '../services/method_channel_service.dart';
import '../services/selected_apps_store.dart';

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
            color: Color(0xFF9FBFC1),
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
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1B2230), Color(0xFF151B28)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: ClipRect(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.keyboard_arrow_up,
                      color: const Color(0xFF9FBFC1), size: 14),
                  Text(
                    widget.value.toString().padLeft(2, '0'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFFF4F3EF),
                    ),
                  ),
                  Icon(Icons.keyboard_arrow_down,
                      color: const Color(0xFF9FBFC1), size: 14),
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

class _ScheduleConfigScreenState extends State<ScheduleConfigScreen> {
  ScheduleType _scheduleType = ScheduleType.oneTime;
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
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF4FA3A5),
              surface: Color(0xFF1B2230),
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
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF4FA3A5),
              surface: Color(0xFF1B2230),
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

  String _formatDuration(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours > 0) {
      return '${hours}h ${mins}m';
    }
    return '${mins}m';
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

      _isNavigating = true;
      Navigator.pushNamed(context, '/active-block');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error starting timer: ${e.toString()}';
        _isSaving = false;
      });
    }
  }

  Widget _buildScheduleTypeCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1B2230), Color(0xFF151B28)],
          ),
          borderRadius: BorderRadius.circular(18),
          border: isSelected
              ? Border.all(
                  color: const Color(0xFF4FA3A5).withOpacity(0.6), width: 2)
              : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color:
                    isSelected ? const Color(0xFF4FA3A5) : Colors.transparent,
                shape: BoxShape.circle,
                border: !isSelected
                    ? Border.all(color: const Color(0xFF9FBFC1), width: 2)
                    : null,
              ),
              child: Icon(
                icon,
                color: isSelected
                    ? const Color(0xFF151B28)
                    : const Color(0xFF9FBFC1),
                size: 20,
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
                      color: Color(0xFFF4F3EF),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF9FBFC1),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: isSelected
                  ? const Color(0xFF4FA3A5)
                  : const Color(0xFF9FBFC1),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeButton({
    required String label,
    required String time,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1B2230), Color(0xFF151B28)],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        height: 60,
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF9FBFC1),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              time,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Color(0xFFF4F3EF),
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
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1B2230), Color(0xFF151B28)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Custom Duration',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF9FBFC1),
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
                  color: Color(0xFF9FBFC1),
                ),
              ),
              Text(
                'Now',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFFF4F3EF),
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
                  color: Color(0xFF9FBFC1),
                ),
              ),
              Text(
                _formatCustomEndTime(),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFFF4F3EF),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatCustomEndTime() {
    final now = DateTime.now();
    final endTime = now.add(
        Duration(hours: _customDurationHours, minutes: _customDurationMinutes));
    final hour = endTime.hour.toString().padLeft(2, '0');
    final minute = endTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C0F16),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C0F16),
        elevation: 0,
        title: const Text(
          'Schedule',
          style: TextStyle(
            color: Color(0xFFF4F3EF),
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF9FBFC1)),
          onPressed: _isNavigating
              ? null
              : () {
                  if (mounted && !_isNavigating) {
                    Navigator.pop(context);
                  }
                },
        ),
        actions: [
          if (_activeSessionCount > 0)
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
                    '$_activeSessionCount active',
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
      body: SafeArea(
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
            SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 24),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Block schedule',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFFF4F3EF),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Choose when focus protection applies',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF9FBFC1),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildScheduleTypeCard(
                      icon: Icons.timer,
                      title: 'One-time block',
                      subtitle: 'Block for a specific period',
                      isSelected: _scheduleType == ScheduleType.oneTime,
                      onTap: () {
                        if (mounted) {
                          setState(() {
                            _scheduleType = ScheduleType.oneTime;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildScheduleTypeCard(
                      icon: Icons.repeat,
                      title: 'Daily schedule',
                      subtitle: 'Same time every day',
                      isSelected: _scheduleType == ScheduleType.daily,
                      onTap: () {
                        if (mounted) {
                          setState(() {
                            _scheduleType = ScheduleType.daily;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildScheduleTypeCard(
                      icon: Icons.calendar_view_week,
                      title: 'Weekdays only',
                      subtitle: 'Monday to Friday',
                      isSelected: _scheduleType == ScheduleType.weekdays,
                      onTap: () {
                        if (mounted) {
                          setState(() {
                            _scheduleType = ScheduleType.weekdays;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildScheduleTypeCard(
                      icon: Icons.access_time,
                      title: 'Custom duration',
                      subtitle: 'Block for a specific duration starting now',
                      isSelected: _scheduleType == ScheduleType.customDuration,
                      onTap: () {
                        if (mounted) {
                          setState(() {
                            _scheduleType = ScheduleType.customDuration;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Time range',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFFF4F3EF),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTimeButton(
                            label: 'Start',
                            time: _formatTimeOfDay(_startTime),
                            onTap: _selectStartTime,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTimeButton(
                            label: 'End',
                            time: _formatTimeOfDay(_endTime),
                            onTap: _selectEndTime,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    if (_scheduleType != ScheduleType.customDuration)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Column(
                          children: [
                            const Text(
                              'Duration',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF9FBFC1),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatDuration(_durationMinutes),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFFF4F3EF),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (_scheduleType == ScheduleType.customDuration)
                      _buildCustomDurationInput(),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A1B1B),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.all(14),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: Color(0xFFE6B4B4),
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xFF0C0F16)],
                  ),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed:
                        _isSaving || _isNavigating ? null : _saveSchedule,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4FA3A5),
                      foregroundColor: const Color(0xFF0C0F16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: _isSaving
                        ? const CircularProgressIndicator(
                            color: Color(0xFF0C0F16),
                          )
                        : const Text(
                            'Start Focus Session',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
