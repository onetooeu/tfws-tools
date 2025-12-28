# TFWS Tools (onetooeu/tfws-tools)

Non-authoritative, offline-first tools for adopting  
**Trust-First Web Standard (TFWS v2)** on your own domain.

This repository provides a minimal but complete **local toolchain**
for publishing, validating, and checking TFWS trust signals —
without asking any central authority for permission.

---

## What this repository provides

- **Generator**  
  Creates copy/paste-ready `/.well-known` files and optional
  `tfws-adoption.json` manifests.

- **Validator**  
  Permissive validator for TFWS-related JSON documents  
  (no scoring, no certification, no enforcement).

- **Checker**  
  Checks a live domain for TFWS endpoints, fetches artifacts,
  and produces machine- and human-readable reports.

All tools are **non-authoritative** and **offline-first**.

---

## Core principles

- **Non-authoritative**  
  These tools do **not** certify, approve, rank, or score trust.

- **Self-declared adoption**  
  Trust signals are published by domain owners themselves.

- **Offline-first**  
  No backend services, no accounts, no telemetry.

- **Reproducible**  
  Deterministic outputs where possible.

- **Portable**  
  Works with static hosting (Cloudflare Pages, GitHub Pages,
  Netlify, nginx, etc.).

---

## What this is not

- ❌ Not a certification authority  
- ❌ Not a central registry  
- ❌ Not a trust score or reputation system  
- ❌ Not a runtime service  
- ❌ No tracking, analytics, or telemetry  

---

## Repository structure

packages/
generator/ – .well-known + adoption manifest generator
validator/ – permissive TFWS JSON validator
checker/ – domain checker + report generator
shared/ – shared helpers (internal)
schemas/ – non-authoritative schema mirrors
docs/ – policy and explanatory documentation
examples/ – example inputs and outputs
scripts/ – entry-point helper (run.sh)

yaml
Kopírovať kód

---

## Quick start

All tools are executed via a single helper script.

### 1️⃣ Check a domain

Checks TFWS endpoints on a live domain and produces a report.

```bash
./scripts/run.sh check example.com
Outputs:

report/example.com/report.json

report/example.com/report.md

2️⃣ Generate .well-known files
Interactively generate TFWS-compatible files for your domain:

bash
Kopírovať kód
./scripts/run.sh gen
Output directory:

pgsql
Kopírovať kód
out/<domain>/.well-known/
Copy the generated files to your website.

3️⃣ Validate a JSON file
Validate a TFWS-related JSON document locally:

bash
Kopírovať kód
./scripts/run.sh validate path/to/file.json
The validator is permissive and aligned with real TFWS v2
documents such as:

ai-trust-hub.json

key-history.json

tfws-adoption.json

Example: onetoo.eu
The onetoo.eu domain publishes:

/.well-known/ai-trust-hub.json

/.well-known/key-history.json

/.well-known/llms.txt

/.well-known/minisign.pub

/.well-known/tfws-adoption.json

All of them validate successfully using this repository.

Relationship to other TFWS projects
TFWS specification
https://github.com/onetooeu/trust-first-web-standard-ver-2

TFWS Adoption Kit
https://github.com/onetooeu/tfws-adoption-kit

This repository focuses only on tools.
Specification and adoption guidance live elsewhere.

Security notes
Never publish private keys

Validation does not imply trust

Consumers must always verify signatures independently

License
CC0 / Public Domain.

This work is dedicated to the public domain.
