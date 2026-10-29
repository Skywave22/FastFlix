import 'package:flutter_test/flutter_test.dart';
import 'package:flixquest/video_providers/language_priority.dart';

void main() {
  test('recognizes Hindi words and language codes, not unrelated text', () {
    expect(LanguagePriority.isHindi('Hindi Dubbed'), isTrue);
    expect(LanguagePriority.isHindi('hi-IN'), isTrue);
    expect(LanguagePriority.isHindi('audio: hin'), isTrue);
    expect(LanguagePriority.isHindi('हिन्दी'), isTrue);
    expect(LanguagePriority.isHindi('hindi'), isTrue);
    expect(LanguagePriority.isHindi('1080p English'), isFalse);
    expect(LanguagePriority.isHindi('something'), isFalse);
    expect(LanguagePriority.isHindi(null), isFalse);
  });

  test('Hindi preference is stable and can be disabled', () {
    final sources = [
      ('English', 1),
      ('Hindi', 2),
      ('Japanese', 3),
      ('hi-IN', 4),
    ];
    expect(
      LanguagePriority.hindiFirst(
        sources,
        (source) => LanguagePriority.isHindi(source.$1),
      ),
      [
        ('Hindi', 2),
        ('hi-IN', 4),
        ('English', 1),
        ('Japanese', 3),
      ],
    );
    expect(sources.first.$1, 'English');
  });
}
