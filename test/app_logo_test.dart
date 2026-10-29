import 'package:flixquest/models/fastflix_logo.dart';
import 'package:flixquest/provider/app_dependency_provider.dart';
import 'package:flixquest/provider/settings_provider.dart';
import 'package:flixquest/widgets/app_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

class _PlayLogoSettings extends SettingsProvider {
  @override
  FastFlixLogo get fastFlixLogo => FastFlixLogo.play;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => dotenv.testLoad(
      fileInput: 'TMDB_API_KEY=test\nMIXPANEL_API_KEY=test\nFLIXQUEST_API_URL=https://example.test\n'));

  testWidgets('original FlixQuest is the default bundled logo', (tester) async {
    final dependencies = AppDependencyProvider();
    addTearDown(dependencies.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: dependencies,
        child: const MaterialApp(home: AppLogo()),
      ),
    );
    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as AssetImage).assetName, 'assets/images/logo.png');
  });

  testWidgets('optional wordmark stays readable on a light background',
      (tester) async {
    final settings = _PlayLogoSettings();
    addTearDown(settings.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: settings,
        child: const MaterialApp(
          home: ColoredBox(
            color: Colors.white,
            child: Center(child: SizedBox.square(dimension: 120, child: AppLogo())),
          ),
        ),
      ),
    );
    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as AssetImage).assetName,
        'assets/images/fastflix/logo_play.png');
    expect(AppLogo.artworkPlate.computeLuminance(), lessThan(0.1));
    expect(image.semanticLabel, 'FlixQuest');
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
