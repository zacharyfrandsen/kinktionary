#!/usr/bin/env bash
# Builds the Android phone test APK and installs it on the connected device.
#
# One step: a release arm64 build with the App Check debug token baked in,
# signed with the local debug key so it can update an existing sideloaded
# install without erasing local notes, saves and path progress.
#
#   tools/install_phone.sh
#
# The token comes from APP_CHECK_DEBUG_TOKEN or the gitignored
# .app_check_debug_token in the repository root. It must be registered for the
# Android app; tools/check_app_check.sh android verifies that. Set
# ANDROID_SERIAL when more than one device is attached.
#
# Play releases are unaffected: they still use android/key.properties.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR/.."
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# A debug token is a credential, so it comes from the environment or the
# gitignored file, never from this script.
TOKEN="${APP_CHECK_DEBUG_TOKEN:-}"
if [[ -z "$TOKEN" && -f "$ROOT/.app_check_debug_token" ]]; then
  TOKEN="$(tr -d '[:space:]' < "$ROOT/.app_check_debug_token")"
fi
if [[ -z "$TOKEN" ]]; then
  echo "No App Check debug token: set APP_CHECK_DEBUG_TOKEN or write" >&2
  echo ".app_check_debug_token in the repository root." >&2
  exit 1
fi

FLUTTER="$(command -v flutter || true)"
if [[ -z "$FLUTTER" ]]; then
  FLUTTER_SDK="$(sed -n 's/^flutter\.sdk=//p' android/local.properties 2>/dev/null || true)"
  if [[ -n "$FLUTTER_SDK" && -x "$FLUTTER_SDK/bin/flutter" ]]; then
    FLUTTER="$FLUTTER_SDK/bin/flutter"
  fi
fi
if [[ -z "$FLUTTER" ]]; then
  echo "flutter was not found; add it to PATH or set flutter.sdk in" >&2
  echo "android/local.properties." >&2
  exit 1
fi

# Gradle needs a JDK. A Flutter provisioned by the project tooling keeps one
# next to the SDK.
if [[ -z "${JAVA_HOME:-}" ]] && ! command -v java >/dev/null 2>&1; then
  FLUTTER_ROOT="$(cd "$(dirname "$FLUTTER")/.." && pwd)"
  for candidate in "$FLUTTER_ROOT/../jdk"* /usr/lib/jvm/*; do
    if [[ -x "$candidate/bin/java" ]]; then
      export JAVA_HOME="$candidate"
      break
    fi
  done
fi
if [[ -z "${JAVA_HOME:-}" ]] && ! command -v java >/dev/null 2>&1; then
  echo "No Java runtime found; install a JDK or set JAVA_HOME." >&2
  exit 1
fi

ADB="$(command -v adb || true)"
if [[ -z "$ADB" ]]; then
  SDK_DIR="$(sed -n 's/^sdk\.dir=//p' android/local.properties 2>/dev/null || true)"
  for candidate in "${ANDROID_HOME:-}" "${ANDROID_SDK_ROOT:-}" "$SDK_DIR"; do
    if [[ -n "$candidate" && -x "$candidate/platform-tools/adb" ]]; then
      ADB="$candidate/platform-tools/adb"
      break
    fi
  done
fi
if [[ -z "$ADB" ]]; then
  echo "adb was not found; add it to PATH or set ANDROID_HOME." >&2
  exit 1
fi

SERIAL="${ANDROID_SERIAL:-}"
if [[ -z "$SERIAL" ]]; then
  mapfile -t attached < <("$ADB" devices | awk 'NR > 1 && $2 == "device" { print $1 }')
  case "${#attached[@]}" in
    1)
      SERIAL="${attached[0]}"
      ;;
    0)
      echo "No phone is attached. Connect it over USB, or over Wi-Fi with" >&2
      echo "'adb connect <host:port>' (ports are listed by 'adb mdns services')." >&2
      exit 1
      ;;
    *)
      echo "Several devices are attached; set ANDROID_SERIAL to one of:" >&2
      printf '  %s\n' "${attached[@]}" >&2
      exit 1
      ;;
  esac
fi

# A warning rather than a stop: an offline build is still useful, but sign-in
# will fail on the phone until the token is registered.
if ! check_output="$(APP_CHECK_DEBUG_TOKEN="$TOKEN" "$SCRIPT_DIR/check_app_check.sh" android 2>&1)"; then
  printf '%s\n' "$check_output" >&2
  echo "Building anyway; sign-in will fail on this build until that is fixed." >&2
fi

echo "Building the Android test APK..."
ORG_GRADLE_PROJECT_phoneTestSigning=true "$FLUTTER" build apk --release \
  --target-platform android-arm64 \
  --dart-define=APP_CHECK_DEBUG=true \
  --dart-define=APP_CHECK_DEBUG_TOKEN="$TOKEN"

APK="build/app/outputs/flutter-apk/app-release.apk"
echo "Installing on $SERIAL..."
if ! install_output="$("$ADB" -s "$SERIAL" install -r "$APK" 2>&1)"; then
  printf '%s\n' "$install_output" >&2
  case "$install_output" in
    *INSTALL_FAILED_UPDATE_INCOMPATIBLE*)
      echo "The installed app was signed with a different key, so it cannot be" >&2
      echo "updated in place. Uninstall it (that deletes its local notes," >&2
      echo "saves and progress) and run this again." >&2
      ;;
  esac
  exit 1
fi
printf '%s\n' "$install_output" | tail -n 1
echo "Installed on $SERIAL."
