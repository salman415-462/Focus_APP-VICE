import 'package:flutter/material.dart';
import '../services/method_channel_service.dart';
import '../services/selected_apps_store.dart';

class AppInfo {
  final String packageName;
  final String appName;
  bool isBlocked;

  AppInfo({
    required this.packageName,
    required this.appName,
    required this.isBlocked,
  });
}

class AppSelectionScreen extends StatefulWidget {
  const AppSelectionScreen({super.key});

  @override
  State<AppSelectionScreen> createState() => _AppSelectionScreenState();
}

class _AppSelectionScreenState extends State<AppSelectionScreen> {
  final List<AppInfo> _apps = [];
  final List<AppInfo> _filteredApps = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  String _searchQuery = '';
  bool _hasError = false;
  bool _isSessionActive = false;

  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _loadApps();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
        _filterApps();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadApps() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final status = await MethodChannelService.getBlockStatus();
      if (!mounted) return;

      _isSessionActive = status['isBlockActive'] as bool? ?? false;

      final installedApps = await MethodChannelService.getInstalledApps();
      if (!mounted) return;

      final blockedStatus = await MethodChannelService.getBlockStatus();
      if (!mounted) return;

      final blockedPackages = Set<String>.from(
          (blockedStatus['blockedApps'] as List<String>?) ?? <String>[]);

      setState(() {
        _apps.clear();
        for (final app in installedApps) {
          if (app['packageName']?.isNotEmpty == true &&
              app['appName']?.isNotEmpty == true) {
            _apps.add(AppInfo(
              packageName: app['packageName']!,
              appName: app['appName']!,
              isBlocked: blockedPackages.contains(app['packageName']),
            ));
          }
        }
        _filteredApps.clear();
        _filteredApps.addAll(_apps);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  void _filterApps() {
    if (_searchQuery.isEmpty) {
      _filteredApps.clear();
      _filteredApps.addAll(_apps);
    } else {
      _filteredApps.clear();
      _filteredApps.addAll(
        _apps.where((app) => app.appName.toLowerCase().contains(_searchQuery)),
      );
    }
  }

  void _toggleAppBlock(AppInfo app) {
    setState(() {
      app.isBlocked = !app.isBlocked;
    });
  }

  int get _blockedCount => _apps.where((app) => app.isBlocked).length;

  void _proceedToSchedule() {
    if (_isNavigating) return;

    final selectedPackages = _apps
        .where((app) => app.isBlocked)
        .map((app) => app.packageName)
        .toList();
    SelectedAppsStore().setBlockedPackages(selectedPackages);

    if (_blockedCount == 0) {
      _showWarningDialog();
    } else {
      setState(() => _isNavigating = true);

      Navigator.pushNamed(context, '/schedule-config').then((_) {
        if (mounted) {
          setState(() => _isNavigating = false);
        }
      });
    }
  }

  void _showWarningDialog() {
    if (_isNavigating) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFFFDF2),
        title: const Text(
          'No Apps Selected',
          style: TextStyle(color: Color(0xFF2C2C25)),
        ),
        content: const Text(
          'You have not selected any apps to block. You can continue without blocking, but blocking will not be active.',
          style: TextStyle(color: Color(0xFF7A7A70)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF7A7A70)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _isNavigating = true);

              Navigator.pushNamed(context, '/schedule-config').then((_) {
                if (mounted) {
                  setState(() => _isNavigating = false);
                }
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6E8F5E),
              foregroundColor: Colors.white,
            ),
            child: const Text('Continue Anyway'),
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
              top: 0,
              child: Container(
                height: 260,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.3, 0.0),
                    radius: 0.7,
                    colors: [
                      const Color(0xFFFFFFFF).withOpacity(0.85),
                      const Color(0xFFFFFFFF).withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: CustomPaint(
                painter: _LeafPainter(),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  _buildHeader(),
                  const SizedBox(height: 32),
                  _buildSearchBar(),
                  const SizedBox(height: 18),
                  _buildSectionHint(),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _isLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF6E8F5E),
                            ),
                          )
                        : _filteredApps.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 64,
                                      height: 64,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE6EFE3),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.apps,
                                        color: Color(0xFF6E8F5E),
                                        size: 32,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      _searchQuery.isEmpty
                                          ? 'No apps found'
                                          : 'No apps match your search',
                                      style: const TextStyle(
                                        color: Color(0xFF7A7A70),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                itemCount: _filteredApps.length,
                                itemBuilder: (context, index) {
                                  final app = _filteredApps[index];
                                  return _AppTile(
                                    app: app,
                                    onToggle: () => _toggleAppBlock(app),
                                  );
                                },
                              ),
                  ),
                  const SizedBox(height: 24),
                  _buildCTAButton(),
                  const SizedBox(height: 24),
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
      padding: const EdgeInsets.only(left: 8, right: 16, top: 12),
      child: Row(
        children: [
          IconButton(
            onPressed: _isNavigating
                ? null
                : () {
                    if (mounted && !_isNavigating) {
                      Navigator.pop(context);
                    }
                  },
            icon: const Text(
              '‹',
              style: TextStyle(
                color: Color(0xFF2C2C25),
                fontSize: 28,
              ),
            ),
          ),
          const Expanded(
            child: Text(
              'Select apps',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: Color(0xFF2C2C25),
              ),
            ),
          ),
          Text(
            '$_blockedCount selected',
            style: const TextStyle(
              color: Color(0xFF7A7A70),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        height: 44,
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
        child: TextField(
          controller: _searchController,
          style: const TextStyle(
            color: Color(0xFF2C2C25),
            fontSize: 13,
          ),
          decoration: const InputDecoration(
            hintText: 'Search apps',
            hintStyle: TextStyle(
              color: Color(0xFF9A9A8E),
              fontSize: 13,
            ),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            isDense: true,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHint() {
    return const Padding(
      padding: EdgeInsets.only(left: 24),
      child: Text(
        'Installed apps',
        style: TextStyle(
          color: Color(0xFF7A7A70),
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildCTAButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 72),
      child: GestureDetector(
        onTap: _isLoading || _isNavigating ? null : _proceedToSchedule,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6E8F5E), Color(0xFF4E6E3A)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.14),
                offset: const Offset(0, 10),
                blurRadius: 18,
              ),
            ],
          ),
          child: const Center(
            child: Text(
              'Continue to schedule',
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
}

class _LeafPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF8DA167)
      ..style = PaintingStyle.fill
      ..filterQuality = FilterQuality.high;

    final smallLeafPath = Path()
      ..moveTo(0, 0)
      ..cubicTo(6, -10, 20, -10, 28, 0)
      ..cubicTo(20, 6, 6, 6, 0, 0)
      ..close();

    canvas.save();
    canvas.translate(40, 140);
    canvas.scale(0.8);
    canvas.drawPath(
        smallLeafPath, paint..color = paint.color.withOpacity(0.18));
    canvas.restore();

    canvas.save();
    canvas.translate(300, 220);
    canvas.scale(0.9);
    canvas.rotate(0.3);
    canvas.drawPath(
        smallLeafPath, paint..color = paint.color.withOpacity(0.18));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AppTile extends StatelessWidget {
  final AppInfo app;
  final VoidCallback onToggle;

  const _AppTile({
    required this.app,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = app.isBlocked;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: GestureDetector(
        onTap: onToggle,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
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
                  height: 56,
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
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: isSelected
                        ? const BorderRadius.horizontal(
                            right: Radius.circular(18),
                          )
                        : BorderRadius.circular(18),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF6E8F5E)
                              : const Color(0xFFE6EFE3),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.apps,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          app.appName,
                          style: const TextStyle(
                            color: Color(0xFF2C2C25),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      _buildToggle(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToggle() {
    final isSelected = app.isBlocked;

    return Container(
      width: 36,
      height: 20,
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF6E8F5E) : const Color(0xFFE6EFE3),
        borderRadius: BorderRadius.circular(10),
      ),
      child: AnimatedAlign(
        alignment: isSelected ? Alignment.centerRight : Alignment.centerLeft,
        duration: const Duration(milliseconds: 200),
        child: Container(
          margin: const EdgeInsets.all(2),
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : const Color(0xFF9A9A8E),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}
