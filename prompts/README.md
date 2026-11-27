# prompts/

两份与代理无关的提示词模板，加每个项目一份配置。模板只写流程，项目之间不同的东西全在配置里：同一份模板配两个项目，生成的两份提示词只差配置项。

| 文件 | 是什么 | 谁来跑 |
|---|---|---|
| `nightly.md` | 夜间值班：触发全量 → 等结果 → 绿后动作 → 红了评审（偶发 / 回归 / 环境、嫌疑 PR、修法）→ 开或追加 `nightly-red` / `ci-health` issue → 写置顶 issue「CI 健康日报」 | dots（ChatGPT personal agent），每天台湾 04:30 |
| `morning.md` | 早晨修复：读打开的 `nightly-red` → 复现 → 票分支修 → 开 PR → 「请验收」；顺带巡检 `awaiting-observation` issue | Claude Code 定时任务（项目配置写明是本机桌面任务还是云端 `/schedule`），也可以 `/loop` |
| `projects/<项目>.md` | 一个项目的配置：`## 键` 下面到下一个 `## ` 之前就是值 | — |
| `projects/variants/<项目>-<变体>.md` | 只覆盖几个键的变体（如 AI 画板早晨修复改在本机跑） | — |
| `rendered/` | 生成好的提示词，接入时整份贴（`scripts/prompts/render-all.sh` 生成，别手改） | — |
| `SETUP.md` | 接入步骤：贴到哪、几点、怎么建定时任务、之后观察什么 | 我 |
| `examples/` | 填好的样例：CI 健康日报、`nightly-red` issue | — |

## 生成

```bash
scripts/prompts/render.sh prompts/projects/quota-bar.md prompts/nightly.md   # → stdout，整份贴进 dots 的定时任务
scripts/prompts/render.sh prompts/projects/quota-bar.md prompts/morning.md   # → 桌面定时任务的指令
scripts/prompts/render.sh prompts/projects/infinite-canvas.md prompts/projects/variants/infinite-canvas-local.md prompts/morning.md  # 变体：后面的配置覆盖同名键
scripts/prompts/render-all.sh                                                 # 全部重新生成到 prompts/rendered/
scripts/prompts/test.sh                                                       # 自测：两个项目都能生成、白名单、样例格式、rendered/ 是最新
```

模板里每个 `{{键}}` 换成配置里同名的值；配置缺键，`render.sh` 退出 1 并说出缺哪个。新项目：复制一份 `projects/*.md`，逐键改值。

## 配置键

| 键 | 用在 | 含义 |
|---|---|---|
| `project_name` · `repo` · `default_branch` | 两份 | 项目名、`owner/repo`、主分支 |
| `nightly_time` | 夜间 | 触发时刻（台湾时间） |
| `full_workflow` · `dispatch_cmd` · `full_wait_minutes` | 夜间 | 全量存根文件名、触发命令、最多等几分钟 |
| `green_action` | 夜间 | 全量绿后发生什么（quota-bar 由工作流装 beta；AI 画板什么都不做） |
| `not_run_note` | 夜间 | 没跑成时的说明（跑在哪台机器） |
| `test_name_hint` · `verify_hint` | 两份 | 失败测试长什么样、怎样单独跑一个 |
| `source_read` | 夜间 | 只读看源码的方式 |
| `pipelines` · `bot_workflows` | 夜间 | 健康巡检要看的流水线、算「机器人故障」的流水线 |
| `morning_runner` · `gh_note` | 早晨 | 在哪里跑、什么时候；`gh` 的可用范围 |
| `project_rules` | 早晨 | 项目规则：本机任务指向项目文件，云端任务全文写进来（云端只有一份新克隆） |
| `workspace_setup` · `verify_scope` · `acceptance` | 早晨 | 怎样拿到票分支、修完跑什么、怎样「请验收」 |

当前默认（261127 定）：AI 画板绿后不部署；早晨修复 quota-bar 用本机桌面定时任务（09:00）、AI 画板用云端 `/schedule`（07:30，本机变体 09:00）；dots 每天 04:30 触发。

## 和中央全量的约定

- 全量工作流是 `.github/workflows/full-suite.yml`：测试失败时整条重跑一次，结果写成提交状态 `full-suite`（「全量通过」/「全量通过（偶发：重跑后通过）」/「全量失败」），同一提交已有结果就秒退跳过。所以夜间提示词不许重跑运行。
- 两个项目都设 `issue-filer: external`：中央红了只写状态，由夜间值班开 issue。中央兜底：红了 `review-window`（默认 120 分钟）还没有打开的 `nightly-red`，**下一次触发时**中央开「全量失败（未经评审）」。没有 GitHub 定时兜底，所以下一次触发通常是第二天夜里：一晚没评审，红灯最晚第二天夜里有 issue。这是有意接受的延迟。
- 每仓最多一张打开的 `nightly-red`；全量重新跑绿时中央评论「已恢复」并关掉它。所以修复 PR 写 `Refs #N`，不写 `Closes`。
- `release-please--*` 分支上 `action_required` 的运行是预期（GITHUB_TOKEN 开的发版 PR，GitHub 等批准，Kit#26）：不算红、不开 issue、不计入成功率，日报只记条数。
- 标签：`nightly-red` = 确认是回归，早晨修；`ci-health` = 偶发、变慢、白跑，只记录，加上 `nightly-red` 才进早晨修复；`awaiting-observation` = 合并后要隔几天才看得到的验收行。

## 权限

- 夜间：只读命令随便用；写只有触发全量、开 / 评论 issue、改日报那一张、建两个标签（`nightly.md` § 允许的命令）。不改代码、不推送、不合并、不改仓库设置，不重跑。
- 早晨：可以建票分支、提交、推分支、开 PR、评论、给观察 issue 打勾；不合并、不批准 PR，不推主分支，不删 / 跳测试，每张 issue 最多 2 次。

## `awaiting-observation` 的行格式

早晨巡检按这一行格式读写，开这类 issue 时照写：

```
- ☐ <票>#<行号> · <看什么> · 最早 <YYYY-MM-DD>
```

满足后变成 `- ✅ … · <证据链接>`；全部打勾后早晨任务评论请你关闭，不自己关。
