# New JS project toolchain / 新项目默认工具链

The single source for a new JS/TS project's toolchain: Bun installs, Oxlint lints, Oxfmt formats (fresh scaffolds only), `bun check` type-checks, Vitest tests.
Skills and docs link here; they never copy the steps or the versions.

新 JS/TS 项目的默认工具链唯一出处：Bun 装依赖、Oxlint 做 lint、Oxfmt 排版（只给新脚手架）、`bun check` 做类型检查、Vitest 跑测试。技能与文档只链接这里，不抄步骤和版本。

## Starter config / 起点配置

[`configs/js-default/`](../configs/js-default):

| File | Copy to | What it is |
|------|---------|------------|
| `oxlintrc.json` | `.oxlintrc.json` | Oxlint with the react / nextjs / import / jsx-a11y / typescript plugins: the rules `eslint-config-next` turned on, the naming rules of [`eslint-naming.json`](../configs/eslint-naming.json), and an override for the scaffold's `tailwind.config.ts` (`require`) |
| `package-snippet.json` | merged into `package.json` | `packageManager`, the `lint` / `typecheck` / `test` scripts, and the `bun` / `oxlint` / `vitest` dev dependencies. The versions live only in the snippets (this one and `fmt-snippet.json`) |
| `oxfmtrc.json` | `.oxfmtrc.json` | Fresh scaffolds only. Oxfmt with `printWidth` 140, other options default; `ignorePatterns` is an allowlist (`*`, then `!*/`, then js / jsx / ts / tsx / mjs / cjs / json / jsonc / css), plus build output and lock files |
| `fmt-snippet.json` | merged into `package.json` | Fresh scaffolds only. The `fmt` (write) / `fmt:check` (check only) scripts and the exactly pinned `oxfmt` dev dependency |
| `smoke.test.ts` | `tests/smoke.test.ts` | One test, because `vitest run` exits 1 when it finds no test file; replace it once real tests exist |

`oxlintrc.json` 是 Oxlint 配置：`eslint-config-next` 打开的规则、`eslint-naming.json` 的命名规则，外加脚手架 `tailwind.config.ts`（`require`）的覆盖项；`package-snippet.json` 合并进 `package.json`，版本只写在两份片段里（它和 `fmt-snippet.json`）；`oxfmtrc.json` 与 `fmt-snippet.json` 只给新脚手架：Oxfmt 配置（行宽 140，其余默认，`ignorePatterns` 写成白名单，只放行 js / jsx / ts / tsx / mjs / cjs / json / jsonc / css，另排除构建产物与锁文件）和 `fmt`（写入）/ `fmt:check`（只检查）两个脚本加精确钉版的 `oxfmt`；`smoke.test.ts` 是一条冒烟测试（`vitest run` 找不到测试文件会退出 1），有了真测试就替换它。

Naming rules: the starter lists no files. Conversion step 5 runs Oxlint once and writes the files that already break `id-length` / `id-denylist` into an override in the project's `.oxlintrc.json`; the same step works when converting an existing project. Every new file is checked; when you rewrite a listed file, drop it from the list.

命名规则：起点配置不带文件名单。转换第 5 步跑一次 Oxlint，把已经违反 `id-length` / `id-denylist` 的文件写进项目 `.oxlintrc.json` 的一个覆盖项；转换已有项目也用这一步。新文件都要过检查；改写了名单里的文件，就把它从名单删掉。

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

# 2. Copy the starter files (Oxfmt: fresh scaffolds only)
cp "$KIT/configs/js-default/oxlintrc.json" .oxlintrc.json
cp "$KIT/configs/js-default/oxfmtrc.json" .oxfmtrc.json
mkdir -p tests && cp "$KIT/configs/js-default/smoke.test.ts" tests/smoke.test.ts

# 3. Merge the snippets into package.json and drop every eslint package (fmt-snippet: fresh scaffolds only)
node -e '
const fs = require("fs");
const pkg = JSON.parse(fs.readFileSync("package.json", "utf8"));
for (const deps of [pkg.dependencies, pkg.devDependencies])
  for (const name of Object.keys(deps ?? {})) if (name.includes("eslint")) delete deps[name];
for (const snippet of process.argv.slice(1)) {
  const starter = JSON.parse(fs.readFileSync(snippet, "utf8"));
  pkg.packageManager = starter.packageManager ?? pkg.packageManager;
  pkg.scripts = { ...pkg.scripts, ...starter.scripts };
  pkg.devDependencies = { ...pkg.devDependencies, ...starter.devDependencies };
}
fs.writeFileSync("package.json", JSON.stringify(pkg, null, 2) + "\n");
' "$KIT/configs/js-default/package-snippet.json" "$KIT/configs/js-default/fmt-snippet.json"

# 4. Reinstall with the pinned Bun (the scaffold's bun.lock came from whatever bun is global)
npx -y "$(node -p "require('./package.json').packageManager")" install

# 5. Naming baseline: files that already break the naming rules go into one override; new files stay checked
node -e '
const fs = require("fs");
const { spawnSync } = require("child_process");
const run = spawnSync("node_modules/.bin/oxlint", ["--format=json"], { encoding: "utf8" });
const naming = ["eslint(id-length)", "eslint(id-denylist)"];
const files = [...new Set(JSON.parse(run.stdout).diagnostics
  .filter((diag) => naming.includes(diag.code)).map((diag) => diag.filename))].sort();
if (files.length) {
  const config = JSON.parse(fs.readFileSync(".oxlintrc.json", "utf8"));
  config.overrides = [...(config.overrides ?? []), { files, rules: { "id-length": "off", "id-denylist": "off" } }];
  fs.writeFileSync(".oxlintrc.json", JSON.stringify(config, null, 2) + "\n");
}
console.log("naming baseline: " + files.length + " files");
'

# 6. Format once, after step 5 (the baseline rewrites .oxlintrc.json)
npm run fmt

# 7. Every check exits 0
npm run fmt:check && npm run lint && npm run typecheck && npm run build && npm run test
```


Done when: no `eslint.config.*` / `.eslintrc*`, no `eslint` in `package.json`, no `package-lock.json`, only `bun.lock`, and `npm run fmt:check` exits 0.
Use `npm run <script>`, never `npm install` / `npm ci`: npm would write a `package-lock.json`.

完成标准：没有 `eslint.config.*` / `.eslintrc*`，`package.json` 里没有 `eslint`，没有 `package-lock.json`，只有 `bun.lock`，`npm run fmt:check` 退出 0。脚本用 `npm run <script>` 跑，NEVER `npm install` / `npm ci`：npm 会写出 `package-lock.json`。

CI: in the project's stub of [`quality.yml`](../.github/workflows/quality.yml) set `bun: true` (the gate installs the `packageManager` Bun and runs `bun install --frozen-lockfile`) and `lint: npm run lint && npm run typecheck`; a project with a `fmt:check` script sets `lint: npm run fmt:check && npm run lint && npm run typecheck`.

CI：项目的 [`quality.yml`](../.github/workflows/quality.yml) 存根里设 `bun: true`（中央门按 `packageManager` 装 Bun，再跑 `bun install --frozen-lockfile`），并设 `lint: npm run lint && npm run typecheck`；有 `fmt:check` 脚本的项目设 `lint: npm run fmt:check && npm run lint && npm run typecheck`。

## Convert an existing project / 转换已有项目

Run the fresh-scaffold steps without Oxfmt: skip the `oxfmtrc.json` copy in step 2, pass only `package-snippet.json` to step 3, skip step 6, and drop `npm run fmt:check` from step 7. Formatting would rewrite most files at once, so it never rides along with the conversion.

照新脚手架的步骤做，但不带 Oxfmt：第 2 步不拷 `oxfmtrc.json`，第 3 步只传 `package-snippet.json`，跳过第 6 步，第 7 步去掉 `npm run fmt:check`。排版会一次改写大部分文件，所以不跟转换一起做。

To format an existing project later, take its own route:

1. Clear the file-gate debt first ([`protocols/file-gate.md`](../protocols/file-gate.md): over-long files, over-long lines), so formatting does not push files over the limits.
2. Add Oxfmt (`oxfmtrc.json` + `fmt-snippet.json`, then reinstall: steps 2–4), append the project's own generated or vendored directories to `ignorePatterns`, run `npm run fmt`, and land it as one PR that only formats.
3. After it is squash-merged, add that commit's hash to `.git-blame-ignore-revs`; each clone runs `git config blame.ignoreRevsFile ':(optional).git-blame-ignore-revs'` once.

已有项目要排版，单独走一条路：

1. 先还 file-gate 旧债（[`protocols/file-gate.md`](../protocols/file-gate.md)：超长文件、超长行），免得排版把文件推过上限。
2. 加 Oxfmt（`oxfmtrc.json` + `fmt-snippet.json`，再重装：同第 2–4 步），把项目自己的生成目录、第三方目录追加进 `ignorePatterns`，跑 `npm run fmt`，作为一个只排版的 PR 合进去。
3. squash 合并后，把那次提交的哈希登记进 `.git-blame-ignore-revs`；每个克隆跑一次 `git config blame.ignoreRevsFile ':(optional).git-blame-ignore-revs'`。

## Upgrade rule / 升级规则

- **Oxlint** is pinned exactly (no `^`): its JS plugins are alpha and a minor release can change behaviour. Upgrade it alone, in its own commit, with lint and typecheck green.
- **Bun** has two pins that move together in one commit: `packageManager` (`bun@<version>`, the version CI installs, and Railway's Railpack reads it too) and the `bun` dev dependency (the one `npm run typecheck` runs). Reinstall so `bun.lock` follows.
- **Vitest** is a caret range (`^`); `bun.lock` fixes the installed version.
- **Oxfmt** is pinned exactly: upgrade it alone, in its own commit; when the new version formats differently, follow it at once with a commit that only formats.
- The starter follows the pins in nokiy/infinite-canvas's `package.json`; when that project upgrades, `package-snippet.json` follows in its own commit.

- **Oxlint** 精确钉版（不带 `^`）：它的 JS 插件还是 alpha，小版本就可能改行为。单独升级、单独提交，lint 与类型检查都绿。
- **Bun** 有两处钉版，同一个提交里一起动：`packageManager`（`bun@<版本>`，CI 装这个版本，Railway 的 Railpack 也读它）和 `bun` 开发依赖（`npm run typecheck` 跑的那个）。重装让 `bun.lock` 跟上。
- **Vitest** 用 `^` 范围，实际版本由 `bun.lock` 锁定。
- **Oxfmt** 精确钉版：单独升级、单独提交；新版本排版结果变了，紧跟一次只排版的提交。
- 起点配置跟 nokiy/infinite-canvas 的 `package.json` 钉版走；那个项目升级后，`package-snippet.json` / `fmt-snippet.json` 单独提交跟上。

## Pitfalls / 已知坑

- A script named `check` makes `bun check` run that script instead of type-checking: keep the script name `typecheck`.
- An older global `bun` may not read a newer `bun.lock`: install through `npx -y "$(node -p "require('./package.json').packageManager")"` (or `node_modules/.bin/bun`), not the global one.
- Oxlint does not parse JSX in `.ts` files; JSX belongs in `.tsx`.
- Component tests (`.tsx`) need `jsdom` and `@vitejs/plugin-react` in a `vitest.config.ts`; the starter ships none because the smoke test needs none.
- Oxfmt formats Markdown, HTML, YAML and more by default: the allowlist in `ignorePatterns` keeps it to code, JSON and CSS; to format another file type, add its `!*.<ext>` to the allowlist.
- Oxfmt reorders `package.json` keys by default; that is kept, as part of formatting.
- A test that reads a CSS file's source text literally breaks once Oxfmt reformats that file: assert on what matters, not on exact spacing.

- 脚本若叫 `check`，`bun check` 会跑这个脚本而不做类型检查：脚本名保持 `typecheck`。
- 旧版全局 `bun` 可能读不了新版 `bun.lock`：用 `npx -y "$(node -p "require('./package.json').packageManager")"`（或 `node_modules/.bin/bun`）安装，不用全局的。
- Oxlint 不解析 `.ts` 里的 JSX；JSX 写在 `.tsx` 里。
- 组件测试（`.tsx`）需要在 `vitest.config.ts` 里配 `jsdom` 和 `@vitejs/plugin-react`；冒烟测试用不到，所以起点配置不带。
- Oxfmt 默认还排 Markdown、HTML、YAML 等：`ignorePatterns` 的白名单把它限在代码、JSON、CSS；要排别的文件类型，在白名单里加 `!*.<扩展名>`。
- Oxfmt 默认重排 `package.json` 的键顺序；保留，属于排版。
- 按字面读 CSS 原文的测试会在 Oxfmt 排版后失败：断言要看的内容，不断言空白。
