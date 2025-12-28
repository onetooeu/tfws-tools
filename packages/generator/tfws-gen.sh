#!/usr/bin/env bash
set -euo pipefail

prompt () {
  local var="$1"
  local text="$2"
  local default="${3:-}"
  local val
  if [[ -n "$default" ]]; then
    read -r -p "${text} [${default}]: " val
    val="${val:-$default}"
  else
    read -r -p "${text}: " val
  fi
  printf -v "$var" "%s" "$val"
}

DOMAIN=""
EMAIL=""
REPO_URL=""
PUBKEY_URL=""
INCLUDE_ADOPTION=""

echo "TFWS Generator (non-authoritative)"
echo "Creates copy-ready .well-known files for your domain."
echo

prompt DOMAIN "Domain (e.g. example.com)"
prompt EMAIL "Contact email (e.g. security@example.com)"
prompt REPO_URL "Optional repo URL" ""
prompt PUBKEY_URL "Public key URL (minisign.pub) (optional)" ""
prompt INCLUDE_ADOPTION "Include tfws-adoption.json? (y/n)" "y"

OUTDIR="out/${DOMAIN}/.well-known"
mkdir -p "$OUTDIR"

# llms.txt (minimal, neutral)
cat > "${OUTDIR}/llms.txt" <<EOT
# llms.txt (TFWS-friendly)
# Domain: ${DOMAIN}
# Contact: ${EMAIL}

User-agent: *
Allow: /
EOT

# ai-trust-hub.json (template-like)
# Note: values are self-declared; tool does not certify anything.
cat > "${OUTDIR}/ai-trust-hub.json" <<EOT
{
  "version": "1.0",
  "domain": "${DOMAIN}",
  "contact": "${EMAIL}",
  "notes": "Self-declared TFWS signals. No central authority.",
  "public_key": ${PUBKEY_URL:+\"${PUBKEY_URL}\"}${PUBKEY_URL:+"",}
  "repo": ${REPO_URL:+\"${REPO_URL}\"}${REPO_URL:+"",}
  "generated_by": "tfws-tools generator (non-authoritative)"
}
EOT

# key-history.json (empty starter)
cat > "${OUTDIR}/key-history.json" <<EOT
{
  "version": "1.0",
  "domain": "${DOMAIN}",
  "keys": [],
  "notes": "Key history is optional. Keep immutable entries once published."
}
EOT

# tfws-adoption.json (optional)
if [[ "${INCLUDE_ADOPTION,,}" == "y" || "${INCLUDE_ADOPTION,,}" == "yes" ]]; then
  cat > "${OUTDIR}/tfws-adoption.json" <<EOT
{
  "version": "1.0",
  "domain": "${DOMAIN}",
  "adoption": {
    "self_declared": true,
    "no_central_authority": true
  },
  "contact": "${EMAIL}",
  "repo": ${REPO_URL:+\"${REPO_URL}\"}${REPO_URL:+"",}
  "generated_by": "tfws-tools generator (non-authoritative)"
}
EOT
fi

echo
echo "OK: generated files in: ${OUTDIR}"
echo "Next: copy these files to your site at: /.well-known/"
