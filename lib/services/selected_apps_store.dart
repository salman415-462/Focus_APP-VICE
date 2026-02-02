/// Simple Flutter-side store for selected blocked apps
/// Single source of truth for selected packages
/// No state management libraries - static singleton pattern
class SelectedAppsStore {
  static final SelectedAppsStore _instance = SelectedAppsStore._internal();

  factory SelectedAppsStore() {
    return _instance;
  }

  SelectedAppsStore._internal();

  List<String> _blockedPackages = [];

  /// Get the list of selected blocked packages
  List<String> get blockedPackages => List.unmodifiable(_blockedPackages);

  /// Save selected blocked packages
  void setBlockedPackages(List<String> packages) {
    _blockedPackages = packages;
  }

  /// Clear the stored packages
  void clear() {
    _blockedPackages = [];
  }

  /// Check if any packages are selected
  bool hasPackages() => _blockedPackages.isNotEmpty;

  /// Get count of selected packages
  int get count => _blockedPackages.length;
}
