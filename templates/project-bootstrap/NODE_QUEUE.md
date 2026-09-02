# Node Queue — TODO: 填写项目名称

## TL;DR (update at sprint close)

- **Active node:** none — project initialized
- **Next:** TODO: 填写第一个任务
- **Tests:** TODO: X/X pass | **Head:** TODO: commit hash

---

Execution ledger. Each row is a discrete unit of work.

| Node | Description | Status | Gate |
|------|-------------|--------|------|
| Node-1 | TODO: 第一个节点描述。**不做：** TODO: 明确列出不做的事 | CANDIDATE | — |

---

## Node Definition Convention

When adding a new CANDIDATE or ACTIVE node, include a **不做** clause in the description:

```
**不做：** [具体禁止的行为] — prevents scope creep and AI misinterpretation.
```

Examples of good 不做 clauses:
- "不改核心 schema；不加第三方依赖"
- "不动核心入口文件；不改现有种子数据"
- "不引入新 npm 包；仅改目标 feature 文件"

The 不做 clause travels with the node so any agent reading the queue has the constraint without needing to check AGENTS.md first.

**Full node format (for CANDIDATE and ACTIVE nodes):**

```
| Node-X | [one-sentence description]. **输入：** [files AI needs to read, 1-3]. **输出：** [file(s) changed + one-line result]. **验收：** [binary condition: test pass / git diff / screenshot]. **不做：** [prohibited actions]. tool-hint: [codex-ok|claude-preferred|either] | CANDIDATE | — |
```

Minimum viable node (5 minutes to write): at least `不做` + `验收`. Without a binary acceptance condition, AI cannot self-verify completion.

**Optional: `tool-hint` field** — use when a premium AI tool (e.g. Claude Code) has limited usage and you want to preserve it for high-value sessions:

```
tool-hint: codex-ok          # single-file, clear spec, no governance reads needed
tool-hint: claude-preferred  # multi-file, needs governance context, first time in module, or strategic judgment required
tool-hint: either            # both work equally well for this node
```

When premium tool usage is running low: run `codex-ok` nodes in the cheaper tool first; save the premium tool for `claude-preferred` nodes. Advisory only — no enforcement.

---

## Gate Convention

Gates are external preconditions, not internal tasks. Format:

```
| Node-X | Description | ARMED | external condition to verify |
```

AI must not advance past a Gate without user confirmation that the condition is met.

---

## Semantic Boundaries (authoritative)

<!-- 在这里定义项目的语义边界（分层/标签结构自定，模板不预设具体项目分层） -->

| Layer | Name | Role |
|-------|------|------|
| TODO  | TODO | TODO |
