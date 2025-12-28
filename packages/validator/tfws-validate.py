#!/usr/bin/env python3
import json
import sys
from pathlib import Path
from typing import Any, Dict, List, Tuple

def fail(msg: str) -> None:
    print(f"ERROR: {msg}")
    sys.exit(1)

def warn(msg: str) -> None:
    print(f"WARNING: {msg}")

def ok(msg: str) -> None:
    print(f"OK: {msg}")

def load_json(path: Path) -> Dict[str, Any]:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        fail(f"File not found: {path}")
    except json.JSONDecodeError as e:
        fail(f"Invalid JSON: {path} ({e})")

def is_obj(x: Any) -> bool:
    return isinstance(x, dict)

def is_list(x: Any) -> bool:
    return isinstance(x, list)

def detect_kind(doc: Dict[str, Any], filename: str) -> str:
    name = filename.lower()
    if "tfws-adoption" in name or "adoption" in doc:
        return "tfws-adoption"
    if "key-history" in name or "keys" in doc or "history" in doc:
        return "key-history"
    # permissive: ai-trust-hub has many possible shapes, but typically contains one of these
    if "ai-trust-hub" in name or any(k in doc for k in ("signals", "endpoints", "resources", "hub", "links")):
        return "ai-trust-hub"
    return "unknown"

def require_fields(doc: Dict[str, Any], fields: List[str], kind: str, fixes: List[str]) -> List[str]:
    missing = [f for f in fields if f not in doc]
    if missing:
        for f in missing:
            print(f"ERROR: Missing required field: '{f}'")
        # UX: suggest fixes
        for fx in fixes:
            warn(f"[suggestion] {kind}: {fx}")
        sys.exit(1)
    return []

def validate_ai_trust_hub(doc: Dict[str, Any]) -> None:
    # TFWS v2 is intentionally flexible. We only require "some payload anchor".
    anchors = ("signals", "endpoints", "resources", "hub", "links")
    if not any(k in doc for k in anchors):
        warn("ai-trust-hub: expected at least one of fields: signals/endpoints/resources/hub/links (permissive)")

    # Optional: basic type sanity for common fields if present
    for k in ("contact", "notes", "repo", "public_key", "generated_by", "timestamp"):
        if k in doc and not isinstance(doc[k], (str, int, float, bool, type(None), dict, list)):
            fail(f"ai-trust-hub: field '{k}' has unexpected type")

    ok("Valid (permissive) ai-trust-hub")

def validate_key_history(doc: Dict[str, Any]) -> None:
    # Accept either keys[] or history[]
    if "keys" in doc:
        if not is_list(doc["keys"]):
            fail("key-history: 'keys' must be a list")
        ok("Valid key-history (keys list)")
        return
    if "history" in doc:
        if not is_list(doc["history"]):
            fail("key-history: 'history' must be a list")
        ok("Valid key-history (history list)")
        return

    # Nothing found -> warning only (permissive), but also UX suggestion
    warn("key-history: expected 'keys' or 'history' list (permissive)")
    warn("[suggestion] key-history: add either 'keys': [] or 'history': [] at the top level")

    ok("Valid (permissive) key-history")

def validate_tfws_adoption(doc: Dict[str, Any]) -> None:
    # Adoption manifest v1 (simple, explicit)
    fixes = [
        "Add 'version': '1.0' (recommended)",
        "Add 'domain': '<your-domain>' (recommended)",
        "Add 'adoption': { 'self_declared': true, 'no_central_authority': true }",
        "Add 'contact': 'security@your-domain' (recommended)"
    ]

    # Require adoption object
    if "adoption" not in doc or not is_obj(doc.get("adoption")):
        print("ERROR: Missing required field: 'adoption' (object)")
        for fx in fixes:
            warn(f"[suggestion] tfws-adoption: {fx}")
        sys.exit(1)

    a = doc["adoption"]
    if "self_declared" not in a or not isinstance(a.get("self_declared"), bool):
        print("ERROR: adoption.self_declared must be boolean")
        warn("[suggestion] tfws-adoption: set adoption.self_declared to true/false")
        sys.exit(1)

    if "no_central_authority" not in a or not isinstance(a.get("no_central_authority"), bool):
        print("ERROR: adoption.no_central_authority must be boolean")
        warn("[suggestion] tfws-adoption: set adoption.no_central_authority to true/false")
        sys.exit(1)

    # Soft recommendations (warn only)
    if "version" not in doc:
        warn("tfws-adoption: missing 'version' (recommended)")
        warn("[suggestion] tfws-adoption: add top-level 'version': '1.0'")
    if "domain" not in doc:
        warn("tfws-adoption: missing 'domain' (recommended)")
        warn("[suggestion] tfws-adoption: add top-level 'domain': '<your-domain>'")
    if "contact" not in doc:
        warn("tfws-adoption: missing 'contact' (recommended)")
        warn("[suggestion] tfws-adoption: add top-level 'contact': 'security@your-domain'")

    ok("Valid tfws-adoption")

def main() -> None:
    if len(sys.argv) < 2:
        print("Usage: tfws-validate.py <file.json>")
        sys.exit(2)

    path = Path(sys.argv[1]).resolve()
    doc = load_json(path)

    if not is_obj(doc):
        fail("Top-level JSON must be an object")

    kind = detect_kind(doc, path.name)

    if kind == "ai-trust-hub":
        validate_ai_trust_hub(doc)
    elif kind == "key-history":
        validate_key_history(doc)
    elif kind == "tfws-adoption":
        validate_tfws_adoption(doc)
    else:
        warn("Unknown doc type; only basic JSON checks applied")
        ok("Basic validation passed")

if __name__ == "__main__":
    main()
