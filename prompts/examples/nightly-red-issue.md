<!-- 样例：数据是虚构的，只示范格式（prompts/README.md） -->
## 结论
用量聚合跨过午夜时少算最后一条事件，是回归，PR #1147 改了聚合的日期边界。

## 证据
- 全量运行：https://github.com/nokiy/quota-bar/actions/runs/46100000001（提交 7ff3843a）
- 失败测试：`UsageAggregateTests.crossMidnight__F41()`；报错：`Expectation failed: (total → 41) == 42`
- 两次运行：第一次和工作流自动重跑都红

## 嫌疑 PR
#1147 用量页按本地时区切日（理由：改了 `Sources/QBCore/UsageAggregateHolder.swift`，失败的测试正好测它的跨日聚合）

## 建议修法
- `Sources/QBCore/UsageAggregateHolder.swift:88`：切日比较从 `<` 改回 `<=`，午夜整点那条归前一天（#1147 之前的行为）
- 复现命令：`./swift-test.sh F-41`
