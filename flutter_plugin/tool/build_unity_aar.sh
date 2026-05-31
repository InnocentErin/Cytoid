#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXPORT_ROOT="$ROOT_DIR/.cytoid_game_core/exports/android/unityLibrary"
EXAMPLE_ANDROID="$ROOT_DIR/example/android"
ARTIFACT_DIR="$ROOT_DIR/.cytoid_game_core/artifacts/unity/android"
AAR_OUT="$EXPORT_ROOT/unityLibrary/build/outputs/aar/unityLibrary-release.aar"

if [[ ! -d "$EXPORT_ROOT/unityLibrary" ]]; then
  echo "Unity export missing at $EXPORT_ROOT" >&2
  echo "Run: Unity -batchmode -quit -projectPath <repo> -executeMethod CytoidCoreBuild.ExportAndroidLibraryForFlutter" >&2
  exit 1
fi

STRINGS_XML="$EXPORT_ROOT/unityLibrary/src/main/res/values/strings.xml"
if [[ -f "$STRINGS_XML" ]] && ! grep -q 'name="app_name"' "$STRINGS_XML"; then
  echo "Injecting missing app_name into $STRINGS_XML"
  python3 - "$STRINGS_XML" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
if 'name="app_name"' in text:
    raise SystemExit(0)
insert = '  <string name="app_name">Cytoid</string>\n'
if "<resources>" in text:
    text = text.replace("<resources>\n", "<resources>\n" + insert, 1)
else:
    text = '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n' + insert + '</resources>\n'
path.write_text(text, encoding="utf-8")
PY
fi

if [[ ! -x "$EXPORT_ROOT/gradlew" ]]; then
  cp "$EXAMPLE_ANDROID/gradlew" "$EXPORT_ROOT/"
  cp "$EXAMPLE_ANDROID/gradlew.bat" "$EXPORT_ROOT/" 2>/dev/null || true
  mkdir -p "$EXPORT_ROOT/gradle/wrapper"
  cp "$EXAMPLE_ANDROID/gradle/wrapper/gradle-wrapper.jar" "$EXPORT_ROOT/gradle/wrapper/"
  cat >"$EXPORT_ROOT/gradle/wrapper/gradle-wrapper.properties" <<'EOF'
distributionBase=GRADLE_USER_HOME
distributionPath=wrapper/dists
zipStoreBase=GRADLE_USER_HOME
zipStorePath=wrapper/dists
distributionUrl=https\://services.gradle.org/distributions/gradle-8.13-bin.zip
EOF
  chmod +x "$EXPORT_ROOT/gradlew"
fi

(cd "$EXPORT_ROOT" && ./gradlew :unityLibrary:assembleRelease --no-daemon)

mkdir -p "$ARTIFACT_DIR"
cp "$AAR_OUT" "$ARTIFACT_DIR/cytoid-unity-core.aar"
cp "$EXPORT_ROOT/unityLibrary/libs/"*.aar "$ARTIFACT_DIR/"
echo "Installed cytoid-unity-core.aar to $ARTIFACT_DIR"