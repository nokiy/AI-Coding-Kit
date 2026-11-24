# New JS project toolchain / 新项目默认工具链

The single source for a new JS/TS project's toolchain: Bun installs, Oxlint lints, `bun check` type-checks, Vitest tests.
Skills and docs link here; they never copy the steps or the versions.

新 JS/TS 项目的默认工具链唯一出处：Bun 装依赖、Oxlint 做 lint、`bun check` 做类型检查、Vitest 跑测试。技能与文档只链接这里，不抄步骤和版本。

## Starter config / 起点配置

[`configs/js-default/`](../configs/js-default):

| File | Copy to | What it is |
|------|---------|------------|
| `oxlintrc.json` | `.oxlintrc.json` | Oxlint with the react / nextjs / import / jsx-a11y / typescript plugins: the rules `eslint-config-next` turned on, the naming rules of [`eslint-naming.json`](../configs/eslint-naming.json), and overrides only for files the default scaffold ships |
| `package-snippet.json` | merged into `package.json` | `packageManager`, the `lint` / `typecheck` / `test` scripts, and the `bun` / `oxlint` / `vitest` dev dependencies. The versions live only here |
| `smoke.test.ts` | `tests/smoke.test.ts` | One test, because `vitest run` exits 1 when it finds no test file; replace it once real tests exist |

`oxlintrc.json` 是 Oxlint 配置：`eslint-config-next` 打开的规则、`eslint-naming.json` 的命名规则，外加只针对默认脚手架自带文件的覆盖项；`package-snippet.json` 合并进 `package.json`，版本只写在这里；`smoke.test.ts` 是一条冒烟测试（`vitest run` 找不到测试文件会退出 1），有了真测试就替换它。

Naming rules: the last override switches them off for the files `create-next-app --example with-supabase` generates (short names like `e` and `cn`, Supabase's `data`). Every new file is checked; when you rewrite one of those files, drop it from the list.

命名规则：最后一个覆盖项对脚手架生成的文件关掉命名检查（`e`、`cn` 这类短名和 Supabase 的 `data`）。新文件都要过检查；改写了名单里的文件，就把它从名单删掉。

Another framework: the preset is written for Next.js + React. Without Next.js, drop the `nextjs` plugin and its `nextjs/*` rules; without React, also drop `react` / `jsx-a11y` and their rules.

换框架：预设按 Next.js + React 写。不用 Next.js 就删掉 `nextjs` 插件和 `nextjs/*` 规则；不用 React 再删 `react` / `jsx-a11y` 及其规则。

## Convert a fresh scaffold / 转换新脚手架

The workspace default scaffold is `create-next-app --example with-supabase --use-bun`. From an empty parent directory:

工作区默认脚手架是 `create-next-app --example with-supabase --use-bun`。在一个空的父目录里执行：

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

完成标准：没有 `eslint.config.*` / `.eslintrc*`，`package.json` 里没有 `eslint`，没有 `package-lock.json`，只有 `bun.lock`。脚本用 `npm run <script>` 跑，NEVER `npm install` / `npm ci`：npm 会写出 `package-lock.json`。

CI: in the project's stub of [`quality.yml`](../.github/workflows/quality.yml) set `bun: true` (the gate installs the `packageManager` Bun and runs `bun install --frozen-lockfile`) and `lint: npm run lint && npm run typecheck`.

CI：项目的 [`quality.yml`](../.github/workflows/quality.yml) 存根里设 `bun: true`（中央门按 `packageManager` 装 Bun，再跑 `bun install --frozen-lockfile`），并设 `lint: npm run lint && npm run typecheck`。

## Upgrade rule / 升级规则

- **Oxlint** is pinned exactly (no `^`): its JS plugins are alpha and a minor release can change behaviour. Upgrade it alone, in its own commit, with lint and typecheck green.
- **Bun** has two pins that move together in one commit: `packageManager` (`bun@<version>`, the version CI installs, and Railway's Railpack reads it too) and the `bun` dev dependency (the one `npm run typecheck` runs). Reinstall so `bun.lock` follows.
- **Vitest** is a caret range (`^`); `bun.lock` fixes the installed version.
- The starter follows the pins in nokiy/infinite-canvas's `package.json`; when that project upgrades, `package-snippet.json` follows in its own commit.

- **Oxlint** 精确钉版（不带 `^`）：它的 JS 插件还是 alpha，小版本就可能改行为。单独升级、单独提交，lint 与类型检查都绿。
- **Bun** 有两处钉版，同一个提交里一起动：`packageManager`（`bun@<版本>`，CI 装这个版本，Railway 的 Railpack 也读它）和 `bun` 开发依赖（`npm run typecheck` 跑的那个）。重装让 `bun.lock` 跟上。
- **Vitest** 用 `^` 范围，实际版本由 `bun.lock` 锁定。
- 起点配置跟 nokiy/infinite-canvas 的 `package.json` 钉版走；那个项目升级后，`package-snippet.json` 单独提交跟上。

## Pitfalls / 已知坑

- A script named `check` makes `bun check` run that script instead of type-checking: keep the script name `typecheck`.
- An older global `bun` may not read a newer `bun.lock`: install through `npx -y "$(node -p "require('./package.json').packageManager")"` (or `node_modules/.bin/bun`), not the global one.
- Oxlint does not parse JSX in `.ts` files; JSX belongs in `.tsx`.
- Component tests (`.tsx`) need `jsdom` and `@vitejs/plugin-react` in a `vitest.config.ts`; the starter ships none because the smoke test needs none.

- 脚本若叫 `check`，`bun check` 会跑这个脚本而不做类型检查：脚本名保持 `typecheck`。
- 旧版全局 `bun` 可能读不了新版 `bun.lock`：用 `npx -y "$(node -p "require('./package.json').packageManager")"`（或 `node_modules/.bin/bun`）安装，不用全局的。
- Oxlint 不解析 `.ts` 里的 JSX；JSX 写在 `.tsx` 里。
- 组件测试（`.tsx`）需要在 `vitest.config.ts` 里配 `jsdom` 和 `@vitejs/plugin-react`；冒烟测试用不到，所以起点配置不带。
