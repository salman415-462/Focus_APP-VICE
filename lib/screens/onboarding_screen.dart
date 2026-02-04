import 'package:flutter/material.dart';
import '../services/method_channel_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _currentPage = 0;
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onNextPage() {
    if (_currentPage < 2) {
      _pageController.animateToPage(
        _currentPage + 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finishOnboarding();
    }
  }

  Future<void> _finishOnboarding() async {
    // Mark onboarding as complete
    await MethodChannelService.setOnboardingComplete();

    if (!mounted) return;

    // Navigate to permissions screen
    Navigator.pushReplacementNamed(context, '/permissions');
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
              Color(0xFFFFFDF2),
              Color(0xFFE9E7D8),
            ],
            stops: [0.0, 1.0],
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: OnboardingBackgroundPainter(),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      onPageChanged: (int page) {
                        setState(() {
                          _currentPage = page;
                        });
                      },
                      children: [
                        _buildPage(
                          icon: Icons.shield_outlined,
                          title: 'Focus Guard',
                          description:
                              'A discipline tool to help you maintain focus and avoid distractions.',
                          iconBgColor: const Color(0xFFE6EFE3),
                          iconColor: const Color(0xFF6E8F5E),
                        ),
                        _buildPage(
                          icon: Icons.block,
                          title: 'App Blocking',
                          description:
                              'Select apps to block during focus time. Blocked apps cannot be accessed.',
                          iconBgColor: const Color(0xFFE6EFE3),
                          iconColor: const Color(0xFF6E8F5E),
                        ),
                        _buildPage(
                          icon: Icons.timer,
                          title: 'Emergency Bypass',
                          description:
                              'Need access? You can request a 2-minute emergency bypass per app.',
                          iconBgColor: const Color(0xFFE6EFE3),
                          iconColor: const Color(0xFF6E8F5E),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.only(left: 24, right: 24, bottom: 40),
                    child: Column(
                      children: [
                        _buildPageIndicator(),
                        const SizedBox(height: 32),
                        _buildContinueButton(),
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

  Widget _buildPageIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: _currentPage == index ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: _currentPage == index
                ? const Color(0xFF6E8F5E)
                : const Color(0xFFD5D4C8),
          ),
        );
      }),
    );
  }

  Widget _buildContinueButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _onNextPage,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6E8F5E),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: Text(
          _currentPage == 2 ? 'Get Started' : 'Continue',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildPage({
    required IconData icon,
    required String title,
    required String description,
    required Color iconBgColor,
    required Color iconColor,
  }) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: iconBgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 48,
              color: iconColor,
            ),
          ),
          const SizedBox(height: 48),
          Text(
            title,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2C2C25),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            description,
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF7A7A70),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class OnboardingBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Light gradient overlay
    final lightPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFFFFF).withOpacity(0.7),
          const Color(0xFFFFFFFF).withOpacity(0),
        ],
        stops: const [0.0, 1.0],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.5, 0),
          radius: size.width * 0.8,
        ),
      )
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height * 0.4),
      lightPaint,
    );

    // Decorative leaves
    final leafPaint = Paint()
      ..color = const Color(0xFF8DA167)
      ..style = PaintingStyle.fill
      ..filterQuality = FilterQuality.high;

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

    // Background leaves
    canvas.save();
    canvas.translate(20, 100);
    drawLeafSmall(leafPaint..color = leafPaint.color.withOpacity(0.15),
        const Offset(40, 120), 0);
    canvas.restore();

    canvas.save();
    canvas.translate(-20, 80);
    drawLeafSmall(leafPaint..color = leafPaint.color.withOpacity(0.12),
        const Offset(320, 200), 0);
    canvas.restore();

    canvas.save();
    canvas.translate(60, 400);
    drawLeafSmall(leafPaint..color = leafPaint.color.withOpacity(0.1),
        const Offset(280, 500), 0);
    canvas.restore();

    // Foreground decorative leaf
    canvas.save();
    canvas.translate(-10, 580);
    canvas.rotate(-18 * 3.14159 / 180);
    final bigLeafPaint = Paint()
      ..color = const Color(0xFF5F7743)
      ..style = PaintingStyle.fill;
    final bigLeafPath = Path()
      ..moveTo(0, 0)
      ..cubicTo(20, -34, 70, -34, 90, 0)
      ..cubicTo(70, 20, 20, 20, 0, 0);
    canvas.drawPath(
        bigLeafPath, bigLeafPaint..color = bigLeafPaint.color.withOpacity(0.2));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
