# 数仓命名规范

## 数据库命名规范

### 环境分层
- **预生产环境**: `dwt_<domain>_prod` (注意: prod后缀表示预生产)
- **生产环境**: `dwt_<domain>_prod` (与预生产相同)
- **共享库**: `shared_udf` / `shared_udf_prod`

### 主题域缩写
| 主题域 | 英文 | 缩写 | 数据库名示例 |
|-------|------|------|-------------|
| 机构 | ORGANIZATION | organization | dwt_organization_prod |
| 专利 | PATENT | patent | dwt_patent_prod |
| 投融资 | CAPITAL | capital | dwt_capital_prod |
| 政策 | POLICY | policy | dwt_policy_prod |
| 创新载体 | INNOVATION_CARRIER | innovation_carrier | dwt_innovation_carrier_prod |
| 科研材料 | RESEARCH_MATERIAL | research_material | dwt_research_material_prod |
| 项目 | PROJECT | project | dwt_project_prod |
| 标签 | LABEL | label | dwt_label_prod |
| 人才 | TALENT | talent | dwt_talent_prod |
| 舆情 | PUBLIC_OPINION | public_opinion | dwt_public_opinion_prod |

## 表命名规范

### 完整格式
```
<表类型>_<中文表名>_<database.table_name>.sql
```

### 表类型前缀

#### DWT层表类型

| 表类型 | 前缀 | 主键前缀 | 示例 |
|-------|------|---------|------|
| 事实表 | `fact_` | `pk_` | fact_investment_event |
| 维度表 | `dim_` | `bk_` | dim_enterprise |
| 桥接表 | `bridge_` | `pk_` | bridge_enterprise_shareholder_relation |
| 支撑表 | `og_` | `bk_` | og_patent_text |

#### DWS层表类型

| 表类型 | 格式 | 示例 |
|-------|------|------|
| 宽表 | `dws_<域>_wide_<业务对象>` | dws_enterprise_profile_wide_df |
| 汇总表 | `dws_<域>_agg_<业务对象>` | dws_enterprise_financial_agg_df |

#### ADS层表类型

| 表类型 | 格式 | 示例 |
|-------|------|------|
| 应用表 | `ads_<应用>_<主题>` | ads_search_enterprise_wide_df |
| 专题表 | `ads_<主题>_<分析>` | ads_risk_analysis_df |

### 更新策略后缀

| 后缀 | 含义 | 使用场景 | 分区策略 |
|------|------|---------|---------|
| `_df` | Full（全量表） | 维度表、快照事实表 | 每日全量，保留7天 |
| `_di` | Incremental（增量表） | 事务事实表 | 每日增量，保留7天 |
| `_scd2` | SCD Type 2（拉链表） | 需要保留历史的维度 | 拉链分区，保留3个月 |
| `_mf` | Materialized View（物化视图） | 高频查询的聚合表 | 按需刷新 |
| `_wf` | Wide Full（无分区全表） | 极小码表 | 无分区 |

### 命名示例

#### 正确示例
```
✓ 事实表-企业上市过程-dwt_organization_prod.fact_enterprise_listing_process_di.sql
✓ 维度表-机构信息-dwt_organization_prod.dim_organization_df.sql
✓ 桥接表-企业股东关系-dwt_organization_prod.bridge_enterprise_shareholder_relation_df.sql
✓ 公共宽表-企业画像-dws_hub.dws_enterprise_profile_wide_df.sql
✓ 多维分析_企业供应链分析-ads_multidim_analysis.ads_enterprise_supply_analysis_df.sql
```

#### 错误示例
```
✗ enterprise_fact_table.sql (缺少表类型前缀)
✗ dim_enterprise (缺少数据库名)
✗ 事实表.sql (缺少中文表名)
✗ fact_investment_event_df.sql (后缀位置错误，应在表名后)
✗ Fact_Investment_Event_DI.sql (使用大写和下划线分隔)
```

## 字段命名规范

### 字段类型前缀

| 字段类型 | 前缀 | 示例 | 说明 |
|---------|------|------|------|
| 主键（事实/桥接） | `pk_` | pk_investment_event_id | Primary Key |
| 业务键（维度/支撑） | `bk_` | bk_enterprise_id | Business Key |
| 代理键 | `sk_` | sk_enterprise_id | Surrogate Key (xxHash64) |
| 外键 | `sk_` | sk_enterprise_id | 引用维度表的代理键 |

### 度量字段命名

#### 金额类
- 后缀: `_amount`, `_fee`, `_price`, `_value`
- 示例: `investment_amount`, `registration_fee`

#### 数量类
- 后缀: `_count`, `_quantity`, `_num`, `_ratio`
- 示例: `patent_count`, `employee_quantity`

#### 时间类
- 后缀: `_date`, `_time`, `_year`, `_month`
- 示例: `establishment_date`, `listing_year`

#### 标识类
- 前缀: `is_`, `has_`
- 示例: `is_listed`, `has_patent`

### 维度属性命名

#### 基础属性
- 直接使用业务术语: `name`, `code`, `type`, `level`
- 示例: `enterprise_name`, `industry_code`, `case_type`

#### 层次结构
- 使用级别前缀: `level_1_`, `level_2_`, `level_3_`
- 示例: `level_1_industry_code`, `level_2_industry_name`

#### 多值属性
- 使用数组类型或后缀: `_list`, `_array`
- 示例: `industry_list`, `investor_array`

### 布尔值命名规范

| 含义 | 命名 | 值域 |
|------|------|------|
| 是否XX | `is_xxx` | 'Y'/'N' 或 1/0 |
| 有无XX | `has_xxx` | 'Y'/'N' 或 1/0 |
| XX状态 | `xxx_status` | 枚举值 |

### 日期时间字段命名

| 字段类型 | 命名 | 示例 |
|---------|------|------|
| 业务日期 | `<事件>_date` | registration_date, listing_date |
| 业务时间 | `<事件>_time` | create_time, update_time |
| 年份 | `<事件>_year` | establishment_year |
| 月份 | `<事件>_month` | listing_month |
| 技术时间戳 | `<动作>_time` | create_time, update_time, etl_time |

### 字段长度规范

| 数据类型 | 长度 | 使用场景 |
|---------|------|---------|
| STRING | 32 | ID、代码类 |
| STRING | 64 | 名称、短文本 |
| STRING | 128 | 描述、地址 |
| STRING | 255 | 长文本 |
| STRING | 2000+ | 超长文本（应放入支撑表） |
| BIGINT | - | 代理键、主键、计数 |
| DECIMAL(18,2) | - | 金额类 |
| DECIMAL(10,4) | - | 比率、百分比 |

## 分区字段命名

### 标准分区
```sql
PARTITIONED BY (dt STRING COMMENT '分区列-日期，格式yyyyMMdd')
```

### 二级分区（特殊情况）
```sql
PARTITIONED BY (
    dt STRING COMMENT '一级分区-日期，格式yyyyMMdd',
    region STRING COMMENT '二级分区-地区'
)
```

## 常用业务对象命名

### 企业相关
```
enterprise        - 企业
listing_company   - 上市企业
branch            - 分支机构
shareholder       - 股东
investor          - 投资方
```

### 人才相关
```
talent            - 人才
researcher        - 研究人员
inventor          - 发明人
author            - 作者
```

### 专利相关
```
patent            - 专利
publication       - 公开/公告
citation          - 引用
family            - 专利族
application       - 申请
```

### 投融资相关
```
investment        - 投资/融资
funding           - 融资
exit              - 退出
ipo               - IPO上市
```

### 项目相关
```
project           - 项目
project_brief     - 项目简报
research_task     - 研究任务
```

### 司法相关
```
case              - 案件
lawsuit           - 诉讼
court             - 法院
judgment          - 判决
execution         - 执行
dishonesty        - 失信
```

## SQL文件命名模板

### 下载SQL文件命名
```
<表类型>-<中文表名>-<database.table_name>.sql
```

### 示例库
```
# DWT层
事实表-投资事件-dwt_capital_prod.fact_investment_event_di.sql
维度表-企业信息-dwt_organization_prod.dim_enterprise_df.sql
桥接表-企业股东关系-dwt_organization_prod.bridge_enterprise_shareholder_relation_df.sql
支撑表-专利文本-dwt_patent_prod.og_patent_text_df.sql

# DWS层
公共宽表-企业画像-dws_hub.dws_enterprise_profile_wide_df.sql
公共宽表-人才画像-dws_hub.dws_talent_profile_wide_df.sql
汇总表-企业财务汇总-dws_hub.dws_enterprise_financial_agg_df.sql

# ADS层
多维分析_企业供应链分析-ads_multidim_analysis.ads_enterprise_supply_analysis_df.sql
多维分析_企业风险评估-ads_risk_analysis.ads_enterprise_risk_assessment_df.sql
```

## 特殊命名约定

### 保留字
避免使用Hive保留字作为字段名：
```
❌ order, group, date, timestamp, user
✅ order_type, group_id, business_date, event_time, user_id
```

### 缩写使用
| 完整词 | 推荐缩写 | 不推荐 |
|-------|---------|--------|
| information | info | inf |
| organization | org | org |
| identification | id | ident |
| registration | reg | regist |
| description | desc | descr |
| amount | amt | amnt |
| quantity | qty | quant |

### 命名一致性
同一概念在整个数仓中使用相同命名：
```
✓ 企业ID统一使用: enterprise_id
✗ 混用: company_id, corp_id, ent_id

✓ 日期统一使用: _date 后缀
✗ 混用: _dt, _day, time
```

## 检查清单

创建新表时，检查命名规范：

- [ ] 数据库名符合 `<dwt/dws/ads>_<主题域>` 格式
- [ ] 表名包含正确的前缀 (`fact_`/`dim_`/`bridge_`/`og_`/`dws_`/`ads_`)
- [ ] 主键使用正确前缀 (`pk_`/`bk_`)
- [ ] 代理键使用 `sk_` 前缀
- [ ] 更新策略后缀正确 (`_df`/`_di`/`_scd2`/`_mf`)
- [ ] 字段名使用小写和下划线
- [ ] 字段名避免保留字
- [ ] 金额字段使用 `_amount` 后缀
- [ ] 数量字段使用 `_count` 或 `_quantity` 后缀
- [ ] 布尔字段使用 `is_` 或 `has_` 前缀
- [ ] 日期字段使用 `_date` 后缀
- [ ] SQL文件名符合 `<表类型>-<中文表名>-<database.table_name>.sql` 格式
