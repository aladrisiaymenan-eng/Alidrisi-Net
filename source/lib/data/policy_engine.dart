import 'models/app_models.dart';

/// Applies the local limit decision to a snapshot of real device usage.
/// The native monitor performs the same decision against NetworkStats by UID;
/// this helper keeps the Flutter presentation state deterministic and testable.
List<ManagedApp> applyLocalLimitPolicies(
  Iterable<ManagedApp> apps, {
  required bool limitRuleEnabled,
}) {
  return apps.map((app) {
    final exceeded = limitRuleEnabled &&
        app.isRuleEnabled &&
        app.limitBytes > 0 &&
        app.usageBytes >= app.limitBytes;
    if (exceeded) {
      return app.copyWith(accessMode: AccessMode.blocked, autoBlocked: true);
    }
    if (app.autoBlocked) {
      return app.copyWith(accessMode: AccessMode.allowed, autoBlocked: false);
    }
    return app;
  }).toList();
}
