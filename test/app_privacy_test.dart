import 'package:docket/features/settings/domain/app_privacy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('privacy policy has versioned sections for About and hosting', () {
    expect(AppPrivacy.lastUpdated, isNotEmpty);
    expect(AppPrivacy.summary.toLowerCase(), contains('local'));
    expect(AppPrivacy.sections, isNotEmpty);
    expect(
      AppPrivacy.sections.map((s) => s.$1),
      containsAll([
        'Encryption',
        'App lock & biometrics',
        'Backup & sharing',
        'Deleting your data',
      ]),
    );
  });
}
