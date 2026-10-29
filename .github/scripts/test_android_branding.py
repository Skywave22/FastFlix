"""Keep Android package, default launcher, and optional logo aliases aligned."""
from pathlib import Path
import re
import unittest
import xml.etree.ElementTree as ET

from prepare_firebase_android import PACKAGE

ROOT = Path(__file__).resolve().parents[2]
ANDROID = '{http://schemas.android.com/apk/res/android}'


class AndroidBrandingTest(unittest.TestCase):
    def test_original_package_and_single_default_launcher(self):
        self.assertEqual(PACKAGE, 'dev.beamlak.flixquest_v2')
        gradle = (ROOT / 'android/app/build.gradle').read_text()
        self.assertRegex(gradle, rf'applicationId\s+"{re.escape(PACKAGE)}"')
        self.assertIn('appLabel: "FlixQuest"', gradle)
        manifest = ET.parse(ROOT / 'android/app/src/main/AndroidManifest.xml').getroot()
        aliases = manifest.find('application').findall('activity-alias')
        launchers = [a for a in aliases if any(
            c.get(ANDROID + 'name') == 'android.intent.category.LAUNCHER'
            for c in a.findall('intent-filter/category')
        )]
        names = {a.get(ANDROID + 'name'): a for a in launchers}
        self.assertEqual(set(names), {
            '.FlixQuestOriginalIcon', '.FastFlixPlayIcon',
            '.FastFlixWingIcon', '.FastFlixFIcon',
        })
        self.assertEqual(
            [name for name, alias in names.items() if alias.get(ANDROID + 'enabled') != 'false'],
            ['.FlixQuestOriginalIcon'],
        )
        self.assertEqual(names['.FlixQuestOriginalIcon'].get(ANDROID + 'icon'), '@mipmap/ic_launcher')
        bridge = (ROOT / 'android/app/src/main/kotlin/dev/beamlak/flixquest_v2/LauncherIconBridge.kt').read_text()
        for alias in names:
            self.assertIn(PACKAGE + alias, bridge)
        smoke = (ROOT / '.github/scripts/android_preview_smoke.sh').read_text()
        self.assertIn("package='" + PACKAGE + "'", smoke)
        self.assertIn(PACKAGE + '.FlixQuestOriginalIcon', smoke)

    def test_restored_widget_dimensions_are_resolved(self):
        res = ROOT / 'android/app/src/main/res'
        dimensions = {
            node.get('name')
            for path in res.glob('values*/dimens.xml')
            for node in ET.parse(path).getroot().findall('dimen')
        }
        widget = (ROOT / 'android/app/src/main/kotlin/dev/beamlak/flixquest_v2/widgets/FlixQuestWidgetProviders.kt').read_text()
        self.assertTrue(set(re.findall(r'R\.dimen\.(\w+)', widget)) <= dimensions)

    def test_all_optional_launcher_artwork_has_resources(self):
        res = ROOT / 'android/app/src/main/res'
        for choice in ('play', 'wing', 'f'):
            self.assertTrue((res / f'mipmap-anydpi-v26/ic_fastflix_{choice}.xml').exists())
            for density in ('mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi'):
                self.assertTrue((res / f'mipmap-{density}/ic_fastflix_{choice}.webp').exists())
                self.assertTrue((res / f'mipmap-{density}/ic_fastflix_{choice}_foreground.webp').exists())
        for banner in ('tv_banner.png', 'tv_banner_play.png', 'tv_banner_wing.png', 'tv_banner_f.png'):
            self.assertTrue((res / 'drawable-xhdpi' / banner).exists())


if __name__ == '__main__':
    unittest.main()
