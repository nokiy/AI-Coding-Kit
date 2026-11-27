<!-- 样例：数据是虚构的，只示范格式（prompts/README.md） -->
<!-- watermark: 2026-11-28T04:30:00+08:00 -->
# CI 健康日报 · 2026-11-28（台湾时间）

**结论**：全量红了一个回归（#1150，早上修），PR CI 变慢一档，其余正常；你不用做什么。

## 全量
红 → #1150 · 提交 7ff3843a · https://github.com/nokiy/quota-bar/actions/runs/46100000001 · 全量红，beta 未装

## 账单（2026-11-27T04:30+08:00 起）
| 流水线 | 运行 | 成功率 | 正常耗时 | 最慢 | 趋势 | 偶发 | 白跑 |
|---|---|---|---|---|---|---|---|
| ci.yml（PR CI） | 14 | 86% | 3 分 47 秒 | 7 分 12 秒 | ↑ | 1 | 0 |
| beta.yml（Beta 机器人） | 6 | 100% | 4 分 05 秒 | 5 分 31 秒 | → | 0 | 0 |
| release-please.yml（发版机器人） | 5 | 100% | 0 分 41 秒 | 1 分 02 秒 | → | 0 | 0 |
| stage-full.yml（全量） | 1 | 0% | — | 18 分 20 秒 | → | 0 | 0 |

预期挂起（发版 PR 等批准）：2 条，不计入成功率。

## 问题清单
| # | 类别 | 问题 | 证据 | Agent 定位 |
|---|---|---|---|---|
| 1 | 回归 | 用量聚合在跨日时少算一条，`UsageAggregateTests.crossMidnight__F41()` 两次都红 | #1150 · runs/46100000001 | `./swift-test.sh F-41`；`Sources/QBCore/UsageAggregateHolder.swift:88`；嫌疑 PR #1147 |
| 2 | 偶发 | PR #1149 的 CI 第一次红、局内重跑绿：`TestQBSearchQueueKeepsCodexAlive__F47` 超时 | runs/46099000123（attempt 2） | `./GatewayCore/go-test.sh F-47`；`GatewayCore/quotabar_search_alive_test.go` |
| 3 | 变慢 | PR CI 正常耗时 3 分 47 秒，上一份 3 分 05 秒（+23%） | 本表 ci.yml 一行 | `gh run list -R nokiy/quota-bar --workflow ci.yml --limit 20 --json databaseId,startedAt,updatedAt`；看 `Test` 步耗时 |

## 修复进度
- #1150 夜间全量红：UsageAggregateTests.crossMidnight__F41 → 还没有 PR（早上 07:30 修复任务处理）
