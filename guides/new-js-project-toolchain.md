# New JS project toolchain / 新项目默认工具链

The single source for a new JS/TS project's toolchain: Bun installs, Oxlint lints, `bun check` type-checks, Vitest tests.
Skills and docs link here; they never copy the steps or the versions.

新 JS/TS 项目的默认工具链唯一出处：Bun 装依赖、Oxlint 做 lint、`bun check` 做类型检查、Vitest 跑测试。技能与文档只链接这里。

## Starter config

[`configs/js-default/`](../configs/js-default):

| File | Copy to | What it is |
|------|---------|------------|
| `oxlintrc.json` | `.oxlintrc.json` | Oxlint with the react / nextjs / import / jsx-a11y / typescript plugins; the rules `eslint-config-next` turned on, nothing project-specific |
| `package-snippet.json` | merged into `package.json` | `packageManager`, the `lint` / `typecheck` / `test` scripts, and the pinned `bun` / `oxlint` / `vitest` dev dependencies. The versions live only here |
| `smoke.test.ts` | `tests/smoke.test.ts` | One test, because `vitest run` exits 1 when it finds no test file; replace it once real tests exist |

## Convert a fresh scaffold

The workspace default scaffold is `create-next-app --example with-supabase --use-bun`. From an empty parent directory:

```bash
npx -y create-next-app@latest my-app --example with-supabase --use-bun
cd my-app
KIT=<path to an AI-Coding-Kit checkout>

# 1. Remove ESLint: its config files here, its packages in step 3
find . -maxdepth 1 \( -name 'eslint.config.*' -o -name '.eslintrc*' \) -delete

# 2. Copy the starter files
cp "$KIT/configs/js-default/oxlintrc.json" .oxlintrc.json
mkdir -p tests && cp "$KIT/configs/js-default/smoke.test.ts" tests/smoke.test.ts

# 3. Merge the snippet into package.json and drop every eslint package
node -e '
const fs = require("fs");
const pkg = JSON.parse(fs.readFileSync("package.json", "utf8"));
const starter = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
for (const deps of [pkg.dependencies, pkg.devDependencies])
  for (const name of Object.keys(deps ?? {})) if (name.includes("eslint")) delete deps[name];
pkg.packageManager = starter.packageManager;
pkg.scripts = { ...pkg.scripts, ...starter.scripts };
pkg.devDependencies = { ...pkg.devDependencies, ...starter.devDependencies };
fs.writeFileSync("package.json", JSON.stringify(pkg, null, 2) + "\n");
' "$KIT/configs/js-default/package-snippet.json"

# 4. Reinstall with the pinned Bun (the scaffold's bun.lock came from whatever bun is global)
npx -y "$(node -p "require('./package.json').packageManager")" install

# 5. All four checks exit 0
npm run lint && npm run typecheck && npm run build && npm run test
```

Done when: no `eslint.config.*` / `.eslintrc*`, no `eslint` in `package.json`, no `package-lock.json`, only `bun.lock`.
Use `npm run <script>`, never `npm install` / `npm ci`: npm would write a `package-lock.json`.

CI: in the project's stub of [`quality.yml`](../.github/workflows/quality.yml) set `bun: true` (the gate installs the `packageManager` Bun and runs `bun install --frozen-lockfile`) and `lint: npm run lint && npm run typecheck`.

## Upgrade rule / 升级规则

- **Oxlint** is pinned exactly (no `^`): its JS plugins are alpha and a minor release can change behaviour. Upgrade it alone, in its own commit, with lint and typecheck green.
- **Bun** has two pins that move together in one commit: `packageManager` (`bun@<version>`, the version CI and Railpack install) and the `bun` dev dependency (the one `npm run typecheck` runs). Reinstall so `bun.lock` follows.
- The starter tracks the pilot project's pins; when the pilot upgrades, `package-snippet.json` follows in its own commit.

## Pitfalls

- A script named `check` makes `bun check` run that script instead of type-checking: keep the script name `typecheck`.
- An older global `bun` may not read a newer `bun.lock`: install through `npx -y "$(node -p "require('./package.json').packageManager")"` (or `node_modules/.bin/bun`), not the global one.
- Oxlint does not parse JSX in `.ts` files; JSX belongs in `.tsx`.
- Component tests (`.tsx`) need `jsdom` and `@vitejs/plugin-react` in a `vitest.config.ts`; the starter ships none because the smoke test needs none.
