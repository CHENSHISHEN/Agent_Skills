# 协作规则（薄指针）

本项目有多 LLM 共享工作区。项目章程见 **`.agents/README.md`**，开始任何工作前先读它。

要点：
- 你的工作区：`.agents/workspaces/<本工具名>/`（如 claude 会话 → `claude/`）
- 被派了任务：读自己工作区的 `plan.md` → `status` 改 `in_progress` → 按计划干活
- 完成后：产出写入自己工作区的 `output.md`（结论先行，≤100 行）→ `status` 改 `done`
- 需要其他 agent 的成果：读对方工作区的 `output.md`；不要改别人的工作区
- 技术决策记录：`.agents/decisions.md`——跨会话生效的选型/约定按模板追加到末尾
- 任务发起与推进在对话中进行，主 agent 负责写 plan / 读 output / 归档
