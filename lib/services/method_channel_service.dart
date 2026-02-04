import 'package:flutter/services.dart';

class MethodChannelService {
  static const _channel = MethodChannel('core.blocker/channel');

  static Future<Map<String, dynamic>> getPermissionStatus() async {
    try {
      final result = await _channel
          .invokeMethod<Map<Object?, Object?>>('getPermissionStatus');
      if (result == null) {
        return _disabledPermissions();
      }
      return {
        'accessibility_enabled':
            result['accessibility_enabled'] as bool? ?? false,
        'service_running': result['service_running'] as bool? ?? false,
        'overlay_enabled': result['overlay_enabled'] as bool? ?? false,
        'device_admin_enabled':
            result['device_admin_enabled'] as bool? ?? false,
        'is_block_active': result['is_block_active'] as bool? ?? false,
        'bypass_active': result['bypass_active'] as bool? ?? false,
      };
    } on PlatformException catch (_) {
      return _disabledPermissions();
    } catch (_) {
      return _disabledPermissions();
    }
  }

  static Future<Map<String, dynamic>> getBlockStatus() async {
    try {
      final result =
          await _channel.invokeMethod<Map<Object?, Object?>>('getBlockStatus');
      if (result == null) {
        return {
          'isBlockActive': false,
          'blockedApps': <String>[],
          'bypassActive': false,
        };
      }
      return {
        'isBlockActive': result['isBlockActive'] as bool? ?? false,
        'blockedApps': (result['blockedApps'] as List<Object?>?)
                ?.map((e) => e.toString())
                .toList() ??
            <String>[],
        'bypassActive': result['bypassActive'] as bool? ?? false,
      };
    } on PlatformException catch (_) {
      return {
        'isBlockActive': false,
        'blockedApps': <String>[],
        'bypassActive': false,
      };
    } catch (_) {
      return {
        'isBlockActive': false,
        'blockedApps': <String>[],
        'bypassActive': false,
      };
    }
  }

  static Future<List<Map<String, String>>> getInstalledApps() async {
    try {
      final result =
          await _channel.invokeMethod<List<Object?>>('getInstalledApps');
      if (result == null) {
        return [];
      }
      return result.map((item) {
        final map = item as Map<Object?, Object?>;
        return {
          'packageName': map['packageName'] as String? ?? '',
          'appName': map['appName'] as String? ?? '',
        };
      }).toList();
    } on PlatformException catch (_) {
      return [];
    } catch (_) {
      return [];
    }
  }

  static Future<bool> saveBlockRules(String rulesJson) async {
    try {
      final result = await _channel
          .invokeMethod<bool>('saveBlockRules', {'rulesJson': rulesJson});
      return result ?? false;
    } on PlatformException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> requestEmergencyBypass(String packageName) async {
    try {
      final result = await _channel.invokeMethod<bool>(
          'requestEmergencyBypass', {'packageName': packageName});
      return result ?? false;
    } on PlatformException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> requestEmergencyBypassWithPin(
      String packageName, String pin) async {
    try {
      final result = await _channel.invokeMethod<bool>(
          'requestEmergencyBypass', {'packageName': packageName, 'pin': pin});
      return result ?? false;
    } on PlatformException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isBypassPinSet() async {
    try {
      final result = await _channel.invokeMethod<bool>('isBypassPinSet');
      return result ?? false;
    } on PlatformException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> setBypassPin(String pin) async {
    try {
      final result =
          await _channel.invokeMethod<bool>('setBypassPin', {'pin': pin});
      return result ?? false;
    } on PlatformException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> verifyBypassPin(String pin) async {
    try {
      final result =
          await _channel.invokeMethod<bool>('verifyBypassPin', {'pin': pin});
      return result ?? false;
    } on PlatformException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Start a one-time focus timer
  /// Returns true only if timer is successfully created and persisted
  static Future<bool> startOneTimeTimer({
    required int durationMinutes,
    required List<String> blockedPackages,
  }) async {
    try {
      final result = await _channel.invokeMethod<bool>('startOneTimeTimer', {
        'durationMinutes': durationMinutes,
        'blockedPackages': blockedPackages,
      });
      return result ?? false;
    } on PlatformException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Start a custom duration focus timer
  /// Returns true only if timer is successfully created and persisted
  static Future<bool> startCustomDurationTimer({
    required int durationMinutes,
    required List<String> blockedPackages,
  }) async {
    try {
      final result =
          await _channel.invokeMethod<bool>('startCustomDurationTimer', {
        'durationMinutes': durationMinutes,
        'blockedPackages': blockedPackages,
      });
      return result ?? false;
    } on PlatformException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Start a pomodoro focus timer
  /// Returns true only if timer is successfully created and persisted
  static Future<bool> startPomodoroFocusTimer({
    required int durationMinutes,
  }) async {
    try {
      final result =
          await _channel.invokeMethod<bool>('startPomodoroFocusTimer', {
        'durationMinutes': durationMinutes,
      });
      return result ?? false;
    } on PlatformException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Start a pomodoro break timer
  /// Returns true only if timer is successfully created and persisted
  static Future<bool> startPomodoroBreakTimer({
    required int durationMinutes,
  }) async {
    try {
      final result =
          await _channel.invokeMethod<bool>('startPomodoroBreakTimer', {
        'durationMinutes': durationMinutes,
      });
      return result ?? false;
    } on PlatformException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Get active timer sessions from native
  /// Returns list of active timer info with remaining time from native
  static Future<List<Map<String, dynamic>>> getActiveTimers() async {
    try {
      final result =
          await _channel.invokeMethod<List<Object?>>('getActiveTimers');
      if (result == null) {
        return [];
      }
      return result.map((item) {
        final map = item as Map<Object?, Object?>;
        return {
          'id': map['id'] as String? ?? '',
          'mode': map['mode'] as String? ?? 'FOCUS',
          'startTimeMillis': map['startTimeMillis'] as int? ?? 0,
          'durationMinutes': map['durationMinutes'] as int? ?? 0,
          'remainingSeconds': map['remainingSeconds'] as int? ?? 0,
          'blockedPackages': (map['blockedPackages'] as List<Object?>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              <String>[],
        };
      }).toList();
    } on PlatformException catch (_) {
      return [];
    } catch (_) {
      return [];
    }
  }

  static Future<bool> openAccessibilitySettings() async {
    try {
      final result =
          await _channel.invokeMethod<bool>('openAccessibilitySettings');
      return result ?? false;
    } on PlatformException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> openOverlaySettings() async {
    try {
      final result = await _channel.invokeMethod<bool>('openOverlaySettings');
      return result ?? false;
    } on PlatformException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }

  static Future<String> openDeviceAdminSettings() async {
    try {
      final result =
          await _channel.invokeMethod<String>('openDeviceAdminSettings');
      return result ?? 'failed';
    } on PlatformException catch (_) {
      return 'failed';
    } catch (_) {
      return 'failed';
    }
  }

  /// Notify native side that permissions should be refreshed
  /// Used when returning from Device Admin settings
  static Future<bool> refreshPermissions() async {
    try {
      final result = await _channel.invokeMethod<bool>('refreshPermissions');
      return result ?? false;
    } on PlatformException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Check if the accessibility service is actually running
  /// (not just enabled in settings)
  static Future<bool> isAccessibilityServiceRunning() async {
    try {
      final result =
          await _channel.invokeMethod<bool>('isAccessibilityServiceRunning');
      return result ?? false;
    } on PlatformException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Check if onboarding has been completed
  static Future<bool> isOnboardingComplete() async {
    try {
      final result = await _channel.invokeMethod<bool>('isOnboardingComplete');
      return result ?? false;
    } on PlatformException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Mark onboarding as complete
  static Future<void> setOnboardingComplete() async {
    try {
      await _channel.invokeMethod<void>('setOnboardingComplete');
    } catch (_) {
      // Silent fail
    }
  }

  static Map<String, dynamic> _disabledPermissions() {
    return {
      'accessibility_enabled': false,
      'overlay_enabled': false,
      'device_admin_enabled': false,
      'is_block_active': false,
      'bypass_active': false,
    };
  }
}
