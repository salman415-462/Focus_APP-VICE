import 'package:flutter/material.dart';
import '../services/method_channel_service.dart';
import '../services/selected_apps_store.dart';

class PomodoroConfigScreen extends StatefulWidget {
  const PomodoroConfigScreen({super.key});

  @override
  State<PomodoroConfigScreen> createState() => _PomodoroConfigScreenState();
}

class _PomodoroConfigScreenState extends State<PomodoroConfigScreen> {
  int _focusDurationMinutes = 25;
  int _breakDurationMinutes = 5;
  int _cycles = 4;
  bool _isStarting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: const Text(
          'Pomodoro Setup',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Configure Pomodoro',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Focus sessions with scheduled breaks. Apps are blocked during focus time but allowed during breaks.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 32),

              // Focus duration
              _buildDurationCard(
                title: 'Focus Duration',
                subtitle: 'Time spent focused and blocking apps',
                value: _focusDurationMinutes,
                minValue: 5,
                maxValue: 60,
                onChanged: (value) =>
                    setState(() => _focusDurationMinutes = value),
              ),
              const SizedBox(height: 16),

              // Break duration
              _buildDurationCard(
                title: 'Break Duration',
                subtitle: 'Time to relax with apps unblocked',
                value: _breakDurationMinutes,
                minValue: 1,
                maxValue: 30,
                onChanged: (value) =>
                    setState(() => _breakDurationMinutes = value),
              ),
              const SizedBox(height: 16),

              // Cycles
              _buildDurationCard(
                title: 'Number of Cycles',
                subtitle: 'How many focus-break pairs',
                value: _cycles,
                minValue: 1,
                maxValue: 10,
                onChanged: (value) => setState(() => _cycles = value),
                showMinSuffix: false,
              ),

              const SizedBox(height: 32),

              // Summary
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF16213E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Session Summary',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildSummaryRow('Total Focus Time',
                        '${_focusDurationMinutes * _cycles} min'),
                    _buildSummaryRow('Total Break Time',
                        '${_breakDurationMinutes * _cycles} min'),
                    _buildSummaryRow('Total Duration',
                        '${(_focusDurationMinutes + _breakDurationMinutes) * _cycles} min'),
                    _buildSummaryRow('Cycles', '$_cycles'),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Start button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isStarting ? null : _startPomodoro,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F3460),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isStarting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Start Pomodoro Session',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDurationCard({
    required String title,
    required String subtitle,
    required int value,
    required int minValue,
    required int maxValue,
    required ValueChanged<int> onChanged,
    bool showMinSuffix = true,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              IconButton(
                onPressed: value > minValue ? () => onChanged(value - 1) : null,
                icon: const Icon(Icons.remove, color: Colors.white70),
              ),
              Expanded(
                child: Text(
                  showMinSuffix ? '$value min' : '$value',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              IconButton(
                onPressed: value < maxValue ? () => onChanged(value + 1) : null,
                icon: const Icon(Icons.add, color: Colors.white70),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startPomodoro() async {
    setState(() => _isStarting = true);

    try {
      // Start the first focus session
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
        backgroundColor: const Color(0xFF16213E),
        title: const Text(
          'Error',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          message,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'OK',
              style: TextStyle(color: Color(0xFF0F3460)),
            ),
          ),
        ],
      ),
    );
  }
}
