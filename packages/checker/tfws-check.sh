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
  local headers
  headers="$(curl -sS -D - -o /dev/null -L --max-time 20 "$url" || true)"

  local status
  status="$(printf "%s" "$headers" | awk 'toupper($0) ~ /^HTTP\/[0-9.]+/ {print $2; exit}' )"
  [[ -z "$status" ]] && status="0"

  local ctype
  ctype="$(printf "%s" "$headers" | awk -F': ' 'tolower($1)=="content-type"{print $2; exit}' | tr -d '\r')"
  [[ -z "$ctype" ]] && ctype=""

  local safe
  safe="$(echo "$url" | sed 's#https\?://##' | sed 's#[/:]#_#g')"
  printf "%s" "$headers" > "${FETCHDIR}/${safe}.headers.txt"

  echo "$status|$ctype"
}

json_escape () {
  python - <<'PY' "$1"
import json,sys
print(json.dumps(sys.argv[1]))
PY
}

run_validator () {
  local file="$1"
  if command -v python >/dev/null 2>&1; then
    python packages/validator/tfws-validate.py "$file" 2>&1
  else
    echo "ERROR: python not found; cannot validate"
    return 1
  fi
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

    fetched=""
    validation=""
    validation_ok=""

    if [[ "$status" == "200" ]]; then
      # Save body (cap at 1MB)
      target="${FETCHDIR}${p}"
      mkdir -p "$(dirname "$target")"
      if curl -sS -L --max-time 25 "$url" | head -c 1048576 > "$target"; then
        fetched="fetched${p}"

        # Validate JSON files we care about
        if [[ "$p" == *".json" ]]; then
          # capture validator output; do not fail whole run
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
    echo "      \"content_type\": $(json_escape "$ctype"),"
    echo "      \"fetched_file\": $(json_escape "$fetched"),"
    echo "      \"validation_ok\": $(json_escape "$validation_ok"),"
    echo "      \"validation_output\": $(json_escape "$validation")"
    echo -n "    }"
  done

  echo
  echo "  ]"
  echo "}"
} > "$results_json"

# Build Markdown summary
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
    res="$(check_url "$url")"
    status="${res%%|*}"

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
