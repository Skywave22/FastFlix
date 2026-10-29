import 'package:flixquest/widgets/app_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('bundled default wordmark is readable on the dark artwork plate',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: ColoredBox(color: AppLogo.artworkPlate, child: AppLogo()),
    ));
    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as AssetImage).assetName,
        'assets/images/fastflix/logo_play.png');
    expect(AppLogo.artworkPlate.computeLuminance(), lessThan(0.1));
    expect(image.semanticLabel, 'FastFlix');
  });

  test('accepts only well-formed SVG logo documents', () {
    expect(
      isValidRemoteLogoSvg(
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10">'
        '<path d="M0 0h10v10H0z"/>'
        '</svg>',
      ),
      isTrue,
    );
    expect(isValidRemoteLogoSvg('<html>Not an SVG</html>'), isFalse);
    expect(isValidRemoteLogoSvg('< invalid xml'), isFalse);
    expect(isValidRemoteLogoSvg('{"error":"not found"}'), isFalse);
    expect(isValidRemoteLogoSvg(''), isFalse);
  });
}
