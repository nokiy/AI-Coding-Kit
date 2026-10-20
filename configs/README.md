# configs/

Config presets / 配置预设。Identifier names are judged by each language's own linter in CI;
these presets carry the naming half of [`protocols/file-gate.md`](../protocols/file-gate.md).

| File | What it enforces | Adopt |
|------|------------------|-------|
| `swiftlint-naming.yml` | `identifier_name` ≥ 3 chars (except id i j k x y w h); `let`/`var`/`func` named data, tmp, temp, obj, info, result, res, ret, val, foo, bar, item, list, str, arr, dict (+ digits) is an error; `file_length` 400, `line_length` 200, `file_name` | Copy to the project root as `.swiftlint.yml` (or point `parent_config:` at it); the project's lint command runs `swiftlint lint --strict` |
| `eslint-naming.json` | `id-length` ≥ 3 (same exceptions); `id-denylist` with the same words | Flat config: `import naming from "./eslint-naming.json" with { type: "json" }` and spread it into a config object (`{ files: [...], ...naming }`); legacy `.eslintrc`: add it to `extends` |

All rules are errors. ESLint's `id-denylist` matches whole names only, so `data2` passes there while SwiftLint's regex catches it.
