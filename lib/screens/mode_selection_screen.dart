import 'package:flutter/material.dart';

enum AppMode {
  focus,
  pomodoro,
  websiteBlocking,
}

class FocusModeIcon extends StatelessWidget {
  final bool isEnabled;

  const FocusModeIcon({super.key, this.isEnabled = true});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(36, 36),
      painter: FocusIconPainter(isEnabled: isEnabled),
    );
  }
}

class FocusIconPainter extends CustomPainter {
  final bool isEnabled;

  const FocusIconPainter({this.isEnabled = true});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = 18.0;

    final gradient = RadialGradient(
      colors: isEnabled
          ? [const Color(0xFF4FA3A5), const Color(0xFF2F6F73)]
          : [const Color(0xFF1E2433), const Color(0xFF1E2433)],
    );

    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius,
      Paint()..shader = gradient.createShader(rect),
    );

    final linePaint = Paint()
      ..color = isEnabled ? const Color(0xFF0C0F16) : const Color(0xFF6B7C93)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(center.dx - 8, center.dy),
      Offset(center.dx + 8, center.dy),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(covariant FocusIconPainter oldDelegate) {
    return oldDelegate.isEnabled != isEnabled;
  }
}

class PomodoroModeIcon extends StatelessWidget {
  final bool isEnabled;

  const PomodoroModeIcon({super.key, this.isEnabled = true});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(36, 36),
      painter: PomodoroIconPainter(isEnabled: isEnabled),
    );
  }
}

class PomodoroIconPainter extends CustomPainter {
  final bool isEnabled;

  const PomodoroIconPainter({this.isEnabled = true});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = 18.0;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = isEnabled ? const Color(0xFF2E3A4A) : const Color(0xFF1E2433),
    );

    canvas.drawCircle(
      center,
      10,
      Paint()
        ..color = isEnabled ? const Color(0xFF9FBFC1) : const Color(0xFF6B7C93)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant PomodoroIconPainter oldDelegate) {
    return oldDelegate.isEnabled != isEnabled;
  }
}

class WebsiteModeIcon extends StatelessWidget {
  final bool isEnabled;

  const WebsiteModeIcon({super.key, this.isEnabled = true});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(36, 36),
      painter: WebsiteIconPainter(isEnabled: isEnabled),
    );
  }
}

class WebsiteIconPainter extends CustomPainter {
  final bool isEnabled;

  const WebsiteIconPainter({this.isEnabled = true});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCenter(center: center, width: 16, height: 12);

    final borderPaint = Paint()
      ..color = isEnabled ? const Color(0xFF6B7C93) : const Color(0xFF6B7C93)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final roundedRect = RRect.fromRectAndRadius(rect, const Radius.circular(2));
    canvas.drawRRect(roundedRect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant WebsiteIconPainter oldDelegate) {
    return oldDelegate.isEnabled != isEnabled;
  }
}

class ModeSelectionScreen extends StatelessWidget {
  const ModeSelectionScreen({super.key});

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
                painter: ModeScreenBackgroundPainter(),
              ),
            ),
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 36),
                  const Padding(
                    padding: EdgeInsets.only(left: 40),
                    child: Text(
                      'How do you want to stay focused?',
                      style: TextStyle(
                        color: Color(0xFF9FBFC1),
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        _buildModeCard(
                          context,
                          icon: const FocusModeIcon(),
                          title: 'Focus / App Blocking',
                          subtitle: 'Block selected apps completely',
                          mode: AppMode.focus,
                          isEnabled: true,
                        ),
                        const SizedBox(height: 20),
                        _buildModeCard(
                          context,
                          icon: const PomodoroModeIcon(),
                          title: 'Pomodoro',
                          subtitle: 'Focus sessions with breaks',
                          mode: AppMode.pomodoro,
                          isEnabled: true,
                        ),
                        const SizedBox(height: 20),
                        _buildModeCard(
                          context,
                          icon: const WebsiteModeIcon(),
                          title: 'Website Blocking',
                          subtitle: 'Coming soon',
                          mode: AppMode.websiteBlocking,
                          isEnabled: false,
                        ),
                      ],
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

  Widget _buildHeader(BuildContext context) {
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
            'Choose Mode',
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

  Widget _buildModeCard(
    BuildContext context, {
    required Widget icon,
    required String title,
    required String subtitle,
    required AppMode mode,
    required bool isEnabled,
  }) {
    return Opacity(
      opacity: isEnabled ? 1.0 : 0.5,
      child: GestureDetector(
        onTap: isEnabled ? () => _onModeSelected(context, mode) : null,
        child: Container(
          height: 96,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isEnabled
                  ? [const Color(0xFF1B2230), const Color(0xFF151B28)]
                  : [const Color(0xFF121726), const Color(0xFF121726)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isEnabled
                  ? (mode == AppMode.focus
                      ? const Color(0xFF2F6F73).withOpacity(0.7)
                      : const Color(0xFF2E3A4A))
                  : Colors.transparent,
              width: 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(
            children: [
              SizedBox(
                width: 36,
                height: 36,
                child: icon,
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: isEnabled
                            ? const Color(0xFFF4F3EF)
                            : const Color(0xFF9FBFC1),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: isEnabled
                            ? const Color(0xFF9FBFC1)
                            : const Color(0xFF6B7C93),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '›',
                style: TextStyle(
                  fontSize: 18,
                  color: isEnabled
                      ? const Color(0xFF9FBFC1)
                      : const Color(0xFF6B7C93),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onModeSelected(BuildContext context, AppMode mode) {
    switch (mode) {
      case AppMode.focus:
        Navigator.pushNamed(context, '/app-selection');
        break;
      case AppMode.pomodoro:
        Navigator.pushNamed(context, '/pomodoro-config');
        break;
      case AppMode.websiteBlocking:
        break;
    }
  }
}

class ModeScreenBackgroundPainter extends CustomPainter {
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
