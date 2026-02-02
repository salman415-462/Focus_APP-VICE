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
      _isNavigating = true;
      Navigator.pushNamed(context, '/schedule-config');
    }
  }

  void _showWarningDialog() {
    if (_isNavigating) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        title: const Text(
          'No Apps Selected',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'You have not selected any apps to block. You can continue without blocking, but blocking will not be active.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _isNavigating = true;
              Navigator.pushNamed(context, '/schedule-config');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F3460),
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
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [const Color(0xFF0C0F16), const Color(0xFF141722)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [
            Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.5, 0.35),
                  radius: 0.6,
                  colors: [
                    const Color(0xFF1C2430).withOpacity(0.5),
                    const Color(0xFF0C0F16).withOpacity(0),
                  ],
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  _buildHeader(),
                  const SizedBox(height: 28),
                  _buildSearchBar(),
                  const SizedBox(height: 14),
                  _buildSectionHint(),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _isLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF0F3460),
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
                                        color: const Color(0xFF2E3A4A),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.apps,
                                        color: Color(0xFF6B7C93),
                                        size: 32,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      _searchQuery.isEmpty
                                          ? 'No apps found'
                                          : 'No apps match your search',
                                      style: const TextStyle(
                                        color: Color(0xFF6B7C93),
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
                color: Color(0xFF9FBFC1),
                fontSize: 28,
              ),
            ),
          ),
          const Expanded(
            child: Text(
              'Select Apps',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: Color(0xFFF4F3EF),
              ),
            ),
          ),
          Text(
            '$_blockedCount selected',
            style: const TextStyle(
              color: Color(0xFF9FBFC1),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [const Color(0xFF1C2433), const Color(0xFF151B28)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: TextField(
          controller: _searchController,
          style: const TextStyle(color: Color(0xFF9FBFC1), fontSize: 13),
          decoration: const InputDecoration(
            hintText: 'Search apps',
            hintStyle: TextStyle(color: Color(0xFF9FBFC1), fontSize: 13),
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
          color: Color(0xFF6B7C93),
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildCTAButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: GestureDetector(
        onTap: _isLoading || _isNavigating ? null : _proceedToSchedule,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color(0xFF4FA3A5), const Color(0xFF2F6F73)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Center(
            child: Text(
              'Continue to Schedule',
              style: TextStyle(
                color: Color(0xFF0C0F16),
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: GestureDetector(
        onTap: onToggle,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    colors: [
                      const Color(0xFF4FA3A5).withOpacity(0.25),
                      Colors.transparent,
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  )
                : null,
            color: const Color(0xFF161C29),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF4FA3A5).withOpacity(0.55)
                  : Colors.transparent,
              width: 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF4FA3A5)
                      : const Color(0xFF2E3A4A),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.apps,
                  color: Color(0xFF0C0F16),
                  size: 16,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Text(
                  app.appName,
                  style: const TextStyle(
                    color: Color(0xFFF4F3EF),
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
    );
  }

  Widget _buildToggle() {
    final isSelected = app.isBlocked;

    return Container(
      width: 36,
      height: 20,
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF4FA3A5) : const Color(0xFF2E3A4A),
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
            color:
                isSelected ? const Color(0xFF0C0F16) : const Color(0xFF9FBFC1),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}
