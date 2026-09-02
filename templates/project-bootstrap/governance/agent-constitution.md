# Agent Constitution — TODO: 填写项目名称

This file governs how any AI agent may interact with this codebase.

## What This Project Is

**TODO: 用一句话定义这个项目是什么，不是什么。**

示例格式（参考下例——模板自带示例，勿照抄内容）：
> **Decision OS v4.10.0** - a local-first cognitive governance system, not a todo app.

核心数据流（如果有）：

```text
TODO: 填写核心数据流。例：Evidence -> Variable -> Conclusion
```

技术栈：TODO: React 18 + Vite + ... / Python + FastAPI + ... / 其他

TODO: 说明单用户 vs 多用户，本地优先 vs 云端优先等关键设计取向。

## Architecture

```text
TODO: 填写目录结构和各层职责。例：
src/core/       -> Logic engine
src/ui/         -> Shared UI primitives
src/features/   -> Feature clusters
src/App.jsx     -> Thin shell
```

TODO: 说明业务逻辑集中在哪里，UI 在哪里，不要在 Constitution 里写实现细节。

## Absolute Constraints

### Minimal Diff

- Only make changes explicitly required by the current Node.
- No whole-file formatting, no opportunistic refactors, no style fixes.
- TODO: 列出不能随意修改的核心文件。例：Do not touch `src/App.jsx` unless the Node explicitly targets it.

### Architecture Guardrails

- TODO: 列出架构约束。例：Do not introduce unnecessary third-party npm dependencies.
- TODO: 列出核心哲学约束。例：Do not bypass the reducer or weaken state constraints.
- TODO: 列出数据约束。例：Do not modify seed data without explicit owner approval.

### Four Inviolable Rules

TODO: 定义 4 条不变量（参考上方示例格式）：

| Rule | Location | What it protects |
|------|----------|-----------------|
| TODO | TODO | TODO |
| TODO | TODO | TODO |
| TODO | TODO | TODO |
| TODO | TODO | TODO |

### Output Discipline

- Before writing any code, recite the constraints in 5 bullets.
- After completing the Node, output only the result.
- Do not fabricate verification results.
