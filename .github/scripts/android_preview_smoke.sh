#!/usr/bin/env bash
set -euo pipefail

# Runs only against the disposable preview APK on a clean Android emulator.
# Disable networking to avoid contacting configured services or creating
# accounts during a startup-only check; no user data is installed.
package='io.github.skywave22.fastflix'
activity="$package/dev.beamlak.flixquest_v2.FastFlixPlayIcon"
artifact_dir="${RUNNER_TEMP:-/tmp}/fastflix-smoke"
mkdir -p "$artifact_dir"
adb shell cmd connectivity airplane-mode enable >/dev/null 2>&1 || true
adb shell svc wifi disable >/dev/null 2>&1 || true
adb shell svc data disable >/dev/null 2>&1 || true
adb install -r "$1"
# A first-launch notification prompt is a system window, not an app failure.
# Grant it in this disposable emulator so we can inspect the Flutter content
# without incorrectly treating the dialog overlay as successful startup.
adb shell pm grant "$package" android.permission.POST_NOTIFICATIONS || true
adb logcat -c
adb shell am start -W -n "$activity"

# Allow startup, including an offline account/bootstrap timeout, to settle.
# A successful Flutter semantics tree is more meaningful than just an Android
# activity existing behind an indefinitely held native splash screen.
ready=0
for attempt in $(seq 1 24); do
  adb shell uiautomator dump /sdcard/fastflix-window.xml >/dev/null 2>&1 || true
  adb pull /sdcard/fastflix-window.xml "$artifact_dir/window.xml" >/dev/null 2>&1 || true
  if [[ -s "$artifact_dir/window.xml" ]] && python3 -c '
import sys, xml.etree.ElementTree as ET
try:
    root = ET.parse(sys.argv[1]).getroot()
    ready = any(node.get("package") == sys.argv[2] and
                (node.get("text", "").strip() or node.get("content-desc", "").strip())
                for node in root.iter())
except (OSError, ET.ParseError):
    ready = False
sys.exit(0 if ready else 1)
' "$artifact_dir/window.xml" "$package"; then
    ready=1
    break
  fi
  sleep 5
done
adb shell screencap -p /sdcard/fastflix-screen.png || true
adb pull /sdcard/fastflix-screen.png "$artifact_dir/screen.png" >/dev/null 2>&1 || true
adb logcat -d -s AndroidRuntime:E flutter:E > "$artifact_dir/errors.log" || true
if ! adb shell pidof "$package" >/dev/null; then
  echo '::error::Preview process is not running after startup.'
  tail -100 "$artifact_dir/errors.log"
  exit 1
fi
if grep -q 'FATAL EXCEPTION' "$artifact_dir/errors.log"; then
  echo '::error::Android reported a fatal startup exception.'
  tail -100 "$artifact_dir/errors.log"
  exit 1
fi
if (( ready == 0 )); then
  echo '::error::No accessible app content appeared after startup.'
  tail -100 "$artifact_dir/errors.log"
  exit 1
fi
echo '::notice::Preview installed and reached accessible Android app content.'
