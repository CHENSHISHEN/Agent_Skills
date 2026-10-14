# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

HIIC-数据仓库 is an enterprise-level financial research data warehouse using Kimball dimensional modeling methodology. The project implements a 5-layer architecture (ODS-DWD-DWT-DWS-ADS) covering 10 core domains including organizations, patents, investments, policies, innovation carriers, research materials, projects, and labels.

**Tech Stack**: Apache Hive + Tez execution engine, ORC format with zlib compression, 64-bucket clustering

**Key Scale**: 2,493 Git-managed files, 1,000+ SQL files, 10 core subject domains

## Repository Structure

```
hiic-datawarehouse/
├── 01-贴源库-ODS/              # Operational Data Store (raw data)
├── 02-基础库-DWD/              # Data Warehouse Detail (cleaned data)
├── 03-要素主题库-DWT/           # Data Warehouse Topic (star schema baseline)
│   ├── 公共维度库-DIM_PUBLIC/   # Public dimensions (location, currency, language)
│   ├── 机构主题-DWT_ORGANIZATION/
│   ├── 专利主题-DWT_PATENT/
│   ├── 投融资主题-DWT_CAPTIAL/
│   └── [8 more subject domains]
├── 04-公共汇总库-DWS/           # Data Warehouse Summary (wide tables/aggregations)
├── 05-应用专题库-ADS/           # Application Data Store (delivery layer)
├── 06-公共函数-UDF/             # User-defined functions (shared_udf/shared_udf_prod)
├── 07-辅助脚本/                 # Validation and consistency check scripts
└── 08-工具插件/                 # Agent Skills Hub for reusable agent skills
```

## Core Architectural Principles

### Layer Responsibilities (Critical)

- **DWT (要素主题库)**: Star/snowflake schema with fact tables (center), dimension tables (SCD Type-1/2), and bridge tables for N:M relationships. Primary source of truth for metrics and dimensions.
- **DWS (公共汇总库)**: Scenario-oriented wide tables for query acceleration. Must have granularity >= DWT (never more granular).
- **ADS (应用专题库)**: Final delivery layer for frontend/API. **Read-only** from DWS; direct DWT/DWD access only for whitelisted large fields (abstracts, content) via special exception.

### Key Design Rules (From 主题库设计规范.md)

1. **Surrogate Keys**: All dimension tables use 64-bit xxhash surrogate keys (`sk_*` prefix) generated via `shared_udf_prod.xxhash()`
2. **Primary Key Naming**: Fact/bridge tables use `pk_*`, dimension/support tables use `bk_*`
3. **Foreign Key Handling**: When foreign key fails to match, multiply by -1: `sk_id = CASE WHEN dim.sk_id IS NULL THEN xxhash(id) * -1 ELSE dim.sk_id END`
4. **Dimension Decoupling**: Entity dimensions must NOT join directly; use bridge tables
5. **Full Partition Requirement**: All DWT tables must have full partitions (极小码表 can apply for exception)
6. **No UPDATE/DELETE**: All three layers (DWT/DWS/ADS) are read-only; changes via rerun or SCD
7. **Partition Strategy**: Default `dt STRING (yyyyMMdd)`, monthly tables use `yyyyMM`, retain 7 days default

### Table Type Naming

| Type | Prefix | Example | Primary Key |
|------|--------|---------|-------------|
| Fact Table | `fact_` | `fact_investment_event` | `pk_...` |
| Dimension Table | `dim_` | `dim_enterprise` | `bk_...` |
| Bridge Table | `bridge_` | `bridge_investment_investor` | `pk_...` |
| Support Table | `og_` | `og_patent_text` | `bk_...` |
| DWS Wide Table | `dws_<domain>_wide` | `dws_enterprise_profile_wide` | `pk_...` |
| ADS Table | `ads_<app>_<topic>_wide` | `ads_search_report_wide` | inherits source |

## SQL File Conventions

### File Naming Pattern

SQL files follow: `[表类型]-[中文表名]-[database.table_name].sql`

Examples:
- `事实表-企业上市过程-dwt_organization_prod.fact_enterprise_listing_process_di.sql`
- `维度表-机构信息-dwt_organization_prod.dim_organization_df.sql`
- `桥接表-企业股东关系-dwt_organization_prod.bridge_enterprise_shareholder_relation_df.sql`

Suffix indicates update strategy:
- `_df`: Full load (全量)
- `_di`: Incremental load (增量)
- `_scd2`: SCD Type-2 (拉链表)
- `_mf`: Materialized view (物化视图)
- `_wf`: Full load without partition (无分区全量)

### SQL File Template Structure

Every SQL file follows this pattern:

```sql
-- Hive/Tez performance parameters
SET hive.exec.dynamic.partition = true;
SET hive.exec.dynamic.partition.mode = nonstrict;
SET tez.grouping.min-size=134217728;
SET tez.grouping.max-size=1073741824;
SET hive.exec.reducers.bytes.per.reducer=10737418240;
SET hive.exec.reducers.max=64;
SET tez.am.grouping.split-count=64;
SET hive.map.aggr=true;
SET hive.optimize.sort.dynamic.partition=true;
SET hive.exec.compress.intermediate=true;

-- CREATE TABLE DDL
CREATE TABLE IF NOT EXISTS [database].[table_name] (
    pk_field_id              STRING    COMMENT '主键',
    sk_dimension_id          BIGINT    COMMENT '代理键-维度ID',
    ...
    create_time              TIMESTAMP COMMENT '数据创建时间',
    update_time              TIMESTAMP COMMENT '数据更新时间'
)
COMMENT '[表类型]-[中文表名]'
PARTITIONED BY (dt STRING COMMENT '分区列-日期，格式yyyyMMdd')
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'zlib');

-- INSERT OVERWRITE data loading logic
INSERT OVERWRITE TABLE [database].[table_name] PARTITION (dt)
SELECT
    ...
    date_format(current_date(), 'yyyyMMdd') AS dt
FROM [source_table];
```

## Common Development Commands

### Schema Validation

```bash
# Validate table consistency between SQL filenames and CREATE TABLE statements
python3 07-辅助脚本/check_table_consistency.py

# Compare PDMA JSON model with SQL implementation (all layers)
python3 07-辅助脚本/validate_schema.py

# Validate specific layer only
python3 07-辅助脚本/validate_schema.py --layer dwt
python3 07-辅助脚本/validate_schema.py --layer dws,ads
```

### Agent Skills (08-工具插件/Agent Skills Hub)

```bash
# Initialize new skill
python3 08-工具插件/Agent\ Skills\ Hub/scripts/init_skill.py <skill-name> --path skills/public

# Validate skill structure
python3 08-工具插件/Agent\ Skills\ Hub/scripts/validate_skill.py <path/to/skill>

# Package skill for distribution
python3 08-工具插件/Agent\ Skills\ Hub/scripts/package_skill.py <path/to/skill> dist
```

### UDF Functions (06-公共函数-UDF)

Available UDFs in `shared_udf` (pre-prod) and `shared_udf_prod` (production):

- `shared_udf_prod.xxhash(string)`: Generate 64-bit surrogate key
- `shared_udf.array_struct_to_json(array<struct<>>)`: Convert struct array to JSON
- `shared_udf.extract_field_from_struct_array(array, field_name)`: Extract field from struct array
- `shared_udf.array_concat_multi(arr1, arr2, ..., [distinct])`: Concatenate arrays
- `shared_udf.array_distinct(array)`: Remove duplicates from array
- `shared_udf.string_clean(string)`: Clean empty strings/null JSON objects
- `shared_udf.json_parse(json_string, schema)`: Parse JSON to typed data
- `shared_udf.standardize_indicator(value, min, max, [is_positive], [use_log], [base])`: Normalize indicator
- `shared_udf.calculate_indicator_score(score, lower_base, max, min, [upper_base])`: Calculate indicator score with floor
- `shared_udf.industry_basis_service(eid, task_id, [url], [app], [key])`: Call industry API
- `shared_udf.date_range_to_now(start_date, [end_date], mode)`: Generate date range sequence

## Data Modeling Methodology

### Dimensional Modeling Process (from 总体设计方式.md)

When designing new DWT tables, follow this thought process:

1. **Identify Business Process**: What event does this data record? (application, investment, publication, etc.)
2. **Determine Fact vs Dimension**:
   - Fact: Continuously growing, numeric measures, has event time
   - Dimension: Descriptive attributes, relatively stable, shared across processes
3. **Define Granularity**: What does one row represent? (single event, daily snapshot, etc.)
4. **Identify Dimensions**: Use 5W1H (Who, What, When, Where, Why, How)
5. **Handle Relationships**:
   - 1:1 → Merge into fact table or 1:1 dimension
   - N:1 → Foreign key in fact table
   - N:M → Bridge table (e.g., patent-applicant, report-researcher)
6. **Design Measures**: Ensure additivity (fully, semi-additive, or non-additive)

### SCD (Slowly Changing Dimensions) Strategy

- **SCD Type-1**: Overwrite updates, no history (default for most dimensions)
- **SCD Type-2**: Preserve history with `scd_start_date`, `scd_end_date`, `is_current` fields

### Complex Relationship Patterns

**Multi-role participation** (e.g., investment institutions as lead/follow investor):
- Use separate participation dimension table with `role_type` field
- Link to both investment and exit events

**Multi-language support** (e.g., patent titles/abstracts):
- Main dimension table stores primary language
- Support table (`og_*`) stores multi-language text with `is_origin` flag

**Hierarchical structures** (e.g., 6-level industry chain):
- Wide table with `level_1_code/name` through `level_6_code/name` columns
- Supports drill-up/drill-down without recursive queries

## Important Design Documents

- `03-要素主题库-DWT/总体设计方式.md`: Complete dimensional modeling methodology
- `03-要素主题库-DWT/主题库设计规范.md`: Layer responsibilities, naming conventions, anti-patterns
- `03-要素主题库-DWT/机构主题-DWT_ORGANIZATION/设计输出/DWT设计蓝图.md`: Example design blueprint
- `06-公共函数-UDF/README.md`: Complete UDF reference with examples
- `07-辅助脚本/README_check_table_consistency.md`: Table naming validation guide
- `08-工具插件/Agent Skills Hub/skills/public/smart-data-query/SKILL.md`: Intelligent data querying skill

## Quality Checklist for New Tables

- [ ] File name matches CREATE TABLE statement (check with `check_table_consistency.py`)
- [ ] Table follows naming convention: `[prefix]_[domain]_[business_object]_[suffix]`
- [ ] Primary key uses correct prefix (`pk_` for fact/bridge, `bk_` for dimension/support)
- [ ] Surrogate keys (`sk_*`) use `shared_udf_prod.xxhash()` with -1 fallback
- [ ] Partition strategy follows standard (`dt STRING` with yyyyMMdd format)
- [ ] All columns have Chinese COMMENT
- [ ] Storage format is ORC with zlib compression
- [ ] Large text fields (>1KB) moved to separate 1:1 dimension table, not in fact table
- [ ] Bridge tables used for all N:M relationships (no direct dimension-to-dimension joins)
- [ ] Foreign key relationships documented in design blueprint
- [ ] DDL matches PDMA model file (check with `validate_schema.py`)
- [ ] ETL logic handles NULL values properly (especially for surrogate key lookups)
- [ ] Table positioned in correct layer (DWT for star schema, DWS for wide tables, ADS for delivery)

## Anti-Patterns to Avoid

- ❌ Putting large text (abstracts, content) in fact/DWS/ADS wide tables → causes IO bloat
- ❌ DWT star schema without unique primary key validation → causes double-counting/missing aggregation
- ❌ DWS/ADS cross-domain wide tables without granularity declaration → causes full table scans
- ❌ Massive number of tiny partitions → causes NameNode pressure, task explosion
- ❌ Direct dimension-to-dimension joins without bridge tables → violates dimensional modeling principles
- ❌ Using `ORDER BY 1/2/3` (column position) → prohibited for compatibility
- ❌ Subqueries in SELECT list or JOIN ... ON for older Hive versions → use CTEs instead

## Performance Optimization Guidelines

### Tez Parameters (Standard Header)

Every DWT/DWS/ADS SQL should include the standard Tez configuration block (see SQL template above).

### Partitioning Strategy

- Daily incremental tables: `dt=yyyyMMdd`, retain 7 days
- Monthly tables: `dt=yyyyMM`, retain 3 months
- Dimension tables: Full partition `dt=yyyyMMdd`, retain 7 days
- Static enum tables: No partition (极小码表 exception)

### Bucketing Strategy

Large tables use 64 buckets:
```sql
CLUSTERED BY (sk_entity_id) SORTED BY (sk_entity_id) INTO 64 BUCKETS
```

### Degenerate Dimensions

For low-cardinality attributes (<100 values), store directly in fact table instead of creating dimension tables:
- `disclosure_status` (披露状态)
- `role_type` (角色类型)
- `audit_result` (审核结果)

## Environment-Specific Notes

- **Pre-production**: `shared_udf` schema, `dwt_*_prod` databases
- **Production**: `shared_udf_prod` schema, `dwt_*_prod` databases
- **Hive Version**: MRS 3.x (Huawei cloud), compatible with Hive 3.1.0
- **Execution Engine**: Tez (not MapReduce)
- **Character Encoding**: UTF-8 throughout

## Getting Help

- Dimensional modeling questions: Refer to `03-要素主题库-DWT/总体设计方式.md`
- Design standards: Refer to `03-要素主题库-DWT/主题库设计规范.md`
- UDF usage: Refer to `06-公共函数-UDF/README.md`
- Schema validation: Use `07-辅助脚本/validate_schema.py --help`
- Data querying skill: Use `/skill` command with `smart-data-query` from Agent Skills Hub
