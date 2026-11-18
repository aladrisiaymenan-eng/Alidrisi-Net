import 'package:flutter/services.dart';

class NativeConnector {
  static const MethodChannel _channel =
      MethodChannel('com.manus.internet_manager/device');
  static const MethodChannel _vpnChannel =
      MethodChannel('com.manus.internet_manager/vpn');

  static Future<List<Map<String, dynamic>>> getInstalledApps() async {
    try {
      final result =
          await _channel.invokeMethod<List<dynamic>>('getInstalledApps');
      return (result ?? const <dynamic>[]).whereType<Map>().map((raw) {
        final app = <String, dynamic>{};
        raw.forEach((key, value) => app[key.toString()] = value);
        return app;
      }).toList();
    } on MissingPluginException {
      throw StateError('قناة التطبيقات غير متاحة على هذه المنصة');
    } on PlatformException catch (error) {
      throw StateError('تعذر قراءة التطبيقات: ${error.message ?? error.code}');
    }
  }

  static Future<List<Map<String, dynamic>>> getUsageStats(
      {required DateTime start, required DateTime end}) async {
    try {
      final result =
          await _channel.invokeMethod<List<dynamic>>('getUsageStats', {
        'startMillis': start.millisecondsSinceEpoch,
        'endMillis': end.millisecondsSinceEpoch,
      });
      return (result ?? const <dynamic>[]).whereType<Map>().map((raw) {
        final item = <String, dynamic>{};
        raw.forEach((key, value) => item[key.toString()] = value);
        return item;
      }).toList();
    } on MissingPluginException {
      throw StateError('قناة استهلاك التطبيقات غير متاحة على هذه المنصة');
    } on PlatformException catch (error) {
      throw StateError(
          'تعذر قراءة استهلاك التطبيقات: ${error.message ?? error.code}');
    }
  }

  static Future<List<Map<String, dynamic>>> getUsageHistory(
      {required DateTime start, required DateTime end}) async {
    try {
      final result =
          await _channel.invokeMethod<List<dynamic>>('getUsageHistory', {
        'startMillis': start.millisecondsSinceEpoch,
        'endMillis': end.millisecondsSinceEpoch,
      });
      return (result ?? const <dynamic>[]).whereType<Map>().map((raw) {
        final item = <String, dynamic>{};
        raw.forEach((key, value) => item[key.toString()] = value);
        return item;
      }).toList();
    } on MissingPluginException {
      throw StateError('قناة سجل الاستخدام غير متاحة على هذه المنصة');
    } on PlatformException catch (error) {
      throw StateError(
          'تعذر قراءة سجل الاستخدام: ${error.message ?? error.code}');
    }
  }

  static Future<String?> getNetworkStatsError() async {
    try {
      final result = await _channel
          .invokeMethod<Map<dynamic, dynamic>>('getNetworkStatsDiagnostics');
      final map = _normalizeMap(result);
      final error = map['lastError']?.toString().trim() ?? '';
      return error.isEmpty ? null : error;
    } on MissingPluginException {
      return 'قناة تشخيص الإحصاءات غير متاحة';
    } on PlatformException catch (error) {
      return error.message ?? error.code;
    }
  }

  static Future<Map<String, dynamic>> getPermissionStatus() async {
    try {
      final result = await _channel
          .invokeMethod<Map<dynamic, dynamic>>('getPermissionStatus');
      return _normalizeMap(result);
    } on MissingPluginException {
      return {'supported': false};
    } on PlatformException catch (error) {
      return {'supported': false, 'error': error.message ?? error.code};
    }
  }

  static Future<String> openUsageAccessSettings() async {
    try {
      return await _channel.invokeMethod<String>('openUsageAccessSettings') ??
          'OPENED';
    } on MissingPluginException {
      return 'UNSUPPORTED';
    } on PlatformException catch (error) {
      return 'ERROR: ${error.message ?? error.code}';
    }
  }

  static Future<String> openVpnSettings() async {
    try {
      return await _vpnChannel.invokeMethod<String>('openVpnSettings') ??
          'OPENED';
    } on MissingPluginException {
      return 'UNSUPPORTED';
    } on PlatformException catch (error) {
      return 'ERROR: ${error.message ?? error.code}';
    }
  }

  static Future<String> requestVpnPermission() async {
    try {
      return await _vpnChannel.invokeMethod<String>('requestVpnPermission') ??
          'REQUESTED';
    } on MissingPluginException {
      return 'UNSUPPORTED';
    } on PlatformException catch (error) {
      return 'ERROR: ${error.message ?? error.code}';
    }
  }

  static Future<String> requestNotificationPermission() async {
    try {
      return await _channel
              .invokeMethod<String>('requestNotificationPermission') ??
          'REQUESTED';
    } on MissingPluginException {
      return 'UNSUPPORTED';
    } on PlatformException catch (error) {
      return 'ERROR: ${error.message ?? error.code}';
    }
  }

  static Future<String> startSpeedService() async {
    try {
      return await _channel.invokeMethod<String>('startSpeedService') ??
          'STARTED';
    } on MissingPluginException {
      return 'UNSUPPORTED';
    } on PlatformException catch (error) {
      return 'ERROR: ${error.message ?? error.code}';
    }
  }

  static Future<String> stopSpeedService() async {
    try {
      return await _channel.invokeMethod<String>('stopSpeedService') ??
          'STOPPED';
    } on MissingPluginException {
      return 'UNSUPPORTED';
    } on PlatformException catch (error) {
      return 'ERROR: ${error.message ?? error.code}';
    }
  }

  static Future<String> startLimitMonitor() async {
    try {
      return await _channel.invokeMethod<String>('startLimitMonitor') ??
          'STARTED';
    } on MissingPluginException {
      return 'UNSUPPORTED';
    } on PlatformException catch (error) {
      return 'ERROR: ${error.message ?? error.code}';
    }
  }

  static Future<String> stopLimitMonitor() async {
    try {
      return await _channel.invokeMethod<String>('stopLimitMonitor') ??
          'STOPPED';
    } on MissingPluginException {
      return 'UNSUPPORTED';
    } on PlatformException catch (error) {
      return 'ERROR: ${error.message ?? error.code}';
    }
  }

  static Future<String> clearAutomaticBlocks() async {
    try {
      return await _channel.invokeMethod<String>('clearAutomaticBlocks') ??
          'REQUESTED';
    } on MissingPluginException {
      return 'UNSUPPORTED';
    } on PlatformException catch (error) {
      return 'ERROR: ${error.message ?? error.code}';
    }
  }

  static Future<Map<String, dynamic>> getRealtimeSpeed() async {
    try {
      final result = await _channel
          .invokeMethod<Map<dynamic, dynamic>>('getRealtimeSpeed');
      return _normalizeMap(result);
    } on MissingPluginException {
      return {'supported': false};
    } on PlatformException catch (error) {
      return {'supported': false, 'error': error.message ?? error.code};
    }
  }

  static Future<String> startVpn({
    required List<String> blockedPackages,
    List<String> automaticPackages = const <String>[],
    List<String> backgroundPackages = const <String>[],
  }) async {
    try {
      return await _vpnChannel.invokeMethod<String>('startVpn', {
            'blockedPackages': blockedPackages,
            'automaticBlockedPackages': automaticPackages,
            'backgroundBlockedPackages': backgroundPackages,
          }) ??
          'STARTED';
    } on MissingPluginException {
      return 'UNSUPPORTED';
    } on PlatformException catch (error) {
      return 'ERROR: ${error.message ?? error.code}';
    }
  }

  static Future<String> updateVpnPolicies(
    List<String> blockedPackages, {
    List<String> automaticPackages = const <String>[],
    List<String> backgroundPackages = const <String>[],
  }) async {
    try {
      return await _vpnChannel.invokeMethod<String>('updatePolicies', {
            'blockedPackages': blockedPackages,
            'automaticBlockedPackages': automaticPackages,
            'backgroundBlockedPackages': backgroundPackages,
          }) ??
          'UPDATED';
    } on MissingPluginException {
      return 'UNSUPPORTED';
    } on PlatformException catch (error) {
      return 'ERROR: ${error.message ?? error.code}';
    }
  }

  static Future<String> updateAutomaticBlocks(List<String> packages) async {
    try {
      return await _vpnChannel.invokeMethod<String>('updateAutomaticBlocks',
              {'automaticBlockedPackages': packages}) ??
          'UPDATED';
    } on MissingPluginException {
      return 'UNSUPPORTED';
    } on PlatformException catch (error) {
      return 'ERROR: ${error.message ?? error.code}';
    }
  }

  static Future<String> stopVpn() async {
    try {
      return await _vpnChannel.invokeMethod<String>('stopVpn') ?? 'STOPPED';
    } on MissingPluginException {
      return 'UNSUPPORTED';
    } on PlatformException catch (error) {
      return 'ERROR: ${error.message ?? error.code}';
    }
  }

  static Future<String> blockAppPackage(String packageName) async {
    try {
      return await _vpnChannel
              .invokeMethod<String>('blockApp', {'packageName': packageName}) ??
          'UPDATED';
    } on MissingPluginException {
      return 'UNSUPPORTED';
    } on PlatformException catch (error) {
      return 'ERROR: ${error.message ?? error.code}';
    }
  }

  static Map<String, dynamic> _normalizeMap(Map<dynamic, dynamic>? raw) {
    final map = <String, dynamic>{};
    raw?.forEach((key, value) => map[key.toString()] = value);
    return map;
  }

  static Uint8List? iconBytes(dynamic value) {
    if (value is Uint8List) return value;
    if (value is List<int>) return Uint8List.fromList(value);
    return null;
  }
}
