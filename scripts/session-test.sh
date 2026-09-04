#!/usr/bin/env sh
set -eu

KC=${KEYCLOAK_URL:-http://localhost:8080}
TOKEN_ENDPOINT="$KC/realms/finance-lab/protocol/openid-connect/token"
LOGOUT_ENDPOINT="$KC/realms/finance-lab/protocol/openid-connect/logout"
PASSED=0
FAILED=0
BODY_FILE=$(mktemp)
trap 'rm -f "$BODY_FILE"' EXIT

need() { command -v "$1" >/dev/null 2>&1 || { echo "Need $1"; exit 1; }; }
need curl
need python3

form_request() {
  uri=$1
  shift
  : > "$BODY_FILE"
  curl_args=""
  FORM_STATUS=$(curl -sS -o "$BODY_FILE" -w '%{http_code}' -X POST "$uri" "$@")
  FORM_BODY=$(cat "$BODY_FILE")
}

assert_case() {
  expected=$1
  name=$2
  printf '\n%s | expected=%s actual=%s\n' "$name" "$expected" "$FORM_STATUS"
  if [ "$FORM_STATUS" = 200 ]; then
    echo '{"token_response":"received","tokens":"redacted"}'
  elif [ -n "$FORM_BODY" ]; then
    printf '%s\n' "$FORM_BODY"
  fi
  if [ "$FORM_STATUS" = "$expected" ]; then
    PASSED=$((PASSED + 1))
    echo 'PASS'
  else
    FAILED=$((FAILED + 1))
    echo 'FAIL'
  fi
}

new_alice_session() {
  form_request "$TOKEN_ENDPOINT" \
    --data-urlencode 'grant_type=password' \
    --data-urlencode 'client_id=lab-client' \
    --data-urlencode 'username=alice' \
    --data-urlencode 'password=Alice@123'
  [ "$FORM_STATUS" = 200 ] || { echo "Cannot create Alice session: $FORM_BODY"; exit 1; }
}

echo 'Demo refresh-token rotation...'
new_alice_session
OLD_REFRESH=$(printf '%s' "$FORM_BODY" | python3 -c "import json,sys; print(json.load(sys.stdin)['refresh_token'])")

form_request "$TOKEN_ENDPOINT" \
  --data-urlencode 'grant_type=refresh_token' \
  --data-urlencode 'client_id=lab-client' \
  --data-urlencode "refresh_token=$OLD_REFRESH"
assert_case 200 'SR01 - Refresh token issues a new token'

form_request "$TOKEN_ENDPOINT" \
  --data-urlencode 'grant_type=refresh_token' \
  --data-urlencode 'client_id=lab-client' \
  --data-urlencode "refresh_token=$OLD_REFRESH"
assert_case 400 'SR02 - Old refresh token cannot be reused'

echo 'Demo session revocation using OIDC logout...'
new_alice_session
LOGOUT_REFRESH=$(printf '%s' "$FORM_BODY" | python3 -c "import json,sys; print(json.load(sys.stdin)['refresh_token'])")

form_request "$LOGOUT_ENDPOINT" \
  --data-urlencode 'client_id=lab-client' \
  --data-urlencode "refresh_token=$LOGOUT_REFRESH"
assert_case 204 'SR03 - Session is revoked'

form_request "$TOKEN_ENDPOINT" \
  --data-urlencode 'grant_type=refresh_token' \
  --data-urlencode 'client_id=lab-client' \
  --data-urlencode "refresh_token=$LOGOUT_REFRESH"
assert_case 400 'SR04 - Refresh token is rejected after logout'

printf '\nSESSION RESULT: PASS=%s FAIL=%s\n' "$PASSED" "$FAILED"
[ "$FAILED" -eq 0 ]
