#!/usr/bin/env sh
set -eu

BASE=${GATEWAY_URL:-http://localhost:3000}
KC=${KEYCLOAK_URL:-http://localhost:8080}
PASSED=0
FAILED=0
BODY_FILE=$(mktemp)
HEADER_FILE=$(mktemp)
trap 'rm -f "$BODY_FILE" "$HEADER_FILE"' EXIT

need() { command -v "$1" >/dev/null 2>&1 || { echo "Need $1"; exit 1; }; }
need curl
need python3

get_json() {
  curl -fsS -X POST "$KC/realms/$1/protocol/openid-connect/token" \
    -H 'Content-Type: application/x-www-form-urlencoded' \
    --data-urlencode 'grant_type=password' \
    --data-urlencode "client_id=$2" \
    --data-urlencode "username=$3" \
    --data-urlencode "password=$4"
}

field() { python3 -c "import json,sys; print(json.load(sys.stdin)['$1'])"; }

case_call() {
  expected=$1
  name=$2
  shift 2
  : > "$BODY_FILE"
  : > "$HEADER_FILE"
  status=$(curl -sS -D "$HEADER_FILE" -o "$BODY_FILE" -w '%{http_code}' "$@" || printf '000')

  printf '\n============================================================\n'
  printf '%s | expected=%s\n' "$name" "$expected"
  printf '============================================================\n'
  sed -n '1,12p' "$HEADER_FILE"
  cat "$BODY_FILE"
  printf '\n'

  if [ "$status" = "$expected" ]; then
    PASSED=$((PASSED + 1))
    printf 'PASS | actual=%s\n' "$status"
  else
    FAILED=$((FAILED + 1))
    printf 'FAIL | expected=%s actual=%s\n' "$expected" "$status"
  fi
}

echo 'Preflight: checking all dependencies through API Gateway...'
case_call 200 'PRE01 - Gateway + Finance API + PostgreSQL healthy' "$BASE/health"

echo 'Getting demo tokens from Keycloak...'
ALICE_JSON=$(get_json finance-lab lab-client alice 'Alice@123')
BOB_JSON=$(get_json finance-lab lab-client bob 'Bob@123')
WA_JSON=$(get_json finance-lab wrong-audience-client alice 'Alice@123')
WI_JSON=$(get_json other-lab other-client eve 'Eve@123')
ALICE=$(printf '%s' "$ALICE_JSON" | field access_token)
REFRESH=$(printf '%s' "$ALICE_JSON" | field refresh_token)
BOB=$(printf '%s' "$BOB_JSON" | field access_token)
WA=$(printf '%s' "$WA_JSON" | field access_token)
WI=$(printf '%s' "$WI_JSON" | field access_token)

case_call 401 'TC01 - No token' "$BASE/api/finance/accounts"
case_call 200 'TC02 - Valid Alice token + finance.read' -H "Authorization: Bearer $ALICE" "$BASE/api/finance/accounts"
case_call 403 'TC03 - Valid Bob token but missing role' -H "Authorization: Bearer $BOB" "$BASE/api/finance/accounts"
case_call 401 'TC04 - Wrong audience' -H "Authorization: Bearer $WA" "$BASE/api/finance/accounts"
case_call 401 'TC05 - Token from another issuer/realm' -H "Authorization: Bearer $WI" "$BASE/api/finance/accounts"
case_call 401 'TC06 - Malformed JWT' -H 'Authorization: Bearer abc.def.ghi' "$BASE/api/finance/accounts"
case_call 401 'TC07 - Missing Bearer scheme' -H "Authorization: $ALICE" "$BASE/api/finance/accounts"
case_call 401 'TC08 - Refresh token used as access token' -H "Authorization: Bearer $REFRESH" "$BASE/api/finance/accounts"
case_call 200 'TC09 - Valid token on profile' -H "Authorization: Bearer $ALICE" "$BASE/api/profile"

echo 'TC10: waiting 36 seconds for the 30-second access token to expire...'
sleep 36
case_call 401 'TC10 - Expired access token' -H "Authorization: Bearer $ALICE" "$BASE/api/finance/accounts"

printf '\n============================================================\n'
printf 'RESULT: PASS=%s FAIL=%s\n' "$PASSED" "$FAILED"
printf '============================================================\n'

[ "$FAILED" -eq 0 ]
