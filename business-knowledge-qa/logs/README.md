# 学习日志目录

本目录用于存储 `business-knowledge-qa` skill 的学习历史记录。

## 日志文件格式

日志文件采用 JSONL 格式（每行一个 JSON 对象），文件名为 `learning_history.jsonl`

## 日志结构

每条日志记录包含以下字段：

```json
{
  "session_id": "20250130_001",
  "timestamp": "2025-01-30T12:00:00",
  "mode": "天马行空式业务指标提问",
  "topic": "企业规模判断",
  "total_score": 85,
  "weak_points": ["数仓分层思维", "字段取数逻辑"],
  "user_feedback": {
    "difficulty": 5,
    "relevance": 9,
    "hint_quality": 8,
    "feedback_quality": 9
  }
}
```

## 字段说明

| 字段 | 说明 |
|------|------|
| session_id | 会话唯一标识（格式：YYYYMMDD_序号） |
| timestamp | 会话时间戳 |
| mode | 提问模式（天马行空式/表知识考核/场景化提问） |
| topic | 考核主题或表名 |
| total_score | 总分（0-100） |
| weak_points | 薄弱环节列表 |
| user_feedback | 用户对AI提问的评分 |

## 用途

1. **追踪学习进度**：记录每次考核的结果，了解学习进展
2. **识别薄弱环节**：统计分析找出高频薄弱点
3. **自适应学习**：根据历史数据调整提问策略
4. **学习路径推荐**：基于历史记录推荐下一步学习内容

## 维护建议

- 定期查看日志，分析学习趋势
- 根据薄弱环节制定针对性学习计划
- 如果需要重新开始学习，可以备份并清空日志文件
