# File Gate Protocol

> Every code file a commit or PR touches is judged whole: at most 400 lines, no line over
> 200 characters, and a file name that says what it is about.
>
> 提交或 PR 碰到的每个代码文件都整份检查：不超过 400 行、单行不超过 200 字符、文件名要说得出领域。

Implementation: [`scripts/file-gate/file-gate.sh`](../scripts/file-gate/file-gate.sh).

## Scope

- Every file a commit adds, copies, modifies or renames (deleted files are not judged).
- The whole file, old lines and new alike. Touching a file means it must meet the rules;
  there is no ratchet and no warning tier.
- Tests are code: `Tests/`, `tests/` and paths containing `config` are checked.

## Rules

| # | Rule | Blocks when |
|---|------|-------------|
| 1 | Generic file name | the base name without its last extension, lower-cased, is one of: util utils helper helpers type types model models common config configs constant constants extension extensions misc shared base manager service services data (`OrderUtils.swift`, `order_utils.py`, `main`, `index`, `App`, `mod`, `lib`, `__init__` pass) |
| 2 | File size | more than **400** lines (a last line without a trailing newline counts) |
| 3 | Line length | any line longer than **200** characters, counted as Unicode characters (a CJK character is 1; a CR before the newline is not counted) |

## Two layers

| Layer | Runs | Judges | Final? |
|-------|------|--------|--------|
| Pre-commit hook | `file-gate.sh --staged` | the staged copy (index blob), never the disk copy, so partial staging is judged by what gets committed | No: `git commit --no-verify` skips it, and it passes while a merge, rebase, cherry-pick or revert is in progress |
| CI | `file-gate.sh --base origin/<base>` in the File gate step of `.github/workflows/quality.yml` | files changed between merge-base(base, HEAD) and HEAD, at HEAD | Yes: always on, no workflow input turns it off |

The CI step checks out the kit at the reusable workflow's own commit (`job.workflow_repository` @
`job.workflow_sha`) and fails if either is empty. On a push event (no PR) the base is the pushed
branch itself, so the diff is empty and the gate passes.

## Skipped files

A file is skipped entirely when any of these holds:

- its extension is not code. Code = swift go ts tsx js jsx mjs cjs py rs kt java rb dart c h cpp hpp
  m mm vue svelte html css scss sh bash zsh (lockfiles, md, json, yaml … are not judged);
- a directory segment of its path is node_modules, vendor, third_party, dist, build, .build, docs,
  .claude, prototype or prototypes (whole segments: `builder/` is checked);
- it is generated: one of its first 5 lines matches `Code generated .* DO NOT EDIT` or `@generated`,
  or `git check-attr linguist-generated` is set/true;
- it is vendored: `git check-attr linguist-vendored` is set/true (a `-linguist-vendored` line
  re-includes a file);
- it is listed in the repo-root `.lint-exempt`: one path per line, `#` comments, leading `./` and
  trailing `/` dropped; a directory exempts everything under it. `--staged` reads the staged
  `.lint-exempt` and attributes, `--base` the ones at HEAD.

## Messages

The first line names the layer: `✗ 提交被拦（file-gate）` (pre-commit) or
`✗ CI 文件检查未通过（file-gate）` (CI). Every violation of every file is printed, then
`规则：AI-Coding-Kit protocols/file-gate.md`.

```
✗ <path>：<n> 行，超过 400 行硬线
最大的函数：<name> L<a>-<b>（<nloc> 行）；…
拆分步骤：
 1. 按职责找切口：顶层类型、extension、// MARK: 段落
 2. Swift 拆成 类型+主题.swift；Go 在同一个包里新建文件；JS/TS 拆成独立模块
 3. 只搬代码、不改行为，拆分单独提交，测试通过后再做原来的修改
 4. 更新新旧文件的 [POS] 文件头和目录 README

✗ <path>:<line>：<len> 字符，超过 200          (at most 10 per file, then …另有 N 行)
断行方法：把长表达式拆成中间变量 / 参数一个一行 / 长字符串拆开或移到常量

✗ <path>：文件名 "<base>" 是万金油名字，搜索时分不清
改法：前面加上这个文件所属的领域，如 Order<Base>.<ext>；文件头和引用它的地方一起改
```

A passing run prints `✓ file-gate：检查了 N 个文件，全部通过`.

## Exit codes

| Code | Meaning |
|------|---------|
| 0 | pass |
| 1 | violations (all printed) |
| 2 | internal error, one line on stderr: not a repo, base ref unresolvable, no merge-base, unreadable blob, bad arguments. Never a silent pass |

## Lizard

The `最大的函数` line comes from [lizard](https://github.com/terryyin/lizard): `$LIZARD`, else
`lizard` on PATH, else `$HOME/.local/bin/lizard`, run with a 3-second cap on a temporary copy that
keeps the file's extension; the top 3 functions by NLOC are listed. When lizard is absent, times out
or fails, the line is omitted and the block still stands.

## Identifier names

Names inside files (variables, functions) are not judged by the gate; each language's linter does
it in CI's Lint step, configured from [`configs/`](../configs): `swiftlint-naming.yml`,
`eslint-naming.json`.

## Portability

`file-gate.sh` runs on macOS `/bin/bash` 3.2 and Linux bash, needing only git and perl.
`scripts/file-gate/test.sh` is its self-test; `.github/workflows/self-test.yml` runs it on Linux for
every PR into the kit.
