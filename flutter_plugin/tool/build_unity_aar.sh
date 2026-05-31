#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXPORT_ROOT="$ROOT_DIR/.cytoid_game_core/exports/android/unityLibrary"
EXAMPLE_ANDROID="$ROOT_DIR/example/android"
ARTIFACT_DIR="$ROOT_DIR/.cytoid_game_core/artifacts/unity/android"
AAR_OUT="$EXPORT_ROOT/unityLibrary/build/outputs/aar/unityLibrary-release.aar"

resolve_flutter_gradle_wrapper() {
  local flutter_bin flutter_root local_properties wrapper_root

  resolve_wrapper_from_root() {
    local candidate_root="$1"

    if [[ -z "$candidate_root" ]]; then
      return 1
    fi

    wrapper_root="$candidate_root/bin/cache/artifacts/gradle_wrapper"
    if [[ -x "$wrapper_root/gradlew" && -f "$wrapper_root/gradle/wrapper/gradle-wrapper.jar" ]]; then
      echo "$wrapper_root"
      return 0
    fi

    return 1
  }

  resolve_wrapper_from_root "${FLUTTER_ROOT:-}" && return 0
  resolve_wrapper_from_root "${FLUTTER_HOME:-}" && return 0

  flutter_bin="$(command -v flutter || true)"
  if [[ -n "$flutter_bin" ]]; then
    flutter_root="$(cd "$(dirname "$flutter_bin")/.." && pwd)"
    resolve_wrapper_from_root "$flutter_root" && return 0
  fi

  for local_properties in "$ROOT_DIR/example/android/local.properties" "$EXPORT_ROOT/local.properties"; do
    if [[ -f "$local_properties" ]]; then
      flutter_root="$(sed -n 's/^flutter\.sdk=//p' "$local_properties" | tail -n 1)"
      resolve_wrapper_from_root "$flutter_root" && return 0
    fi
  done

  for flutter_root in \
    "$HOME/.flutter-sdk/main/flutter" \
    "$HOME/flutter" \
    "$HOME/development/flutter" \
    "$HOME/Developer/flutter" \
    "/opt/homebrew/Caskroom/flutter/latest/flutter" \
    "/Applications/flutter"; do
    resolve_wrapper_from_root "$flutter_root" && return 0
  done

  if [[ -x "$EXAMPLE_ANDROID/gradlew" && -f "$EXAMPLE_ANDROID/gradle/wrapper/gradle-wrapper.jar" ]]; then
    echo "$EXAMPLE_ANDROID"
    return 0
  fi

  return 1
}

configure_java_home() {
  local android_player_dir candidate java_home local_properties sdk_dir

  if [[ -n "${JAVA_HOME:-}" && -x "$JAVA_HOME/bin/java" ]]; then
    return 0
  fi

  for local_properties in "$EXPORT_ROOT/local.properties" "$ROOT_DIR/example/android/local.properties"; do
    if [[ -f "$local_properties" ]]; then
      sdk_dir="$(sed -n 's/^sdk\.dir=//p' "$local_properties" | tail -n 1)"
      if [[ -n "$sdk_dir" ]]; then
        android_player_dir="${sdk_dir%/SDK}"
        java_home="$android_player_dir/OpenJDK"
        if [[ -x "$java_home/bin/java" ]]; then
          export JAVA_HOME="$java_home"
          export PATH="$JAVA_HOME/bin:${PATH:-}"
          return 0
        fi
      fi
    fi
  done

  for candidate in /Applications/Unity/Hub/Editor/*/PlaybackEngines/AndroidPlayer/OpenJDK; do
    if [[ -x "$candidate/bin/java" ]]; then
      export JAVA_HOME="$candidate"
      export PATH="$JAVA_HOME/bin:${PATH:-}"
      return 0
    fi
  done

  return 0
}

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
  WRAPPER_ROOT="$(resolve_flutter_gradle_wrapper)" || {
    echo "Gradle wrapper missing." >&2
    echo "Install or initialize Flutter so bin/cache/artifacts/gradle_wrapper exists, then rerun this script." >&2
    exit 1
  }

  cp "$WRAPPER_ROOT/gradlew" "$EXPORT_ROOT/"
  cp "$WRAPPER_ROOT/gradlew.bat" "$EXPORT_ROOT/" 2>/dev/null || true
  mkdir -p "$EXPORT_ROOT/gradle/wrapper"
  cp "$WRAPPER_ROOT/gradle/wrapper/gradle-wrapper.jar" "$EXPORT_ROOT/gradle/wrapper/"
  cat >"$EXPORT_ROOT/gradle/wrapper/gradle-wrapper.properties" <<'EOF'
distributionBase=GRADLE_USER_HOME
distributionPath=wrapper/dists
zipStoreBase=GRADLE_USER_HOME
zipStorePath=wrapper/dists
distributionUrl=https\://services.gradle.org/distributions/gradle-8.13-bin.zip
EOF
  chmod +x "$EXPORT_ROOT/gradlew"
fi

configure_java_home

export GRADLE_USER_HOME="${GRADLE_USER_HOME:-$ROOT_DIR/.cytoid_game_core/build/gradle}"
mkdir -p "$GRADLE_USER_HOME"

(cd "$EXPORT_ROOT" && ./gradlew :unityLibrary:assembleRelease --no-daemon)

mkdir -p "$ARTIFACT_DIR"
cp "$AAR_OUT" "$ARTIFACT_DIR/cytoid-unity-core.aar"
cp "$EXPORT_ROOT/unityLibrary/libs/"*.aar "$ARTIFACT_DIR/"
echo "Installed cytoid-unity-core.aar to $ARTIFACT_DIR"
