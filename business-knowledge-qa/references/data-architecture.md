# HIIC数仓架构概览

## 5层架构设计

### ODS - 贴源库 (Operational Data Store)
- **职责**: 原始数据落地，与业务系统保持1:1关系
- **数据特点**: 原始、不做清洗、保持业务系统原貌
- **更新策略**: 增量/全量同步
- **示例**: `ods_enterprise_basic_info`

### DWD - 基础库 (Data Warehouse Detail)
- **职责**: 数据清洗、标准化、脱敏、统一编码
- **数据特点**: 清洁、唯一、原子粒度
- **关键工作**:
  - 字段命名规范化
  - 数据类型统一
  - 枚举值标准化
  - 主键数据去重
- **示例**: `dwd_enterprise_base_info_df`

### DWT - 要素主题库 (Data Warehouse Topic)
- **职责**: 星型/雪花模型建模，指标与维度体系化
- **数据特点**:
  - **事实表** (fact_*): 业务过程的度量记录
  - **维度表** (dim_*): 描述性属性，采用SCD Type-1/2
  - **桥接表** (bridge_*): N:M关系处理
  - **支撑表** (og_*): 1:1大文本分离
- **设计原则**:
  - 使用xxHash64生成代理键 (sk_*)
  - 事实表主键为pk_*，维度表主键为bk_*
  - 维度表之间不能直接JOIN，通过桥接表
  - 所有表必须有全量分区
- **示例**:
  - `fact_investment_event` - 投融资事件事实表
  - `dim_enterprise` - 企业维度表
  - `bridge_enterprise_shareholder_relation` - 企业股东关系桥接表

### DWS - 公共汇总库 (Data Warehouse Summary)
- **职责**: 场景化宽表、预聚合，加速查询
- **数据特点**:
  - 粒度 >= DWT层（不能更细）
  - 多表JOIN形成宽表
  - 面向具体业务场景
- **命名规范**: `dws_<域>_wide_<业务对象>_<后缀>`
- **示例**: `dws_enterprise_profile_wide_df` - 企业画像宽表

### ADS - 应用专题库 (Application Data Store)
- **职责**: 最终交付层，面向前端/API
- **数据特点**:
  - 只读DWS层（特殊大字段除外）
  - 直接面向应用需求
  - 轻度聚合
- **命名规范**: `ads_<应用>_<主题>_<后缀>`
- **示例**: `ads_search_report_wide_df` - 搜索报表宽表

## 10大核心主题域

1. **ORGANIZATION** - 机构主题（企业、高校、机构）
2. **PATENT** - 专利主题
3. **CAPITAL** - 投融资主题
4. **POLICY** - 政策主题
5. **INNOVATION_CARRIER** - 创新载体主题
6. **RESEARCH_MATERIAL** - 科研材料主题
7. **PROJECT** - 项目主题
8. **LABEL** - 标签主题
9. **TALENT** - 人才主题
10. **PUBLIC_OPINION** - 舆情主题

## 技术栈

- **计算引擎**: Apache Hive 3.1.0 + Tez
- **存储格式**: ORC + zlib压缩
- **分桶策略**: 64桶（大表）
- **分区策略**: 默认按日(dt=yyyyMMdd)，月表按月(dt=yyyyMM)
- **UDF库**: shared_udf(预生产) / shared_udf_prod(生产)

## 数据血缘关系

```
ODS (原始)
  ↓ 清洗去重
DWD (清洁明细)
  ↓ 维度建模
DWT (星型模型) ← 核心指标定义层
  ↓ 场景汇总
DWS (宽表)
  ↓ 应用交付
ADS (应用层)
```

## 关键设计约束

- **禁止UPDATE/DELETE**: 所有三层(DWT/DWS/ADS)只读，通过重跑或SCD处理变更
- **代理键标准化**: 所有维度表必须使用`shared_udf_prod.xxhash()`
- **外键处理失败**: 维度未匹配时，代理键 = xxhash(业务键) * -1
- **维度解耦**: 实体维度间禁止直接JOIN，必须通过桥接表
- **大文本分离**: 超过1KB的文本字段(摘要、内容)必须放入支撑表(og_*)
