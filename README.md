# AI Coding Kit

> Principles and tools for building software in the AI era.
>
> AI 时代软件开发的原则与工具。

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

---

## Why / 为什么

AI changed how we write code. But most projects still lack the structure to work effectively with AI assistants.

This kit solves that — a collection of **principles**, **protocols**, and **scripts** born from real-world AI-assisted development.

AI 改变了我们写代码的方式。但大多数项目仍缺乏与 AI 助手高效协作的结构。

本工具集解决这个问题——一套源自实战的**原则**、**协议**和**脚本**。

---

## What's Inside / 内容

| Directory | Description |
|-----------|-------------|
| [`protocols/`](./protocols) | Rules for AI behavior / AI 行为规则 |
| [`templates/`](./templates) | Document templates / 文档模板 |
| [`scripts/`](./scripts) | Automation scripts / 自动化脚本 |
| [`prompts/`](./prompts) | Prompt library / 提示词库 |
| [`configs/`](./configs) | Config presets / 配置预设 |
| [`checklists/`](./checklists) | Quality checklists / 质量清单 |
| [`guides/`](./guides) | How-to guides / 使用指南 |

---

## Featured / 精选

### [Fractal Docs Protocol](./protocols/fractal-docs.md)

A self-referential documentation system. Every folder has a `.folder.md`, every file has `[IN]/[OUT]/[POS]` headers. Changes propagate automatically.

Inspired by "Gödel, Escher, Bach".

一套自指的文档系统。每个文件夹有 `.folder.md`，每个文件有 `[IN]/[OUT]/[POS]` 头注释。变更自动传播。

灵感来自《哥德尔、埃舍尔、巴赫》。

```bash
# Add to your project
curl -o CLAUDE.md https://raw.githubusercontent.com/JessyTsui/ai-coding-kit/main/protocols/fractal-docs.md
```

---

## Usage / 使用

**Option 1**: Clone everything
```bash
git clone https://github.com/JessyTsui/ai-coding-kit.git
```

**Option 2**: Grab what you need
```bash
curl -O https://raw.githubusercontent.com/JessyTsui/ai-coding-kit/main/protocols/fractal-docs.md
```

---

## Contributing / 贡献

Found a principle or script useful for AI-era development? PRs welcome.

发现了对 AI 时代开发有用的原则或脚本？欢迎 PR。

---

## License / 许可

[MIT](./LICENSE) — Use freely.

---

**Star if useful. / 有用请 Star。**
