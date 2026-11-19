import 'dart:io';

import 'package:agritrace_mobile/services/local_notification_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

/// v1.12.2 — reminders fired on a Pixel but never appeared. The small icon
/// was the full-colour adaptive launcher icon; Android needs a monochrome
/// status-bar drawable. These guards keep the icon in place and protect it
/// from R8 resource shrinking (the plugin resolves it by name at runtime,
/// so the shrinker cannot see the reference).
void main() {
  const resDir = 'android/app/src/main/res';

  test('reminder notifications do not use the launcher icon', () {
    expect(kReminderSmallIcon, isNot(contains('ic_launcher')));
  });

  test('the small icon exists as a monochrome vector drawable', () {
    final file = File('$resDir/drawable/$kReminderSmallIcon.xml');

    expect(file.existsSync(), isTrue);
    final xml = file.readAsStringSync();
    expect(xml, contains('<vector'));
    expect(xml, contains('#FFFFFFFF'));
  });

  test('keep.xml protects the small icon from resource shrinking', () {
    final keep = File('$resDir/raw/keep.xml');

    expect(keep.existsSync(), isTrue);
    expect(
      keep.readAsStringSync(),
      contains('@drawable/$kReminderSmallIcon'),
    );
  });
}
