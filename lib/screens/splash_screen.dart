import 'package:flutter/material.dart';
import '../services/method_channel_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToNextScreen();
  }

  Future<void> _navigateToNextScreen() async {
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    final onboardingComplete =
        await MethodChannelService.isOnboardingComplete();

    if (onboardingComplete) {
      _checkPermissionsAndRoute();
    } else {
      Navigator.pushReplacementNamed(context, '/onboarding');
    }
  }

  Future<void> _checkPermissionsAndRoute() async {
    try {
      final status = await MethodChannelService.getPermissionStatus();
      if (!mounted) return;

      final accessibilityEnabled =
          status['accessibility_enabled'] as bool? ?? false;
      final overlayEnabled = status['overlay_enabled'] as bool? ?? false;
      final adminEnabled = status['device_admin_enabled'] as bool? ?? false;

      final allPermissionsEnabled =
          accessibilityEnabled && overlayEnabled && adminEnabled;

      if (allPermissionsEnabled) {
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        Navigator.pushReplacementNamed(context, '/permissions');
      }
    } catch (e) {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/permissions');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0C0F16), Color(0xFF141722)],
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      Color(0x001B2A2D),
                      Colors.transparent,
                    ],
                    stops: [0.0, 1.0],
                    center: Alignment(0.5, 0.42),
                    radius: 0.38,
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      Color(0x334FA3A5),
                      Colors.transparent,
                    ],
                    stops: [0.7, 1.0],
                    center: Alignment(0.5, 0.42),
                    radius: 0.28,
                  ),
                ),
              ),
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLogo(),
                  const SizedBox(height: 162),
                  const Text(
                    'Vise',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFFF4F3EF),
                    ),
                  ),
                  const SizedBox(height: 34),
                  const Text(
                    'Your focus is protected.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFFA8D5D6),
                    ),
                  ),
                  const SizedBox(height: 56),
                  _buildLoadingIndicator(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 160,
      height: 160,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A1F2B), Color(0xFF0C0F16)],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              width: 128,
              height: 128,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: const Color(0x332E3A3D),
                ),
              ),
            ),
          ),
          Positioned(
            top: 34,
            left: 48,
            child: Container(
              width: 64,
              height: 92,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: const Color(0x33242A38).withOpacity(0.9),
              ),
            ),
          ),
          Positioned(
            top: 98,
            left: 48,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(16),
              ),
              child: Container(
                width: 64,
                height: 26,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF2A3246), Color(0xFF1C2130)],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 40,
                      height: 3,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F3EF).withOpacity(0.45),
                        borderRadius: BorderRadius.circular(1.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 30,
            left: 74,
            child: Container(
              width: 12,
              height: 14,
              decoration: BoxDecoration(
                color: const Color(0xFFF4F3EF).withOpacity(0.7),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return CustomPaint(
      size: const Size(32, 32),
      painter: DashedCirclePainter(
        color: const Color(0x334FA3A5).withOpacity(0.8),
        strokeWidth: 2,
        dashLength: 6,
        gapLength: 12,
      ),
    );
  }
}

class DashedCirclePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashLength;
  final double gapLength;

  DashedCirclePainter({
    required this.color,
    this.strokeWidth = 2,
    this.dashLength = 6,
    this.gapLength = 12,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = 16.0;

    final path = Path();
    final circumference = 2 * 3.14159 * radius;
    final totalDashLength = dashLength + gapLength;
    final dashCount = circumference / totalDashLength;

    for (int i = 0; i < dashCount.floor(); i++) {
      final startAngle = (i * totalDashLength / radius);
      final endAngle = startAngle + (dashLength / radius);
      path.addArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        endAngle - startAngle,
      );
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
