# 接入步骤：dots 夜间值班 + 早晨修复（两个项目）

要贴的提示词都在 `prompts/rendered/`，由 `scripts/prompts/render-all.sh` 从模板和配置生成；改了模板或配置就重跑它（不重跑，`scripts/prompts/test.sh` 会红）。
本机路径：`/Users/niko/AI_Workspace/AI_Coding/lk-nexus/tools/infra/ai-coding-kit/prompts/rendered/`（先把这个检出更新到含本目录的分支）。

| 谁 | 项目 | 贴哪份 | 什么时候（台湾时间） |
|---|---|---|---|
| dots | quota-bar | `quota-bar-nightly.md` | 每天 04:30 |
| dots | AI 画板 | `infinite-canvas-nightly.md` | 每天 04:30 |
| Claude Desktop 本机定时任务 | quota-bar | `quota-bar-morning.md` | 每天 09:00 |
| Claude Desktop 本机定时任务（默认） | AI 画板 | `infinite-canvas-morning.md` | 每天 09:00 |
| Claude Code 云端定时任务（备选） | AI 画板 | `infinite-canvas-morning-cloud.md` | 每天 07:30 |

不设 GitHub 定时：全量只由 dots 触发（「发版」时发版门也可能补跑一次）。

## 1. dots：两个夜间任务

1. 确认 Mac 上 `gh auth status` 已登录、能看到两个仓库（dots 用这个 `gh`）。
2. 在 dots 里新建定时任务「quota-bar 夜间 CI 值班」：每天 04:30，指令整份贴 `quota-bar-nightly.md`。
3. 同样建「AI 画板夜间 CI 值班」，贴 `infinite-canvas-nightly.md`。两个仓库各跑各的，同一时刻不冲突。
4. 手动试跑可以，但验收只认它自己定时跑完的那一晚。
5. Agy 的 quota-bar 巡检先留着；dots 自己跑通一晚（验收行 1）后停掉它。两边撞上同一提交时，后到的那次全量几秒就跳过。

## 2. quota-bar 早晨修复：Claude Desktop 本机定时任务

1. Claude Desktop → **Code** 标签 → 侧栏 **Scheduled**（有的账号叫 **Routines**）→ **New task**；弹出菜单就选 **Set up manually**（出现 **Local / Cloud** 就选 **Local**）。
2. **Name**：`quota-bar-morning-repair`；指令框整份贴 `quota-bar-morning.md`。
3. **Advanced settings → General**：打开 **Only on this computer**；**Local folder** 选 `/Users/niko/AI_Workspace/AI_Coding/Apps/quota-bar`。
4. **Trigger**：**Daily**，09:00。
5. 指令框工具栏：权限模式选 **Accept edits**，模型自选。点 **Create**，问到就信任该文件夹。
6. 不勾 **Worktree**：提示词自己在 `quota-bar-wt-nightly-<号>` 建 worktree，主检出不动。
7. 详情页点一次 **Run now**，打开那次会话，遇到权限提示一律选 always allow。没有 `nightly-red` 时它只巡检观察项；第一次真修（验收行 4 注入失败那次）会再问到 `git worktree`、`git push`、`swift-test.sh`、`await-beta.sh`，同样 always allow。
8. 只在 Desktop 开着、Mac 醒着时跑；睡过了点，醒来补跑一次（提示词已说明补跑照常做）。可在 **Settings → Desktop app** 打开 **Keep computer awake**。

## 3. AI 画板早晨修复：Claude Desktop 本机定时任务（默认）

照第 2 节建，只换这几处：**Name** `infinite-canvas-morning-repair`；指令框整份贴 `infinite-canvas-morning.md`；**Local folder** 选 `/Users/niko/AI_Workspace/AI_Coding/Learn/infinite-canvas`；每天 09:00。第一次真修会问到 `git worktree`、`git push`、`scripts/acceptance.sh`，一律 always allow。

### 备选：AI 画板改用云端定时任务

本机跑不了（如 Mac 常年不开）时：按下面建云端任务，贴 `infinite-canvas-morning-cloud.md`，然后把本机那个任务暂停。

1. 在终端的 Claude Code 里跑一次 `/web-setup`，让 claude.ai 账号能克隆 `nokiy/infinite-canvas`。
2. 打开 https://claude.ai/code/routines → **New task**（或 **New routine**）→ 选 **Set up manually**。
3. 名字 `infinite-canvas-morning-repair`；提示词整份贴 `infinite-canvas-morning-cloud.md`。
4. **Trigger**：**Schedule**，每天 07:30（按本地时间填）。
5. **Repository**：`nokiy/infinite-canvas`。**Cloud environment**：**Default**（Limited，勾着 **Allow package managers**）。
6. **Create**，详情页点一次 **Run now**，看会话里有没有卡在权限或网络上（云端默认 auto mode）。
7. 也可以在 AI 画板检出里的 Claude Code 会话跑 `/schedule`，按问答填同样的仓库、时间和提示词。

## 4. 之后要观察的（Kit#32 验收行）

| 行 | 看什么 | 去哪看 |
|---|---|---|
| 1 | quota-bar 一晚无人值守：触发全量、绿了装 beta、置顶「CI 健康日报」更新 | `stage-full.yml` 运行记录 + 置顶 issue |
| 2 | AI 画板一晚无人值守，同上（绿了不部署） | `full-suite.yml` 运行记录 + 置顶 issue |
| 3 | 同一提交第二次触发几秒跳过 | 运行摘要 `Full suite skipped` |
| 4 | 一次性分支注入失败 → dots 开出写明判断与修法的 `nightly-red` | issue |
| 5 | 早晨任务读到第 4 行的 issue，开修复 PR 并「请验收」 | PR 时间线 + 任务回报 |
