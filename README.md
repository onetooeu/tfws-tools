# TFWS Tools (onetooeu/tfws-tools)

Non-authoritative, offline-first tools for adopting **Trust-First Web Standard (TFWS v2)**.

This repository provides:
- **Generator** – creates copy/paste-ready `.well-known` templates and optional manifests
- **Validator** – validates JSON files against schemas (no scoring, no certification)
- **Checker** – checks a domain for TFWS endpoints, integrity, and basic correctness

## Principles

- **Non-authoritative**: tools do not certify, approve, or rank trust
- **Offline-first**: runs locally; no backend required
- **Reproducible**: deterministic outputs where possible
- **Portable**: usable across hosting providers and static sites

## What this is not

- Not a certification authority
- Not a central registry
- Not a trust score service
- No telemetry, no tracking

## Repository structure

- `packages/generator/` – manifest + template generator
- `packages/validator/` – JSON/schema validator
- `packages/checker/` – domain checker and report generator
- `packages/shared/` – shared utilities
- `schemas/` – schemas used by tools (non-authoritative mirrors)
- `docs/` – policy and documentation
- `examples/` – sample inputs/outputs
- `scripts/` – helper scripts

## Quick start (placeholder)

This repo is intentionally scaffolded first.
Implementation will follow in incremental releases.

## License

CC0 / Public Domain.
