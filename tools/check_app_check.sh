#!/usr/bin/env bash
# Tells you whether this build's App Check debug token is registered for one of
# the project's apps. Sign-in fails with "Firebase App Check token is invalid"
# when it is not, because Auth and Firestore are behind App Check.
#
#   tools/check_app_check.sh android | web | ios
#
# It calls the same exchangeDebugToken endpoint the app calls at startup; an
# "App attestation failed" answer means the token needs adding for that app in
# Firebase console -> App Check -> Apps -> <app> -> Manage debug tokens.
set -euo pipefail

APP="${1:-android}"
# The token is a credential, so it is never written into this script: provide
# it in the environment or in the gitignored file at the repository root.
TOKEN_FILE="$(cd "$(dirname "$0")/../.." && pwd)/.app_check_debug_token"
TOKEN="${APP_CHECK_DEBUG_TOKEN:-}"
if [[ -z "$TOKEN" && -f "$TOKEN_FILE" ]]; then
  TOKEN="$(tr -d '[:space:]' < "$TOKEN_FILE")"
fi
if [[ -z "$TOKEN" ]]; then
  echo "Set APP_CHECK_DEBUG_TOKEN or write .app_check_debug_token in the" >&2
  echo "repository root, then run this again." >&2
  exit 2
fi
OPTIONS="$(cd "$(dirname "$0")/.." && pwd)/lib/firebase_options.dart"

case "$APP" in
  android|web|ios) ;;
  *) echo "usage: $0 android|web|ios" >&2; exit 2 ;;
esac

# Reads one field from the options block for this app in lib/firebase_options.dart.
field() {
  awk -v app="$APP" -v field="$1" '
    $0 ~ "static const FirebaseOptions " app " =" { inblock = 1; next }
    inblock && /^  \);/ { inblock = 0 }
    inblock && $1 == field ":" { gsub(/[\x27,]/, "", $2); print $2; exit }
  ' "$OPTIONS"
}
app="$(field appId)"
key="$(field apiKey)"
PROJECT="$(field messagingSenderId)"
if [[ -z "$app" || -z "$key" || -z "$PROJECT" ]]; then
  echo "Could not read the $APP options from $OPTIONS" >&2
  exit 2
fi

url="https://firebaseappcheck.googleapis.com/v1/projects/$PROJECT/apps/$app:exchangeDebugToken?key=$key"
body=$(printf '{"debugToken":"%s"}' "$TOKEN")

if curl -s -X POST "$url" -H 'Content-Type: application/json' -d "$body" | grep -q '"token"'; then
  echo "$APP: the configured debug token is registered — App Check will pass."
else
  echo "$APP: the configured debug token is NOT registered for this app." >&2
  echo "Add it in Firebase console -> App Check -> Apps -> the $APP app ->" >&2
  echo "  Manage debug tokens -> Add, then rebuild/reinstall." >&2
  exit 1
fi
