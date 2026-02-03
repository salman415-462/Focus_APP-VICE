import 'package:flutter/material.dart';
import '../services/method_channel_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _leafController1;
  late AnimationController _leafController2;
  late AnimationController _leafController3;
  late AnimationController _loadingController;

  @override
  void initState() {
    super.initState();

    _leafController1 = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    _leafController2 = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();

    _leafController3 = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _loadingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _navigateToNextScreen();
  }

  @override
  void dispose() {
    _leafController1.dispose();
    _leafController2.dispose();
    _leafController3.dispose();
    _loadingController.dispose();
    super.dispose();
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
            colors: [
              Color(0xFFFFFDF9),
              Color(0xFFF7F5ED),
              Color(0xFFE9E7D8),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: Stack(
          children: [
            _buildSunlight(),
            _buildRiver(),
            _buildBackgroundLeaves(),
            _buildForegroundLeaves(),
            _buildTextContent(),
            _buildLoadingIndicator(),
          ],
        ),
      ),
    );
  }

  Widget _buildSunlight() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0.5, -0.7),
            radius: 1.1,
            colors: [
              const Color(0x66FFF5C4),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRiver() {
    return CustomPaint(
      size: Size.infinite,
      painter: RiverPainter(),
    );
  }

  Widget _buildBackgroundLeaves() {
    return Stack(
      children: [
        _buildFloatingLeaf(
          controller: _leafController1,
          translate: const Offset(30, 80),
          duration: const Duration(seconds: 12),
          child: _buildLeafSmall(const Offset(40, 120)),
        ),
        _buildFloatingLeaf(
          controller: _leafController2,
          translate: const Offset(-40, 90),
          duration: const Duration(seconds: 14),
          child: _buildLeafMid(const Offset(300, 200)),
        ),
        _buildFloatingLeaf(
          controller: _leafController3,
          translate: const Offset(20, 60),
          duration: const Duration(seconds: 10),
          child: _buildLeafSmall(const Offset(100, 320)),
        ),
      ],
    );
  }

  Widget _buildFloatingLeaf({
    required AnimationController controller,
    required Offset translate,
    required Duration duration,
    required Widget child,
  }) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final progress = controller.value;
        final offset = Offset(translate.dx * progress, translate.dy * progress);
        return Transform.translate(
          offset: offset,
          child: child,
        );
      },
    );
  }

  Widget _buildLeafSmall(Offset position) {
    return Positioned(
      left: position.dx,
      top: position.dy,
      child: CustomPaint(
        size: const Size(28, 14),
        painter: LeafPainter(
          color: const Color(0x478DA167),
        ),
      ),
    );
  }

  Widget _buildLeafMid(Offset position) {
    return Positioned(
      left: position.dx,
      top: position.dy,
      child: CustomPaint(
        size: const Size(52, 26),
        painter: LeafPainter(
          color: const Color(0x46738B4F),
        ),
      ),
    );
  }

  Widget _buildForegroundLeaves() {
    return Stack(
      children: [
        _buildLeafBig(const Offset(-30, 620), -18, 0.75),
        _buildLeafBig(const Offset(260, 80), 22, 0.6),
      ],
    );
  }

  Widget _buildLeafBig(Offset position, double rotation, double opacity) {
    return Positioned(
      left: position.dx,
      top: position.dy,
      child: Transform.rotate(
        angle: rotation * 3.14159 / 180,
        child: CustomPaint(
          size: const Size(90, 45),
          painter: LeafPainter(
            color: const Color(0x605F7743).withOpacity(opacity),
          ),
        ),
      ),
    );
  }

  Widget _buildTextContent() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          const Text(
            'Vise',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w500,
              color: Color(0xFF2C2C25),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 38),
          const Text(
            'A space for deep attention',
            style: TextStyle(
              fontSize: 15,
              color: Color(0xFF7A7A70),
            ),
          ),
          const SizedBox(height: 50),
          const Text(
            'Entering a quiet space',
            style: TextStyle(
              fontSize: 13,
              color: Color(0x662C2C25),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return AnimatedBuilder(
      animation: _loadingController,
      builder: (context, child) {
        final opacity = 0.35 + (_loadingController.value * 0.25);
        return Center(
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: const Color(0xFF4E6E3A).withOpacity(opacity),
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}

class RiverPainter extends CustomPainter {
  RiverPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x4DD9F2EC)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 40
      ..strokeCap = StrokeCap.butt
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    final path = Path();
    path.moveTo(size.width * 0.583, -80);
    path.cubicTo(
      size.width * 0.694,
      80,
      size.width * 0.472,
      240,
      size.width * 0.583,
      400,
    );
    path.cubicTo(
      size.width * 0.694,
      560,
      size.width * 0.472,
      720,
      size.width * 0.583,
      size.height + 80,
    );

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant RiverPainter oldDelegate) => false;
}

class LeafPainter extends CustomPainter {
  final Color color;

  LeafPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;

    final centerX = size.width / 2;

    final path = Path();
    path.moveTo(centerX, 0);
    path.cubicTo(
      centerX + size.width * 0.222,
      -size.height * 0.756,
      centerX + size.width * 0.778,
      -size.height * 0.756,
      centerX + size.width,
      0,
    );
    path.cubicTo(
      centerX + size.width * 0.778,
      size.height * 0.444,
      centerX + size.width * 0.222,
      size.height * 0.444,
      centerX,
      0,
    );
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant LeafPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
