# infinite-canvas（AI 画板）· 云端早晨修复的变体

本机桌面定时任务是默认；这是准备好的备选：早晨修复改成 Claude Code 云端定时任务（`/schedule`）。只覆盖下面这几个键，其余沿用 `../infinite-canvas.md`。
生成：`scripts/prompts/render.sh prompts/projects/infinite-canvas.md prompts/projects/variants/infinite-canvas-cloud.md prompts/morning.md`。

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

## acceptance
1. PR 开成 ready（上面 `draft=false`），不贴 `no-beta`：`no-beta` 的 PR CI 绿就自动合并，修复 PR 必须等我验收。
2. CI 绿后 `beta.yml` 会把这个 PR 部署到测试站并在 PR 上留言版本号：每 3 分钟查一次 `gh api "repos/nokiy/infinite-canvas/issues/<PR 号>/comments?per_page=100"`，最多等 30 分钟。`scripts/acceptance.sh` 要我本机的登录态，云端不跑。
3. 等到留言：在 issue 评论并在回报里写「请验收」三行：版本号 · 修了什么 · https://canvas-test.loki.ac.cn。CI 红或 30 分钟没等到：照实写卡在哪一步。
