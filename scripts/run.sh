#!/usr/bin/env bash
set -euo pipefail

CMD="${1:-}"
shift || true

case "$CMD" in
  check)
    DOMAIN="${1:-}"
    [[ -n "$DOMAIN" ]] || { echo "Usage: ./scripts/run.sh check example.com"; exit 2; }
    ./packages/checker/tfws-check.sh "$DOMAIN"
    ;;
  gen)
    ./packages/generator/tfws-gen.sh
    ;;
  validate)
    FILE="${1:-}"
    [[ -n "$FILE" ]] || { echo "Usage: ./scripts/run.sh validate path/to/file.json"; exit 2; }
    python ./packages/validator/tfws-validate.py "$FILE"
    ;;
  *)
    echo "Usage:"
    echo "  ./scripts/run.sh check example.com"
    echo "  ./scripts/run.sh gen"
    echo "  ./scripts/run.sh validate path/to/file.json"
    exit 2
    ;;
esac
