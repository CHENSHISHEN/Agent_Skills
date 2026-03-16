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

## 目录结构

```
Agent_Skills/
├── README.md                    # 项目说明
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