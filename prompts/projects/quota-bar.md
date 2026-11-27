# quota-bar · 提示词配置

用 `scripts/prompts/render.sh prompts/projects/quota-bar.md prompts/<nightly|morning>.md` 生成。每个 `## 键` 下面到下一个 `## ` 之前的文字就是它的值。

## project_name
QuotaBar

## repo
nokiy/quota-bar

## default_branch
main

## nightly_time
04:30

## full_workflow
stage-full.yml

## dispatch_cmd
gh workflow run stage-full.yml -R nokiy/quota-bar -f ref=main

## full_wait_minutes
60

## green_action
装不装 beta 由工作流自己判断，你不用管：全量绿才装；已装的就是这份代码就跳过；有 PR 带 `beta-installed` 正在验收也跳过。日报写「beta 已装 / 未装（原因见运行摘要）」。

## not_run_note
全量跑在我 Mac 上的 runner（`niko-mac`）：Mac 睡着时任务排队，醒来自动跑；没跑成不用补救，发版前还有发版门兜底。

## test_name_hint
Swift 形如 `xxx__F41()`，Go 形如 `TestQBxxx__F47`

## verify_hint
Swift 用 `./swift-test.sh F-<编号>`，Go 用 `./GatewayCore/go-test.sh F-<编号>`（编号取测试名末尾 `__F` 后面那段）

## source_read
只读看源码：`git -C /Users/niko/AI_Workspace/AI_Coding/Apps/quota-bar log` / `show`，或直接读该目录下的文件（不切分支、不改文件）

## pipelines
   - `ci.yml`：PR CI
   - `beta.yml`：Beta 机器人（装验收用的 beta）
   - `release-please.yml`：发版机器人
   - `stage-full.yml`：全量

## bot_workflows
`beta.yml`、`release-please.yml`

## morning_runner
你跑在我 Mac 上的 Claude Code 桌面定时任务里，工作目录 `/Users/niko/AI_Workspace/AI_Coding/Apps/quota-bar`，每天 09:00（台湾时间）。Mac 睡着错过了，醒来会补跑一次：补跑时照常做，不用管时间。

## gh_note
本机 `gh` 已登录。

## project_rules
- 先读 `/Users/niko/AI_Workspace/AI_Coding/Apps/quota-bar/CLAUDE.md` 和 `/Users/niko/AI_Workspace/AI_Coding/Apps/quota-bar/.claude/delivery.md`（交付规则：分支、CI、beta、「请验收」），照它们做。
- 动某个领域的代码前读 `/Users/niko/AI_Workspace/AI_Coding/Apps/quota-bar/.claude/domains.md` 里那个领域的一节。
- 主检出 `/Users/niko/AI_Workspace/AI_Coding/Apps/quota-bar` 是我的，可能有没提交的改动：不切它的分支、不在里面改文件，只在下面建的 worktree 里干活。
- 不清 `.build`，不跑全量测试；全量是夜里的事。

## workspace_setup
`git -C /Users/niko/AI_Workspace/AI_Coding/Apps/quota-bar fetch origin`，再 `git -C /Users/niko/AI_Workspace/AI_Coding/Apps/quota-bar worktree add /Users/niko/AI_Workspace/AI_Coding/Apps/quota-bar-wt-nightly-N -b fix/N-nightly-<英文短名> origin/main`，之后只在这个 worktree 里干活。第 2 次尝试时 worktree 已在：先 `git -C <worktree> merge origin/main`。

## verify_scope
失败测试所在的组，用 `./swift-test.sh F-<编号>` / `./GatewayCore/go-test.sh F-<编号>`；PR 正文按 `.claude/delivery.md` 写上这些 `./swift-test.sh` 行，CI 会照跑

## acceptance
1. PR 开成 ready（上面 `draft=false`），不贴 `no-beta`：`no-beta` 的 PR CI 绿就自动合并，修复 PR 必须等我验收。
2. 运行 `/Users/niko/AI_Workspace/AI_Coding/Apps/quota-bar/.claude/await-beta.sh <PR 号>`（本机文件，worktree 里没有；它等 CI 和 Beta 机器人，最多约 40 分钟）：
   - 退出 0：可以请验收（beta 已装且 `verify-install` 绿；改动不碰 App 路径时没有 beta，CI 绿即可）。
   - 退出 4：排在别的验收 PR 后面，照实写「排队中，等 #<号>」。
   - 其他退出码：在 issue 评论它最后一行说的卡在哪一步，回报里写明。
3. 在 issue 评论并在回报里写「请验收」三行：PR #<号> <标题> · 修了什么 · 验收时看什么。
