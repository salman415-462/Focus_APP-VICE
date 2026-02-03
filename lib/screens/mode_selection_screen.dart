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
      size: const Size(28, 28),
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
    final radius = 14.0;

    final gradient = RadialGradient(
      colors: isEnabled
          ? [const Color(0xFF6E8F5E), const Color(0xFF4E6E3A)]
          : [const Color(0xFFD5D4C8), const Color(0xFFD5D4C8)],
    );

    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius,
      Paint()..shader = gradient.createShader(rect),
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
      size: const Size(28, 28),
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
    final radius = 14.0;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = isEnabled ? const Color(0xFFE6EFE3) : const Color(0xFFD5D4C8),
    );

    canvas.drawCircle(
      center,
      7,
      Paint()
        ..color = isEnabled ? const Color(0xFF6E8F5E) : const Color(0xFFD5D4C8)
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
      size: const Size(28, 28),
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
    final rect = Rect.fromCenter(center: center, width: 14, height: 10);

    final borderPaint = Paint()
      ..color = isEnabled ? const Color(0xFFD5D4C8) : const Color(0xFFD5D4C8)
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
                painter: ModeScreenBackgroundPainter(),
              ),
            ),
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 34),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: const Text(
                      'Select how focus should be held',
                      style: TextStyle(
                        color: Color(0xFF7A7A70),
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      children: [
                        _buildModeCard(
                          context,
                          icon: const FocusModeIcon(),
                          title: 'App blocking',
                          subtitle: 'Keep selected apps out of reach',
                          mode: AppMode.focus,
                          isEnabled: true,
                        ),
                        const SizedBox(height: 16),
                        _buildModeCard(
                          context,
                          icon: const PomodoroModeIcon(),
                          title: 'Pomodoro rhythm',
                          subtitle: 'Work and rest in gentle cycles',
                          mode: AppMode.pomodoro,
                          isEnabled: true,
                        ),
                        const SizedBox(height: 16),
                        _buildModeCard(
                          context,
                          icon: const WebsiteModeIcon(),
                          title: 'Website blocking',
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
                color: Color(0xFF2C2C25),
                fontSize: 28,
              ),
            ),
          ),
          const Text(
            'Choose mode',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: Color(0xFF2C2C25),
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
          height: 104,
          decoration: BoxDecoration(
            color: isEnabled ? Colors.white : const Color(0xFFF2F1EA),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.14),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: icon,
              ),
              const SizedBox(width: 56),
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
                            ? const Color(0xFF2C2C25)
                            : const Color(0xFF8B8B80),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: isEnabled
                            ? const Color(0xFF7A7A70)
                            : const Color(0xFF9A9A8E),
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
                      ? const Color(0xFF7A7A70)
                      : const Color(0xFF7A7A70),
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
      Rect.fromLTWH(0, 0, size.width, size.height * 0.325),
      lightPaint,
    );

    final leafSmallPaint = Paint()
      ..color = const Color(0xFF8DA167)
      ..style = PaintingStyle.fill;

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
    canvas.translate(20, 70);
    drawLeafSmall(leafSmallPaint, const Offset(40, 120), 0);
    canvas.restore();

    canvas.save();
    canvas.translate(-30, 80);
    drawLeafSmall(leafSmallPaint, const Offset(300, 180), 0);
    canvas.restore();

    canvas.save();
    canvas.rotate(18 * 3.14159 / 180);
    final foregroundPaint = Paint()
      ..color = const Color(0xFF738B4F).withOpacity(0.7)
      ..style = PaintingStyle.fill;
    final leafMidPath = Path()
      ..moveTo(280, 540)
      ..cubicTo(292, 520, 320, 520, 332, 540)
      ..cubicTo(320, 552, 292, 552, 280, 540);
    canvas.drawPath(leafMidPath, foregroundPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
