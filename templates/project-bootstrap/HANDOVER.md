# HANDOVER

## SNAPSHOT

<!-- Update these three lines every session before closing. -->
- **Last updated:** TODO: 填写日期
- **Tests:** TODO: 填写测试数。例：35/35 pass (`npm test`)
- **Head commit:** TODO: 运行 `git log --oneline -1` 填写 hash + message

## HANDOVER WRITING RULES (for all AI agents updating this file)

- **代码修复必须写 commit hash，不能只写描述。** 格式：`(commit \`abc1234\`)` 紧跟在修复摘要后。无 hash = 无法验证是否已合并。
- 每次 session 结束前必须更新 SNAPSHOT 区块（日期、测试数、head commit）。
- 如果 HANDOVER 与 NODE_QUEUE.md 或代码状态冲突，以代码为准，更新 HANDOVER，不得反向。

## DEAD ENDS (already tried or evaluated — read WHY before proposing again)

**写入标准（三条都满足才写入）：**
1. 具体评估或尝试过——不是「感觉不好」，是有过实质讨论或实现
2. 拒绝理由与这个项目的当前约束绑定——是「在这个规模/阶段」下的判断，不是普世规律
3. 能写出重开条件——写不出说明还没想清楚

**格式：** 为什么拒绝 + ADR 指针（或说明无 ADR）+ 重开条件

---

<!-- 在这里添加项目的 DEAD ENDS -->

## INVARIANTS

<!-- 在这里列出项目的不变量 -->
- TODO: 技术栈（例：Stack: React 18 + Vite + Tailwind CSS）
- Keep diffs minimal and node-scoped.
- TODO: 核心文件约束（例：Do not modify `src/App.jsx` unless the active node explicitly requires it）
- Treat `governance/` as the project constitution and `NODE_QUEUE.md` as the canonical task queue.

## VOLATILE STATE

### Completed this sprint

<!-- 在这里记录本 sprint 完成的工作 -->

### Open audit items

<!-- 非阻塞的已知问题 -->

### Key decisions locked (do not relitigate)

<!-- 已锁定的决策，防止重复讨论 -->

## ACTIVE NODE

**No active node.** Project initialized.

## NEXT EXECUTION

**TODO:** 填写第一个任务或节点。

## OPEN QUESTIONS

<!-- 待解决的问题 -->
