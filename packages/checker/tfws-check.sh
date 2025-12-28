#!/usr/bin/env bash
set -euo pipefail

DOMAIN="${1:-}"
if [[ -z "$DOMAIN" ]]; then
  echo "Usage: $0 example.com"
  exit 2
fi

BASE="https://${DOMAIN}"
OUTDIR="report/${DOMAIN}"
FETCHDIR="${OUTDIR}/fetched"
mkdir -p "${FETCHDIR}"

timestamp_utc="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

declare -a PATHS=(
  "/.well-known/minisign.pub"
  "/.well-known/llms.txt"
  "/.well-known/ai-trust-hub.json"
  "/.well-known/key-history.json"
  "/.well-known/tfws-adoption.json"
)

check_url () {
  local url="$1"
  local headers
  headers="$(curl -sS -L -D - -o /dev/null --max-time 20 "$url" || true)"

  local status
  status="$(printf "%s" "$headers" | awk 'toupper($0) ~ /^HTTP\/[0-9.]+/ {code=$2} END{print code+0}' )"
  [[ -z "$status" ]] && status="0"

  local safe
  safe="$(echo "$url" | sed 's#https\?://##' | sed 's#[/:]#_#g')"
  printf "%s" "$headers" > "${FETCHDIR}/${safe}.headers.txt"

  echo "$status"
}

run_validator () {
  local file="$1"
  python packages/validator/tfws-validate.py "$file" 2>&1
}

results_json="${OUTDIR}/report.json"
results_md="${OUTDIR}/report.md"

{
  echo "{"
  echo "  \"domain\": \"${DOMAIN}\","
  echo "  \"checked_at_utc\": \"${timestamp_utc}\","
  echo "  \"base_url\": \"${BASE}\","
  echo "  \"checks\": ["
  first=1

  for p in "${PATHS[@]}"; do
    url="${BASE}${p}"
    status="$(check_url "$url")"

    fetched=""
    validation=""
    validation_ok=""

    if [[ "$status" == "200" ]]; then
      target="${FETCHDIR}${p}"
      mkdir -p "$(dirname "$target")"
      if curl -sS -L --max-time 25 "$url" | head -c 1048576 > "$target"; then
        fetched="fetched${p}"

        if [[ "$p" == *".json" ]]; then
          validation="$(run_validator "$target" || true)"
          if echo "$validation" | grep -q '^OK:'; then
            validation_ok="true"
          elif echo "$validation" | grep -q '^ERROR:'; then
            validation_ok="false"
          else
            validation_ok=""
          fi
        fi
      fi
    fi

    [[ $first -eq 1 ]] || echo "    ,"
    first=0

    echo "    {"
    echo "      \"path\": \"${p}\","
    echo "      \"url\": \"${url}\","
    echo "      \"http_status\": ${status},"
    echo "      \"fetched_file\": \"${fetched}\","
    echo "      \"validation_ok\": \"${validation_ok}\","
    echo "      \"validation_output\": $(python -c "import json,sys; print(json.dumps(sys.stdin.read()))" <<< "$validation")"
    echo -n "    }"
  done

  echo
  echo "  ]"
  echo "}"
} > "$results_json"

{
  echo "# TFWS Checker Report"
  echo
  echo "- Domain: \`${DOMAIN}\`"
  echo "- Checked at (UTC): \`${timestamp_utc}\`"
  echo
  echo "## Endpoints"
  echo
  echo "| Path | Status | Validated |"
  echo "|---|---:|---|"

  for p in "${PATHS[@]}"; do
    url="${BASE}${p}"
    status="$(check_url "$url")"

    validated="(n/a)"
    if [[ "$p" == *".json" && "$status" == "200" ]]; then
      target="${FETCHDIR}${p}"
      if [[ -f "$target" ]]; then
        out="$(run_validator "$target" || true)"
        if echo "$out" | grep -q '^OK:'; then
          validated="OK"
        elif echo "$out" | grep -q '^ERROR:'; then
          validated="ERROR"
        else
          validated="WARN"
        fi
      fi
    fi

    echo "| \`${p}\` | \`${status}\` | \`${validated}\` |"
  done

  echo
  echo "## Notes"
  echo
  echo "- This tool is **non-authoritative**: it does not certify or score trust."
  echo "- It reports availability + basic validation only."
} > "$results_md"

echo "OK: wrote ${results_json}"
echo "OK: wrote ${results_md}"
