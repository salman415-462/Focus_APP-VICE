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
      // Only count focus modes, not breaks
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
      // Only count focus modes, not breaks
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
                painter: StatsScreenBackgroundPainter(),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  _buildHeader(),
                  const SizedBox(height: 32),
                  if (_isLoading)
                    const Expanded(
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF4FA3A5),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionTitle('Right Now'),
                            const SizedBox(height: 12),
                            _buildRightNowCard(),
                            const SizedBox(height: 32),
                            _buildSectionTitle('Today'),
                            const SizedBox(height: 12),
                            _buildTodayCard(),
                            const SizedBox(height: 32),
                            _buildSectionTitle('System Status'),
                            const SizedBox(height: 12),
                            _buildSystemStatusCard(),
                          ],
                        ),
                      ),
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
    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 24, top: 12),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Text(
              '‹',
              style: TextStyle(
                color: Color(0xFF9FBFC1),
                fontSize: 28,
              ),
            ),
          ),
          const Text(
            'Stats',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: Color(0xFFF4F3EF),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Color(0xFF9FBFC1),
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildRightNowCard() {
    final activeModes = _getActiveModes();
    final activeModesText =
        activeModes.isEmpty ? 'None' : activeModes.join(' / ');

    return _buildInfoCard(
      children: [
        _buildInfoRow(
          label: 'Active sessions',
          value: _activeTimers.isEmpty ? 'None' : '${_activeTimers.length}',
        ),
        const SizedBox(height: 16),
        _buildInfoRow(
          label: 'Active modes',
          value: activeModesText,
        ),
      ],
    );
  }

  Widget _buildTodayCard() {
    final totalFocusMinutes = _calculateTotalFocusMinutes();
    final remainingFocusMinutes = _calculateRemainingFocusMinutes();
    final sessionsStarted = _activeTimers.length;

    return _buildInfoCard(
      children: [
        _buildInfoRow(
          label: 'Focus time (total)',
          value: _formatMinutes(totalFocusMinutes),
        ),
        const SizedBox(height: 16),
        _buildInfoRow(
          label: 'Focus time (remaining)',
          value: _formatMinutes(remainingFocusMinutes),
        ),
        const SizedBox(height: 16),
        _buildInfoRow(
          label: 'Sessions started',
          value: '$sessionsStarted',
        ),
      ],
    );
  }

  Widget _buildSystemStatusCard() {
    final isBlocking = _blockStatus['isBlockActive'] as bool? ?? false;
    final bypassActive = _blockStatus['bypassActive'] as bool? ?? false;

    return _buildInfoCard(
      children: [
        _buildInfoRow(
          label: 'Blocking active',
          value: isBlocking ? 'Yes' : 'No',
          valueColor: isBlocking ? const Color(0xFF4FA3A5) : null,
        ),
        const SizedBox(height: 16),
        _buildInfoRow(
          label: 'Emergency bypass',
          value: bypassActive ? 'Yes' : 'No',
          valueColor: bypassActive ? const Color(0xFFE53935) : null,
        ),
      ],
    );
  }

  Widget _buildInfoCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1B2230), Color(0xFF151B28)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF2E3A4A),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildInfoRow({
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF9FBFC1),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: valueColor ?? const Color(0xFFF4F3EF),
          ),
        ),
      ],
    );
  }
}

class StatsScreenBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.35);
    final radius = size.width * 0.6;

    final gradient = RadialGradient(
      colors: [
        const Color(0xFF1C2430).withOpacity(0.5),
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
