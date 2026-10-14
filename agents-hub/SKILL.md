---
name: agents-hub
description: 多LLM共享工作区协作层（.agents/）。让 Codex、Claude Code、Gemini CLI、Qwen 等多个 AI 编程助手在同一项目里共享项目章程、各自的工作区（plan 任务输入 / output 产出 / status 状态）和任务归档，通过文件交换输入输出协同开发。当用户想要初始化多agent协作环境、搭建共享记忆层/.agents/ 目录、建立项目章程或协作规范、给某个 agent 派任务/写 plan、查看或归档任务、让多个 LLM 在项目里共享上下文协同干活时，必须使用此 skill。触发词：初始化协作、共享记忆、项目章程、协作规范、多agent协作、多LLM协作、派任务、写plan、工作区、归档任务、.agents、共享上下文。即使用户只说"我想让codex和claude在同一个项目里干活"，也应触发。
---

# 多LLM共享工作区协作层

让多个 LLM CLI 在同一项目里通过文件交换输入输出：

- `.agents/README.md` — **项目章程**：项目概况、agent 角色分工、规范注意事项
- `.agents/workspaces/<agent>/` — **每个 agent 一个工作区**：
  - `plan.md`：任务输入（主 agent 写）
  - `output.md`：产出输出（本 agent 写）
  - `status`：`pending / in_progress / done`
- `.agents/archive.md` — **历史任务归档**：流水账（任务是啥 / agent 做了啥 / 最终状态）
- `.agents/decisions.md` — 技术决策记录（ADR）
- 根目录 `CLAUDE.md` / `AGENTS.md` / `GEMINI.md` — 薄指针，各 CLI 启动自动加载

定位：**轻量共享架构**。任务在对话里说明，agent 之间通过文件交流（plan 进、output 出），没有复杂的流转协议。价值：任何工具、任何新会话，冷启动即知道项目背景、自己的角色、该看哪个目录、之前干过什么。

## 能力一：初始化

用户说"初始化多agent协作 / 搭建共享记忆层"时：

1. 确认目标目录：默认当前项目根目录。意图不明（如 home 目录）时先问。
2. 运行初始化脚本（agent 名单可选，默认 codex claude gemini）：
   ```bash
   bash <本skill目录>/scripts/init.sh <目标目录> [agent1 agent2 ...]
   ```
   幂等保护：`.agents/` 已存在会拒绝，此时向用户确认是否真要重置。
3. 脚本成功后，用 Edit 定制 `.agents/README.md`：
   - 项目概况：名称、一句话定位、技术栈
   - 角色分工：每个 agent 的职责（与工作区目录一一对应）
   - 规范注意事项：编码规范、目录约定、禁止事项、测试/构建命令
4. 展示生成的目录树，说明交流机制一句话。
5. 若项目是 git 仓库，建议 `.agents/` 纳入版本控制；不是则不强制。

## 能力二：主 agent 派活（本会话是任务发起方时）

任务由用户在对话窗口说明，主 agent 负责落到文件：

1. **写 plan**：把任务写进目标 agent 的 `workspaces/<agent>/plan.md`——目标一句话、要改的文件给**绝对路径**、验收标准可勾选、边界写明"不要动什么"
2. **派发**：告诉用户启动该 agent（如 `claude -p "项目根目录是<绝对路径>。读 .agents/workspaces/claude/plan.md 并执行"`），或本会话直接执行该命令
3. **收活**：该 agent `status=done` 后读它的 `output.md`（+ git diff），据此推进下一步——满意就归档，不满意在 plan.md 批注区写明问题让它重做
4. **归档**：任务完结时，按模板把摘要（任务/agent/做了什么/最终状态）追加到 `archive.md` 末尾（编号 T-xxx 递增），然后重置该工作区（plan/output 恢复模板、status 回 pending）

## 能力三：执行 agent 干活（本会话被派了任务时）

发现 `workspaces/<本工具名>/plan.md` 已填写任务时：

1. 读 plan.md，`status` 改 `in_progress`
2. 严格按 plan 范围执行，遵守 README 章程规范
3. 需要其他 agent 的成果时，读对方的 `output.md`
4. 完成后写自己工作区的 `output.md`：**结论先行，≤100 行**（做了什么 / 改动文件清单 / 遗留问题 / 需主 agent 决策的点），`status` 改 `done`
5. 不改章程、归档和别人的工作区

## 设计原因

- **每 agent 一个目录**：输入输出天然隔离，多 agent 并行互不覆盖；交流=读对方 output
- **status 独立成文件**：扫一眼各目录 status 即知全局进度，不用读 plan/output 全文
- **章程只存稳定信息**：概况/角色/规范低频变化；任务内容在工作区，历史在 archive——README 不膨胀
- **归档是摘要不是全文**：3-5 行提炼，原文细节有 git 历史可查
- **output 限长**：读产出要花 token，冗长产出浪费额度
- **薄指针自动加载**：CLAUDE.md / AGENTS.md / GEMINI.md 是各 CLI 约定入口，零配置生效

## 附属文件

- `scripts/init.sh` — 幂等初始化（可选 agent 名单参数）
- `assets/` — 模板：`README.md`（章程）、`decisions.md`（ADR）、`archive.md`（归档）、`plan.md`、`output.md`、`POINTER.md`（薄指针，复制为三个入口文件）
