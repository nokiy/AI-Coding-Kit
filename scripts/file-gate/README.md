# scripts/file-gate/

Whole-file gate for commits and PRs: 400 lines, 200 characters per line, no generic file names.
Spec: [`protocols/file-gate.md`](../../protocols/file-gate.md).

| File | Role |
|------|------|
| `file-gate.sh` | The gate. `--staged` for a pre-commit hook, `--base <ref>` for CI. Exit 0 pass · 1 violations · 2 internal error |
| `test.sh` | Self-test: builds temp git repos and asserts every rule, skip and mode. Run by `.github/workflows/self-test.yml` |

Pre-commit hook (in a project that vendors or clones the kit):

```sh
#!/bin/sh
exec path/to/AI-Coding-Kit/scripts/file-gate/file-gate.sh --staged
```
