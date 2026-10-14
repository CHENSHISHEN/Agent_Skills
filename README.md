# Agent Skills

Claude Code Agent 技能集合，用于扩展 AI 助手的专业能力。

## 技能列表

### business-knowledge-qa

数仓业务知识智能考核与学习助手。

**核心功能：**
- 天马行空式业务指标提问：不依赖具体表名，通过业务场景测试用户理解
- 自适应表知识考核：根据表复杂度智能调整问题数量和深度
- 场景化学习：基于实际业务场景建立认知
- 双向评分机制：AI评分 + 用户评分
- 学习日志追踪：记录历史，识别薄弱环节

**使用场景：**
- 数仓开发人员知识考核
- 业务指标体系学习
- 表结构熟悉训练

详见 [business-knowledge-qa/SKILL.md](./business-knowledge-qa/SKILL.md)

### agents-hub

多LLM共享工作区协作层。

**核心功能：**
- 项目章程：项目概况、agent 角色分工、规范注意事项，所有 LLM 会话启动自动加载
- 每 agent 一个工作区：plan.md（任务输入）/ output.md（产出输出）/ status（状态）
- 文件即交流：主 agent 写 plan 派活，执行 agent 写 output 交活，互相读对方产出
- 历史任务归档：T-xxx 流水账（任务是什么 / agent 做了什么 / 最终状态）
- 技术决策记录：跨会话生效的选型与约定（ADR）

**使用场景：**
- 一个项目里多个 AI 编程助手（Codex / Claude Code / Gemini CLI / Qwen）协同开发
- 主 agent 拆任务派活，节省贵模型额度
- 跨会话、跨工具共享项目上下文与决策记忆

详见 [agents-hub/SKILL.md](./agents-hub/SKILL.md)

## 目录结构

```
Agent_Skills/
├── README.md                    # 项目说明
├── agents-hub/                  # 多LLM共享工作区协作技能
│   ├── SKILL.md                 # 技能定义文件
│   ├── assets/                  # 模板（章程/ADR/归档/plan/output/薄指针）
│   └── scripts/
│       └── init.sh              # 幂等初始化脚本
└── business-knowledge-qa/       # 数仓业务知识考核技能
    ├── SKILL.md                 # 技能定义文件
    ├── references/              # 参考知识库
    │   ├── project-overview.md
    │   ├── data-architecture.md
    │   ├── layer-standards.md
    │   ├── naming-conventions.md
    │   ├── dimension-modeling.md
    │   ├── common-indicators.md
    │   ├── 主题库设计规范.md
    │   └── 总体设计方式.md
    └── logs/                    # 学习日志
        └── learning_history.jsonl
```

## 如何使用

在 Claude Code 中通过 Skill 工具调用：

```
/business-knowledge-qa
```

或直接描述需求，如：
- "考核我对企业规模判断的业务知识"
- "帮我学习企业画像宽表"
- "基于风险评估场景提问我"