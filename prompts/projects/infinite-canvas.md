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
你跑在我 Mac 上的 Claude Code 桌面定时任务里，工作目录 `/Users/niko/AI_Workspace/AI_Coding/Learn/infinite-canvas`，每天 09:00（台湾时间）。Mac 睡着错过了，醒来会补跑一次：补跑时照常做，不用管时间。

## gh_note
本机 `gh` 已登录。

## project_rules
- 先读 `/Users/niko/AI_Workspace/AI_Coding/Learn/infinite-canvas/CLAUDE.md`（命令、测试范围、「请验收」），照它做；它不在 git 里，worktree 里没有，读主检出这一份。
- 修复要遵守的修复阶梯在 `docs/agents/repair-ladder.md`。
- 主检出 `/Users/niko/AI_Workspace/AI_Coding/Learn/infinite-canvas` 是我的，可能有没提交的改动：不切它的分支、不在里面改文件，只在下面建的 worktree 里干活。
- AI 调用一律经 QuotaBar 网关；不改 `.env*`，不碰 Railway、Supabase、Cloudflare 的配置。不跑全量测试；全量是夜里的事。

## workspace_setup
`git -C /Users/niko/AI_Workspace/AI_Coding/Learn/infinite-canvas fetch origin`，再 `git -C /Users/niko/AI_Workspace/AI_Coding/Learn/infinite-canvas worktree add /Users/niko/AI_Workspace/AI_Coding/Learn/infinite-canvas-wt-nightly-N -b fix/N-nightly-<英文短名> origin/main`，之后只在这个 worktree 里干活，先装依赖（CLAUDE.md「装依赖」那一行）。第 2 次尝试时 worktree 已在：先 `git -C <worktree> merge origin/main`。

## verify_scope
`npx vitest run --changed origin/main`、`npm run typecheck`、`npm run lint`；改到 `components/ui`、`stories/`、`.storybook/` 时再加 `npm run build-storybook && npm run test-storybook`

## acceptance
1. PR 开成 ready（上面 `draft=false`），不贴 `no-beta`：`no-beta` 的 PR CI 绿就自动合并，修复 PR 必须等我验收。
2. 在 worktree 里运行 `scripts/acceptance.sh <PR 号> --wait`（等 CI 和测试站部署，最多 30 分钟）。
3. 退出 0：在 issue 评论并在回报里写「请验收」，内容就用它输出的三行（版本号 · 改了什么 · 网址）。非 0：在 issue 评论它说的差哪一步，回报里写明。
