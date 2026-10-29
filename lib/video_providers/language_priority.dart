/// Best-effort language hint matching. Provider/server labels are not a
/// guarantee of the spoken audio; only explicit Hindi names/codes count.
abstract final class LanguagePriority {
  static final RegExp _hindi = RegExp(
    r'(?:^|[^a-z0-9])(?:hindi|hin|hi)(?:$|[^a-z0-9])|हिंदी|हिन्दी',
    caseSensitive: false,
  );

  static bool isHindi(String? value) => value != null && _hindi.hasMatch(value);

  /// Stable partition: preserves the user's order within both groups.
  static List<T> hindiFirst<T>(Iterable<T> items, bool Function(T) isHindi) {
    final preferred = <T>[];
    final other = <T>[];
    for (final item in items) {
      (isHindi(item) ? preferred : other).add(item);
    }
    return [...preferred, ...other];
  }
}
