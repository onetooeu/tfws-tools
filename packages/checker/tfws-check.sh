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

# Endpoints to check (non-authoritative)
declare -a PATHS=(
  "/.well-known/minisign.pub"
  "/.well-known/llms.txt"
  "/.well-known/ai-trust-hub.json"
  "/.well-known/key-history.json"
  "/.well-known/tfws-adoption.json"
)

# Where validator is (optional, but recommended)
VALIDATOR="packages/validator/tfws-validate.py"

# Helpers
has_cmd() { command -v "$1" >/dev/null 2>&1; }

fetch_headers() {
  local url="$1"
  local hdr="$2"
  curl -sSIL "$url" -o "$hdr" || true
}

fetch_body() {
  local url="$1"
  local out="$2"
  # fetch body (follow redirects), but fail softly
  curl -fsSL "$url" -o "$out" 2>/dev/null || true
}

http_status_from_headers() {
  # take the last HTTP status in case of redirects
  awk '/^HTTP\// {code=$2} END {print code+0}' "$1"
}

content_type_from_headers() {
  awk -F': ' 'tolower($1)=="content-type" {print $2}' "$1" | tail -n 1 | tr -d '\r'
}

json_escape() {
  python - <<'PY' "$1"
import json,sys
print(json.dumps(sys.argv[1]))
PY
}

validate_json() {
  local file="$1"
  if [[ -f "$VALIDATOR" ]] && has_cmd python; then
    python "$VALIDATOR" "$file" 2>&1 || return $?
  else
    echo "WARNING: validator not available (missing $VALIDATOR or python)"
    return 3
  fi
}

# Build checks
checks_json="[]"
checks_md_rows=""

# status -> validated -> OK/WARN/ERROR rules:
# - ERROR: http_status is 0 or >= 400 OR validation exits non-zero (hard error)
# - WARN : http_status is 3xx OR validator prints WARNING lines OR validator unavailable
# - OK   : http_status 200 and validator OK (no WARNING) for JSON docs; n/a for non-JSON
#
# Note: This is NOT trust scoring; it's only availability + format sanity.

mkdir -p "${FETCHDIR}/.well-known"

for p in "${PATHS[@]}"; do
  url="${BASE}${p}"
  safe_name="$(echo "${DOMAIN}${p}" | sed 's#https\?://##g; s#[^a-zA-Z0-9._-]#_#g')"

  hdr="${FETCHDIR}/${safe_name}.headers.txt"
  body="${FETCHDIR}${p}"

  # ensure parent dirs exist for body path
  mkdir -p "$(dirname "$body")"

  fetch_headers "$url" "$hdr"
  status="$(http_status_from_headers "$hdr")"
  ctype="$(content_type_from_headers "$hdr")"

  fetched_file=""
  if [[ "$status" -ge 200 && "$status" -lt 400 ]]; then
    fetch_body "$url" "$body"
    if [[ -s "$body" ]]; then
      fetched_file="$body"
    fi
  fi

  validation_ok="null"
  validation_output=""
  validated_md="(n/a)"
  final_grade="(n/a)"

  # Decide if JSON validation applies
  if [[ "$p" == *.json ]]; then
    if [[ -n "$fetched_file" && -s "$fetched_file" ]]; then
      vout="$(validate_json "$fetched_file" || true)"
      validation_output="$vout"

      # Determine OK/WARN/ERROR for validation
      if echo "$vout" | grep -q "^ERROR:"; then
        validation_ok="false"
        validated_md="ERROR"
      else
        validation_ok="true"
        if echo "$vout" | grep -q "^WARNING:"; then
          validated_md="WARN"
        else
          validated_md="OK"
        fi
      fi
    else
      validated_md="(n/a)"
      validation_ok="null"
      validation_output="ERROR: could not fetch body for JSON validation"
    fi
  fi

  # Determine final grade
  if [[ "$status" -eq 0 || "$status" -ge 400 ]]; then
    final_grade="ERROR"
  elif [[ "$status" -ge 300 && "$status" -lt 400 ]]; then
    final_grade="WARN"
  else
    # status 2xx
    if [[ "$p" == *.json ]]; then
      if [[ "$validated_md" == "ERROR" ]]; then
        final_grade="ERROR"
      elif [[ "$validated_md" == "WARN" ]]; then
        final_grade="WARN"
      elif [[ "$validated_md" == "OK" ]]; then
        final_grade="OK"
      else
        final_grade="WARN"
      fi
    else
      final_grade="OK"
    fi
  fi

  # Build JSON row (NO bash ${...} inside python; safe json.dumps)
  checks_json="$(python - <<PY
import json
checks = json.loads('''$checks_json''')
fetched_file = ${json.dumps(fetched_file)}
validation_output = ${json.dumps(validation_output)}
checks.append({
  "path": "$p",
  "url": "$url",
  "http_status": int($status),
  "content_type": "$ctype",
  "fetched_file": fetched_file if fetched_file else None,
  "validated": "$validated_md",
  "grade": "$final_grade",
  "validation_ok": $validation_ok,
  "validation_output": validation_output,
})
print(json.dumps(checks, ensure_ascii=False, indent=2))
PY
)"

  # Build MD row
  checks_md_rows+=$'| `'"$p"$'` | `'"$status"$'` | `'"$validated_md"$'` | **'"$final_grade"$'** |\n'
done

# Write report.json
cat > "${OUTDIR}/report.json" <<EOF
{
  "domain": $(json_escape "$DOMAIN"),
  "checked_at_utc": $(json_escape "$timestamp_utc"),
  "non_authoritative": true,
  "legend": {
    "OK": "Endpoint reachable and (if JSON) basic validation passed with no warnings.",
    "WARN": "Reachable but has redirects/format warnings/validator unavailable or minor issues.",
    "ERROR": "Missing/unreachable endpoint (>=400) or JSON validation failed (hard errors)."
  },
  "checks": $checks_json
}
EOF

# Write report.md
cat > "${OUTDIR}/report.md" <<EOF
# TFWS Checker Report

- Domain: \`$DOMAIN\`
- Checked at (UTC): \`$timestamp_utc\`

## Summary legend (non-authoritative)

This report does **not** certify trust. It only checks:
- availability (HTTP status)
- basic format sanity for JSON documents

**Grades:**
- **OK**   = endpoint reachable; JSON validates with no warnings
- **WARN** = reachable but redirects / warnings / validator unavailable / minor format issues
- **ERROR**= missing (>=400) or JSON validation failed (hard error)

## Endpoints

| Path | HTTP | Validated | Grade |
|---|---:|---|---|
$checks_md_rows

## Fix hints (common)

- **404 / ERROR**: publish the missing file under \`/.well-known/\`
- **301/302 / WARN**: prefer serving canonical content directly (or ensure redirects are intentional)
- **Validated = ERROR**: run the validator locally to see exact missing fields and suggested fixes:
  \`\`\`bash
  python packages/validator/tfws-validate.py report/$DOMAIN/fetched/.well-known/<file>.json
  \`\`\`
- **Validator unavailable / WARN**: ensure \`packages/validator/tfws-validate.py\` exists and Python is installed

## Notes

- This tool is **non-authoritative**: it does not certify or score trust.
- It reports availability + basic validation only.
EOF

echo "OK: wrote ${OUTDIR}/report.json"
echo "OK: wrote ${OUTDIR}/report.md"
