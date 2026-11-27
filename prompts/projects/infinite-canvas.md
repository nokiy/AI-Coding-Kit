# infinite-canvas（AI 画板）· 提示词配置

用 `scripts/prompts/render.sh prompts/projects/infinite-canvas.md prompts/<nightly|morning>.md` 生成。每个 `## 键` 下面到下一个 `## ` 之前的文字就是它的值。

## project_name
AI 画板

## repo
nokiy/infinite-canvas

## default_branch
main

## nightly_time
04:30

## full_workflow
full-suite.yml

## dispatch_cmd
gh workflow run full-suite.yml -R nokiy/infinite-canvas

## full_wait_minutes
40

## green_action
绿了不部署、不做别的：正式站只在「发版」时部署，测试站只给验收中的 PR。

## not_run_note
全量跑在 Railway 执行机 `railway-runner-ic` 上；执行机离线、排队超过等待时间，就照写「没跑成」。

## test_name_hint
单测失败形如 `FAIL tests/xxx.test.ts > <描述>`；文档站浏览器检查失败出在 `test-storybook`（`.storybook/check-stories.mjs`），带故事名

## verify_hint
单测用 `npx vitest run <测试文件>`；文档站检查用 `npm run build-storybook && npm run test-storybook`

## source_read
只读看源码：`git -C /Users/niko/AI_Workspace/AI_Coding/Learn/infinite-canvas log` / `show`，或直接读该目录下的文件（不切分支、不改文件）

## pipelines
   - `ci.yml`：PR CI
   - `beta.yml`：测试站部署（验收中的 PR）
   - `release-please.yml`：发版机器人
   - `deploy-production.yml`：正式站部署
   - `full-suite.yml`：全量
   - `test-db-keepalive.yml`：测试库保活

## bot_workflows
`beta.yml`、`release-please.yml`、`deploy-production.yml`、`test-db-keepalive.yml`

## morning_runner
你跑在 Claude Code 云端定时任务（`/schedule`）里，每天 07:30（台湾时间）：仓库是一份新克隆，没有我本机的任何文件，项目规则全在下面。

## gh_note
云端的 `gh issue`、`gh pr` 子命令走 GraphQL，会被 GitHub 代理拒（403），所以只用 `gh api`；不用 `gh auth login`，代理替你带凭证。

## project_rules
仓库根的 `CLAUDE.md` 不在 git 里，云端读不到；规则以这里为准。
- 装依赖：`npx -y "$(node -p "require('./package.json').packageManager")" install --frozen-lockfile`。锁文件是 `bun.lock`：不要 `npm ci`（会失败），不要 `npm install`（会悄悄生成 `package-lock.json`）。
- 命令：格式化 `npm run fmt`（每次提交前跑）· 类型检查 `npm run typecheck` · lint `npm run lint` · 单测 `npm run test`（vitest run）· 文档站 `npm run build-storybook` 后 `npm run test-storybook`（云端有 Chrome，`CHROME_PATH` 已设）。
- 测试里要 `localStorage` 时用 `tests/helpers.ts` 的 `createMemoryStorage()`：Node 26 自带的全局 `localStorage` 会遮住 jsdom 的。
- 业务代码只从 `components/ui` 取组件；lk 只经 `@/lib/lk`，UI SDK 只经 lk（守卫 `guards/ui-entry`、`guards/lk-entry`、`guards/ui-sdk`）。
- AI 调用一律经 QuotaBar 网关，不直连模型供应商；不改 `.env*`，不碰 Railway、Supabase、Cloudflare 的配置。
- 可读的项目文档：`docs/architecture.md`、`docs/decisions.md`、`docs/agents/repair-ladder.md`、`docs/troubleshooting/`。

## workspace_setup
仓库已克隆在默认分支：`git fetch origin main`，再 `git switch -c fix/N-nightly-<英文短名> origin/main`（第 2 次尝试且分支已在远端：`git switch fix/N-nightly-<英文短名>` 后 `git merge origin/main`）。然后装依赖（见项目规则）。云端拉 Bun 的包可能被代理挡：装不上就在 issue 评论「云端装不上依赖」和报错末尾，不算一次尝试，处理下一张。

## verify_scope
`npx vitest run --changed origin/main`、`npm run typecheck`、`npm run lint`；改到 `components/ui`、`stories/`、`.storybook/` 时再加 `npm run build-storybook && npm run test-storybook`

## acceptance
1. PR 开成 ready（上面 `draft=false`），不贴 `no-beta`：`no-beta` 的 PR CI 绿就自动合并，修复 PR 必须等我验收。
2. CI 绿后 `beta.yml` 会把这个 PR 部署到测试站并在 PR 上留言版本号：每 3 分钟查一次 `gh api "repos/nokiy/infinite-canvas/issues/<PR 号>/comments?per_page=100"`，最多等 30 分钟。`scripts/acceptance.sh` 要我本机的登录态，云端不跑。
3. 等到留言：在 issue 评论并在回报里写「请验收」三行：版本号 · 修了什么 · https://canvas-test.loki.ac.cn。CI 红或 30 分钟没等到：照实写卡在哪一步。
