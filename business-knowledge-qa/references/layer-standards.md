# 数仓各层标准规范

## DWT层 - 要素主题库标准

### 核心职责
- 采用Kimball维度建模方法论
- 构建星型/雪花模型
- 定义统一的指标口径
- 维度表的单一真相来源

### 表类型与命名规范

#### 1. 事实表 (Fact Table)
- **命名**: `fact_<业务对象>_<后缀>`
- **主键**: `pk_*` (primary key)
- **特征**:
  - 持续增长的度量记录
  - 包含数值型度量
  - 有明确的事件时间
  - 粒度：每次业务事件
- **示例**: `fact_investment_event_di`, `fact_judicial_case_df`

#### 2. 维度表 (Dimension Table)
- **命名**: `dim_<业务对象>_<后缀>`
- **主键**: `bk_*` (business key)
- **代理键**: `sk_*` (surrogate key)，使用xxhash64生成
- **特征**:
  - 描述性属性
  - 相对稳定
  - 跨业务过程共享
  - 采用SCD Type-1或Type-2
- **示例**: `dim_enterprise_df`, `dim_patent_publication_df`

#### 3. 桥接表 (Bridge Table)
- **命名**: `bridge_<关系描述>_<后缀>`
- **主键**: `pk_*`
- **特征**:
  - 处理N:M关系
  - 通常包含两个外键
  - 可能包含关系属性
- **示例**: `bridge_enterprise_shareholder_relation_df`

#### 4. 支撑表 (Support Table)
- **命名**: `og_<用途>_<后缀>` (og = other)
- **主键**: `bk_*`
- **特征**:
  - 1:1关系，大文本字段
  - 从主表分离以提升性能
  - 不直接参与宽表JOIN
- **示例**: `og_patent_text` - 存储专利摘要、权利要求书

### DWT层关键规则

1. **代理键生成规范**:
   ```sql
   sk_enterprise_id = CAST(shared_udf_prod.xxhash(enterprise_id) AS BIGINT)
   ```

2. **外键处理规范**:
   ```sql
   sk_enterprise_id = CASE
       WHEN dim.sk_enterprise_id IS NULL
       THEN shared_udf_prod.xxhash(src.enterprise_id) * -1
       ELSE dim.sk_enterprise_id
   END
   ```

3. **维度解耦原则**:
   - ❌ 禁止: 企业维度直接JOIN人才维度
   - ✅ 正确: 通过`bridge_enterprise_talent_relation`桥接

4. **分区要求**:
   - 所有表必须有全量分区 (dt='99991231')
   - 增量表保留7天，全量表保留3-7天

## DWS层 - 公共汇总库标准

### 核心职责
- 面向业务场景的宽表
- 加速查询性能
- 粒度不能比DWT更细

### 表命名规范
- **格式**: `dws_<域>_wide_<业务对象>_<后缀>`
- **示例**: `dws_enterprise_profile_wide_df`

### DWS层设计原则

1. **粒度原则**:
   - 粒度 >= DWT层
   - 明确声明"每行代表什么"

2. **JOIN规则**:
   - 只能JOIN DWT层表
   - 不能跨越不同域（特殊除外）
   - 控制JOIN表数量（通常<10张）

3. **宽表设计**:
   - 场景驱动：解决具体业务问题
   - 字段数量控制（建议<100字段）
   - 避免大文本字段

4. **更新策略**:
   - `_df`: 全量每日刷新
   - `_di`: 增量每日追加
   - `_mf`: 物化视图

### 典型DWS表类型

1. **画像宽表**: `dws_<entity>_profile_wide_df`
   - 企业画像: 基础信息+标签+指标
   - 人才画像: 教育经历+工作经历+成果

2. **事件宽表**: `dws_<event>_wide_<后缀>`
   - 投融资事件: 金额+轮次+投资方
   - 司法案件: 案件数+金额+类型

3. **汇总宽表**: `dws_<entity>_<metrics>_agg_<后缀>`
   - 企业汇总: 营收+利润+纳税

## ADS层 - 应用专题库标准

### 核心职责
- 面向前端/API的最终交付
- 只读DWS层
- 轻度聚合

### 表命名规范
- **格式**: `ads_<应用>_<主题>_<后缀>`
- **示例**: `ads_search_report_wide_df`

### ADS层设计原则

1. **数据来源**:
   - ✅ 默认: 只读DWS层
   - ❌ 特殊: DWT/DWD的大字段(摘要、内容)，需审批

2. **聚合程度**:
   - 轻度聚合（SUM、COUNT、AVG）
   - 避免复杂计算逻辑

3. **性能优化**:
   - 控制数据量
     - 预聚合
     - 过滤历史数据
     - 物化常用结果

## 字段设计通用规范

### 字段命名规范

| 字段类型 | 前缀 | 示例 | 说明 |
|---------|------|------|------|
| 主键 | pk_* | pk_investment_event_id | 事实表/桥接表主键 |
| 业务键 | bk_* | bk_enterprise_id | 维度表/支撑表业务主键 |
| 代理键 | sk_* | sk_enterprise_id | 维度表代理键 |
| 外键 | sk_* | sk_enterprise_id | 引用维度表的代理键 |
| 度量 | 直接命名 | amount, count | 数值型指标 |
| 退化维度 | 直接命名 | case_type | 低基数属性 |

### 字段注释规范

#### 基础注释
```sql
enterprise_name STRING COMMENT '企业名称'
```

#### 增强注释（关键字段）
```sql
total_revenue DECIMAL(18,2) COMMENT '营业收入(元) | SUM(revenue) FROM fact_financial_statement GROUP BY enterprise_id | 包含主营业务收入+其他业务收入'
```

#### 复杂字段注释结构
```
<中文名称> | <业务定义> | <取数逻辑> | <数据来源> | <注意事项>
```

### 分区字段规范

- **分区列名**: `dt`
- **数据类型**: `STRING`
- **格式**:
  - 日分区: `yyyyMMdd`
  - 月分区: `yyyyMM`
- **注释**: '分区列-日期，格式yyyyMMdd'

## 数据质量标准

### 唯一性
- 所有表必须有主键
- 主键唯一性由ETL保证

### 完整性
- 外键关联失败需标记（乘以-1）
- 关键字段非空校验

### 准确性
- 数值型度量合理范围检查
- 枚举值符合字典定义

### 一致性
- 相同指标在不同表口径一致
- 代理键在全库唯一

## SQL模板标准

所有SQL文件必须包含：

1. **性能参数块**:
```sql
SET hive.exec.dynamic.partition = true;
SET hive.exec.dynamic.partition.mode = nonstrict;
SET tez.grouping.min-size=134217728;
-- ... 其他标准参数
```

2. **CREATE TABLE DDL**:
   - 完整字段注释
   - 分区定义
   - ORC + zlib
   - 表注释

3. **INSERT OVERWRITE**:
   - 明确的分区逻辑
   - 清晰的数据来源
   - NULL值处理

## 文件命名规范

### 格式
```
<表类型>-<中文表名>-<database.table_name>.sql
```

### 后缀含义
- `_df`: 全量表 (full)
- `_di`: 增量表 (incremental)
- `_scd2`: 拉链表 (slowly changing dimension type 2)
- `_mf`: 物化视图 (materialized view)
- `_wf`: 无分区全表 (wide full)

### 示例
- `事实表-企业上市过程-dwt_organization_prod.fact_enterprise_listing_process_di.sql`
- `维度表-机构信息-dwt_organization_prod.dim_organization_df.sql`
