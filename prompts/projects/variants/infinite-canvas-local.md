# infinite-canvas（AI 画板）· 本机早晨修复的变体

云端定时任务用不了时的备选：早晨修复改成我 Mac 上的 Claude Code 桌面定时任务。只覆盖下面这几个键，其余沿用 `../infinite-canvas.md`。
生成：`scripts/prompts/render.sh prompts/projects/infinite-canvas.md prompts/projects/variants/infinite-canvas-local.md prompts/morning.md`。

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

## acceptance
1. PR 开成 ready（上面 `draft=false`），不贴 `no-beta`：`no-beta` 的 PR CI 绿就自动合并，修复 PR 必须等我验收。
2. 在 worktree 里运行 `scripts/acceptance.sh <PR 号> --wait`（等 CI 和测试站部署，最多 30 分钟）。
3. 退出 0：在 issue 评论并在回报里写「请验收」，内容就用它输出的三行（版本号 · 改了什么 · 网址）。非 0：在 issue 评论它说的差哪一步，回报里写明。
