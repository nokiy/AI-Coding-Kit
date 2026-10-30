# scripts/secret-scan/

gitleaks over exactly a PR's commits, logs redacted — the CI twin of the local commit-secrets hook.

| File | Role |
|------|------|
| `secret-scan.sh` | `secret-scan.sh <base-sha> <head-sha>`: installs gitleaks 8.30.1 from the official release (checksum-verified), scans `<base>..<head>` with `--redact`, `./.gitleaks.toml` when present. Exit 0 clean · 1 leaks or gitleaks error · 2 internal error. Run by the `secrets` job of `.github/workflows/quality.yml` |
| `test.sh` | Self-test: temp git repos with a runtime-built fake AWS key; asserts red, redaction, range bounds and errors. Run by `.github/workflows/self-test.yml` |
