#!/usr/bin/env bash
# Builds the public site into build/site:
#   build/site/index.html   the hand-written landing page (source: landing/)
#   build/site/app/         the Flutter app, same code as Android and iOS
#
# Serve it with:  python3 -m http.server 8137 --directory build/site
set -euo pipefail
cd "$(dirname "$0")/.."

# Firebase App Check is enforced on this project's Auth and Firestore, so a web
# build without an App Check token is rejected ("Firebase App Check token is
# invalid"). Until a reCAPTCHA v3 site key is registered for the web app, the
# build uses the web app's registered *debug* token.
#
# This is a development token. Before the site is public, register reCAPTCHA v3
# (Firebase console → App Check → the web app) and build with:
#   APP_CHECK_RECAPTCHA_SITE_KEY=... ./tools/build_site.sh --recaptcha
# then delete the debug token in the console.
# The token is a credential, so this script never carries one: it comes from
# the environment or the gitignored file in the repository root. Anyone can
# extract it from a built bundle, so a public deployment belongs on reCAPTCHA.
TOKEN_FILE="$(cd "$(dirname "$0")/../.." && pwd)/.app_check_debug_token"
DEBUG_TOKEN="${APP_CHECK_DEBUG_TOKEN:-}"
if [[ -z "$DEBUG_TOKEN" && -f "$TOKEN_FILE" ]]; then
  DEBUG_TOKEN="$(tr -d '[:space:]' < "$TOKEN_FILE")"
fi

if [[ "${1:-}" == "--recaptcha" ]]; then
  : "${APP_CHECK_RECAPTCHA_SITE_KEY:?set APP_CHECK_RECAPTCHA_SITE_KEY to the reCAPTCHA v3 site key}"
  APP_CHECK_ARGS=(--dart-define=APP_CHECK_RECAPTCHA_SITE_KEY="$APP_CHECK_RECAPTCHA_SITE_KEY")
else
  if [[ -z "$DEBUG_TOKEN" ]]; then
    echo "No App Check debug token: set APP_CHECK_DEBUG_TOKEN or write" >&2
    echo ".app_check_debug_token in the repository root, or build a public" >&2
    echo "bundle with --recaptcha and APP_CHECK_RECAPTCHA_SITE_KEY." >&2
    exit 1
  fi
  APP_CHECK_ARGS=(
    --dart-define=APP_CHECK_DEBUG=true
    --dart-define=APP_CHECK_DEBUG_TOKEN="$DEBUG_TOKEN"
  )
fi

# No service worker: this is a development preview that is rebuilt often, and a
# cached worker keeps serving the previous build to a browser that already has
# it open, which looks like changes that never arrived.
flutter build web --release --base-href /app/ --pwa-strategy=none "${APP_CHECK_ARGS[@]}"

rm -rf build/site
mkdir -p build/site
cp -R landing/. build/site/
cp -R build/web build/site/app
echo "Built build/site — landing page at /, app at /app/"
