import 'package:flutter_test/flutter_test.dart';
import 'package:internet_manager/data/usage_join.dart';

void main() {
  test('indexes NetworkStats rows by UID and resolves installed app UID', () {
    final index = indexUsageByUid([
      {'uid': 10001, 'totalBytes': 900, 'wifiBytes': 600, 'mobileBytes': 300},
      {'uid': '10002', 'totalBytes': 42, 'wifiBytes': 42, 'mobileBytes': 0},
    ]);

    expect(usageForUid(index, 10001)['totalBytes'], 900);
    expect(usageForUid(index, '10002')['wifiBytes'], 42);
    expect(usageForUid(index, 99999), isEmpty);
  });
}
