#!/usr/bin/env bash
set -euo pipefail

DOMAIN="${1:-}"
if [[ -z "$DOMAIN" ]]; then
  echo "Usage: $0 example.com"
  exit 2
fi

BASE="https://${DOMAIN}"
OUTDIR="report/${DOMAIN}"
mkdir -p "${OUTDIR}/fetched"

timestamp_utc="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

# Endpoints we check (no scoring; only availability + basic HTTP info)
declare -a PATHS=(
  "/.well-known/minisign.pub"
  "/.well-known/llms.txt"
  "/.well-known/ai-trust-hub.json"
  "/.well-known/key-history.json"
  "/.well-known/tfws-adoption.json"
)

check_url () {
  local url="$1"
  # Fetch headers; don't fail the whole run on a single missing file
  local headers
  headers="$(curl -sS -D - -o /dev/null -L --max-time 15 "$url" || true)"

  # Extract status code from first HTTP line that appears
  local status
  status="$(printf "%s" "$headers" | awk 'toupper($0) ~ /^HTTP\/[0-9.]+/ {print $2; exit}' )"
  [[ -z "$status" ]] && status="0"

  # Extract content-type if any
  local ctype
  ctype="$(printf "%s" "$headers" | awk -F': ' 'tolower($1)=="content-type"{print $2; exit}' | tr -d '\r')"
  [[ -z "$ctype" ]] && ctype=""

  # Save headers for debugging
  local safe
  safe="$(echo "$url" | sed 's#https\?://##' | sed 's#[/:]#_#g')"
  printf "%s" "$headers" > "${OUTDIR}/fetched/${safe}.headers.txt"

  echo "$status|$ctype"
}

json_escape () {
  python - <<'PY' "$1"
import json,sys
print(json.dumps(sys.argv[1]))
PY
}

results_json="${OUTDIR}/report.json"
results_md="${OUTDIR}/report.md"

# Build JSON report
{
  echo "{"
  echo "  \"domain\": \"${DOMAIN}\","
  echo "  \"checked_at_utc\": \"${timestamp_utc}\","
  echo "  \"base_url\": \"${BASE}\","
  echo "  \"checks\": ["
  first=1
  for p in "${PATHS[@]}"; do
    url="${BASE}${p}"
    res="$(check_url "$url")"
    status="${res%%|*}"
    ctype="${res#*|}"

    # Attempt to fetch body for 200 responses (small only)
    fetched=""
    if [[ "$status" == "200" ]]; then
      # Keep max 1MB for safety
      if curl -sS -L --max-time 20 "$url" | head -c 1048576 > "${OUTDIR}/fetched$(echo "$p")"; then
        fetched="fetched${p}"
      fi
    fi

    [[ $first -eq 1 ]] || echo "    ,"
    first=0

    echo "    {"
    echo "      \"path\": \"${p}\","
    echo "      \"url\": \"${url}\","
    echo "      \"http_status\": ${status},"
    echo "      \"content_type\": $(json_escape "$ctype"),"
    echo "      \"fetched_file\": $(json_escape "$fetched")"
    echo -n "    }"
  done
  echo
  echo "  ]"
  echo "}"
} > "$results_json"

# Build a simple Markdown summary
{
  echo "# TFWS Checker Report"
  echo
  echo "- Domain: \`${DOMAIN}\`"
  echo "- Checked at (UTC): \`${timestamp_utc}\`"
  echo
  echo "## Endpoints"
  echo
  echo "| Path | Status | Content-Type |"
  echo "|---|---:|---|"
  for p in "${PATHS[@]}"; do
    url="${BASE}${p}"
    res="$(check_url "$url")"
    status="${res%%|*}"
    ctype="${res#*|}"
    echo "| \`${p}\` | \`${status}\` | \`${ctype}\` |"
  done
  echo
  echo "## Notes"
  echo
  echo "- This tool is **non-authoritative**: it does not certify or score trust."
  echo "- It reports availability and basic HTTP metadata only."
} > "$results_md"

echo "OK: wrote ${results_json}"
echo "OK: wrote ${results_md}"
