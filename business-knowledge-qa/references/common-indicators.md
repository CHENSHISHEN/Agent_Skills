# 通用业务指标字典

## 使用说明

本文档定义了HIIC数仓中常见的业务指标及其标准口径。当需要定义新指标时，优先参考本文档，确保指标口径一致性。

## 指标定义模板

每个指标包含以下要素：
- **指标名称**: 中英文标准名称
- **业务定义**: 指标的业务含义
- **计算公式**: SQL计算逻辑
- **数据来源**: 依赖的表和字段
- **取数范围**: 包含/不包含的数据
- **注意事项**: 特殊处理逻辑

## 一、企业基础指标

### 1.1 企业标识类

#### 企业ID (enterprise_id)
- **业务定义**: 企业的唯一业务标识符
- **数据来源**: DWD层的统一企业ID
- **注意事项**:
  - 全局唯一
  - 企业注销后ID不变
  - 不同分支机构有独立ID

#### 统一社会信用代码 (credit_code)
- **业务定义**: 18位的法人和其他组织统一社会信用代码
- **格式**: 18位字母数字组合
- **校验**: 第18位为校验码
- **取数范围**:
  - 包含: 最新有效的统一社会信用代码
  - 不包含: 历史变更过的旧代码

#### 企业状态 (enterprise_status)
- **业务定义**: 企业当前的工商登记状态
- **值域**:
  - `存续`: 正常经营
  - `在业`: 正常经营（部分地区）
  - `开业`: 正常经营（部分地区）
  - `注销`: 已注销
  - `吊销`: 营业执照被吊销
  - `停业`: 暂停营业
  - `清算`: 进入清算程序
- **取数逻辑**:
  ```sql
  -- 取最新状态
  SELECT status
  FROM dwd_enterprise_base_info
  WHERE enterprise_id = xxx
  ORDER BY update_time DESC
  LIMIT 1
  ```

### 1.2 企业生命周期类

#### 成立日期 (establishment_date)
- **业务定义**: 企业工商注册成立日期
- **数据来源**: 工商注册信息
- **注意事项**:
  - 一旦确定不再变化
  - 格式: yyyy-MM-dd

#### 企业年龄 (enterprise_age)
- **业务定义**: 从成立日期到当前日期的年数
- **计算公式**:
  ```sql
  FLOOR(DATEDIFF(current_date(), establishment_date) / 365)
  ```
- **注意事项**:
  - 按自然年计算（不足1年按0年计算）
  - 用于分析企业成熟度

#### 注册资本 (registered_capital)
- **业务定义**: 企业在工商登记的注册资本金额
- **单位**: 万元
- **数据类型**: DECIMAL(18,2)
- **取数范围**:
  - 包含: 实缴制、认缴制
  - 不包含: 减资后的历史注册资本
- **注意事项**:
  - 取最新注册资本
  - 2014年改革后从"实缴制"改为"认缴制"

#### 实缴资本 (paid_capital)
- **业务定义**: 股东实际缴纳的资本金额
- **单位**: 万元
- **取数逻辑**:
  ```sql
  SUM(paid_in_amount)
  FROM dwd_enterprise_shareholder_info
  WHERE enterprise_id = xxx
  ```

### 1.3 企业规模类

#### 员工数量 (employee_count)
- **业务定义**: 企业当前的在职员工总数
- **数据来源**: 企业年报、社保数据
- **取数逻辑**:
  ```sql
  -- 优先取最新年报数据
  COALESCE(
      (SELECT employee_count FROM annual_report WHERE enterprise_id = xxx ORDER BY year DESC LIMIT 1),
      (SELECT employee_count FROM social_security WHERE enterprise_id = xxx AND month = CURRENT_MONTH)
  )
  ```
- **注意事项**:
  - 数据更新频率: 每年（年报）或每月（社保）
  - 社保数据更准确但覆盖不全

#### 营业收入 (operating_revenue)
- **业务定义**: 企业主营业务收入与其他业务收入之和
- **单位**: 万元
- **取数逻辑**:
  ```sql
  SUM(revenue_amount)
  FROM fact_financial_statement
  WHERE enterprise_id = xxx
    AND statement_type = '利润表'
    AND item_name IN ('营业收入', '主营业务收入', '其他业务收入')
    AND year = 2023
  ```
- **注意事项**:
  - 仅包含已披露年报的企业
  - 数据滞后: 当年数据次年4-6月披露

#### 利润总额 (total_profit)
- **业务定义**: 企业在一定时期内实现的利润总额
- **单位**: 万元
- **取数逻辑**:
  ```sql
  SUM(revenue_amount - cost_amount)
  FROM fact_financial_statement
  WHERE enterprise_id = xxx
    AND statement_type = '利润表'
    AND item_name = '利润总额'
    AND year = 2023
  ```
- **计算口径**:
  - 利润总额 = 营业利润 + 营业外收入 - 营业外支出
  - 包含: 营业利润、投资收益、营业外收支
  - 不包含: 所得税费用

#### 净利润 (net_profit)
- **业务定义**: 企业扣除所有税费后的最终利润
- **单位**: 万元
- **计算公式**:
  ```sql
  利润总额 - 所得税费用
  ```
- **注意事项**:
  - 净利润 < 利润总额（除非有所得税返还）

### 1.4 企业标签类

#### 是否上市 (is_listed)
- **业务定义**: 企业是否在证券交易所上市
- **值域**: 'Y' / 'N'
- **判断逻辑**:
  ```sql
  CASE
    WHEN EXISTS (
      SELECT 1 FROM dim_listing_company
      WHERE sk_enterprise_id = xxx
    )
    THEN 'Y'
    ELSE 'N'
  END
  ```
- **注意事项**:
  - 包含: A股、港股、美股等
  - 不包含: 新三板、区域股权市场

#### 是否高新技术企业 (is_high_tech)
- **业务定义**: 企业是否获得国家高新技术企业认定
- **值域**: 'Y' / 'N'
- **判断逻辑**:
  ```sql
  CASE
    WHEN EXISTS (
      SELECT 1 FROM fact_enterprise_certification
      WHERE sk_enterprise_id = xxx
        AND certification_type = '高新技术企业'
        AND certification_status = '有效'
        AND end_date >= current_date()
    )
    THEN 'Y'
    ELSE 'N'
  END
  ```
- **注意事项**:
  - 高企证书有效期3年
  - 需复核认定资格

#### 是否专精特新 (is_specialized_refined)
- **业务定义**: 企业是否获得专精特新认定
- **值域**: 'Y' / 'N' / '省级' / '国家级'
- **判断逻辑**:
  ```sql
  CASE
    WHEN certification_level = '国家级' THEN '国家级'
    WHEN certification_level = '省级' THEN '省级'
    ELSE 'N'
  END
  ```

## 二、司法风险指标

### 2.1 案件数量类

#### 案件总数 (total_case_count)
- **业务定义**: 企业历史所有案件的总数量
- **取数逻辑**:
  ```sql
  COUNT(DISTINCT case_id)
  FROM fact_judicial_case
  WHERE sk_enterprise_id = xxx
  ```
- **注意事项**:
  - 去重以case_id为单位
  - 包含所有案件类型
  - 不区分案件状态

#### 未结案件数 (active_case_count)
- **业务定义**: 企业当前未审结的案件数量
- **取数逻辑**:
  ```sql
  COUNT(DISTINCT case_id)
  FROM fact_judicial_case
  WHERE sk_enterprise_id = xxx
    AND case_status IN ('审理中', '立案', '未结')
  ```
- **业务含义**:
  - 反映当前法律风险敞口
  - 用于风险预警

#### 被执行案件数 (execution_case_count)
- **业务定义**: 企业作为被执行人的案件数量
- **取数逻辑**:
  ```sql
  COUNT(DISTINCT execution_id)
  FROM fact_dishonesty_execution
  WHERE sk_enterprise_id = xxx
    AND role_type = '被执行人'
  ```

#### 失信案件数 (dishonesty_case_count)
- **业务定义**: 企业被列为失信被执行人的案件数量
- **俗称**: "老赖"记录
- **取数逻辑**:
  ```sql
  COUNT(DISTINCT dishonesty_id)
  FROM fact_dishonesty_execution
  WHERE sk_enterprise_id = xxx
    AND is_dishonesty = 'Y'
  ```

### 2.2 案件金额类

#### 案件总额 (total_case_amount)
- **业务定义**: 企业所有涉案案件的标的金额总和
- **单位**: 元
- **取数逻辑**:
  ```sql
  SUM(case_amount)
  FROM fact_judicial_case
  WHERE sk_enterprise_id = xxx
    AND case_status = '已结案'  -- 只统计已结案案件
  ```
- **注意事项**:
  - 只统计已结案案件（有明确金额）
  - 未结案案件金额不确定

#### 被执行金额 (execution_amount)
- **业务定义**: 企业被申请执行的标的金额
- **单位**: 元
- **取数逻辑**:
  ```sql
  SUM(execution_amount)
  FROM fact_dishonesty_execution
  WHERE sk_enterprise_id = xxx
    AND role_type = '被执行人'
  ```

### 2.3 案件特征类

#### 案件类型分布 (case_type_distribution)
- **业务定义**: 各类案件的数量分布
- **数据结构**: ARRAY<STRUCT<type, count>>
- **案件类型**:
  - 民事案件
  - 刑事案件
  - 行政案件
  - 执行案件
  - 仲裁案件
- **取数逻辑**:
  ```sql
  shared_udf.array_struct_to_json(
    COLLECT_LIST(
      NAMED_STRUCT('type', case_type, 'count', COUNT(*))
    )
  )
  FROM fact_judicial_case
  WHERE sk_enterprise_id = xxx
  GROUP BY case_type
  ```

#### 最后案件日期 (last_case_date)
- **业务定义**: 企业最近一次案件的发生日期
- **取数逻辑**:
  ```sql
  MAX(case_date)
  FROM fact_judicial_case
  WHERE sk_enterprise_id = xxx
  ```
- **业务用途**: 判断企业近期法律风险活跃度

## 三、知识产权指标

### 3.1 专利指标

#### 专利申请数 (patent_application_count)
- **业务定义**: 企业提交的专利申请总数量
- **取数逻辑**:
  ```sql
  COUNT(DISTINCT publication_id)
  FROM fact_patent_application
  WHERE sk_enterprise_id = xxx
  ```
- **注意事项**:
  - 包含: 发明专利、实用新型、外观设计
  - 去重以申请号为单位

#### 专利授权数 (patent_grant_count)
- **业务定义**: 企业获得授权的专利数量
- **取数逻辑**:
  ```sql
  COUNT(DISTINCT publication_id)
  FROM fact_patent_application
  WHERE sk_enterprise_id = xxx
    AND grant_status = '已授权'
  ```
- **注意事项**:
  - 仅统计已授权专利
  - 未授权申请不计入

#### 发明专利数 (invention_patent_count)
- **业务定义**: 企业获得的发明专利数量
- **价值**: 发明专利价值最高（保护20年）
- **取数逻辑**:
  ```sql
  COUNT(DISTINCT publication_id)
  FROM fact_patent_application
  WHERE sk_enterprise_id = xxx
    AND patent_type = '发明'
    AND grant_status = '已授权'
  ```

#### 专利被引次数 (patent_citation_count)
- **业务定义**: 企业专利被其他专利引用的总次数
- **业务含义**: 反映技术创新影响力
- **取数逻辑**:
  ```sql
  SUM(citation_count)
  FROM dws_patent_citations_wide
  WHERE sk_enterprise_id = xxx
  ```

### 3.2 软件著作权

#### 软件著作权数量 (software_copyright_count)
- **业务定义**: 企业登记的软件著作权数量
- **取数逻辑**:
  ```sql
  COUNT(DISTINCT copyright_id)
  FROM fact_software_copyright
  WHERE sk_enterprise_id = xxx
  ```

### 3.3 商标指标

#### 商标注册数 (trademark_registration_count)
- **业务定义**: 企业注册成功的商标数量
- **取数逻辑**:
  ```sql
  COUNT(DISTINCT trademark_id)
  FROM fact_trademark_registration
  WHERE sk_enterprise_id = xxx
    AND registration_status = '已注册'
  ```

## 四、投融姿指标

### 4.1 融资事件类

#### 融资轮次 (financing_round)
- **业务定义**: 企业当前的融资阶段
- **值域**:
  - 种子轮
  - 天使轮
  - Pre-A轮
  - A轮
  - B轮
  - C轮
  - D轮及以后
  - E轮及以后
  - Pre-IPO
  - IPO上市
  - 战略融资
  - 并购
- **取数逻辑**:
  ```sql
  -- 取最新融资轮次
  SELECT financing_round
  FROM fact_financing_event
  WHERE sk_enterprise_id = xxx
  ORDER BY announcement_date DESC
  LIMIT 1
  ```

#### 融资总额 (total_financing_amount)
- **业务定义**: 企业历史累计融资金额
- **单位**: 万元
- **取数逻辑**:
  ```sql
  SUM(financing_amount)
  FROM fact_financing_event
  WHERE sk_enterprise_id = xxx
    AND financing_status = '已完成'
  ```

#### 最新融资金额 (latest_financing_amount)
- **业务定义**: 企业最近一次完成的融资金额
- **取数逻辑**:
  ```sql
  financing_amount
  FROM fact_financing_event
  WHERE sk_enterprise_id = xxx
    AND financing_status = '已完成'
  ORDER BY announcement_date DESC
  LIMIT 1
  ```

### 4.2 估值指标

#### 企业估值 (enterprise_valuation)
- **业务定义**: 投资后估值
- **单位**: 万元
- **数据来源**: 融资事件披露
- **注意事项**:
  - 仅为融资时的估值
  - 非上市公司估值波动大
  - 数据不完整（很多未披露）

### 4.3 投资事件类

#### 对外投资企业数 (portfolio_company_count)
- **业务定义**: 企业作为投资方投资的企业数量
- **取数逻辑**:
  ```sql
  COUNT(DISTINCT sk_investee_id)
  FROM bridge_investment_relation
  WHERE sk_investor_id = xxx
  ```

#### 投资事件数 (investment_event_count)
- **业务定义**: 企业作为投资方的投资事件总数
- **取数逻辑**:
  ```sql
  COUNT(DISTINCT pk_investment_event_id)
  FROM fact_investment_event
  WHERE sk_investor_id = xxx
  ```

## 五、人才指标

### 5.1 人才数量类

#### 核心人才数量 (core_talent_count)
- **业务定义**: 企业拥有的核心人才数量
- **核心人才定义**:
  - 高级职称人员
  - 博士学历人员
  - 海外留学人员
  - 国家级人才计划入选者
- **取数逻辑**:
  ```sql
  COUNT(DISTINCT sk_talent_id)
  FROM bridge_organization_talent_relation
  WHERE sk_enterprise_id = xxx
    AND talent_level IN ('高级', '正高级', '国家级人才')
  ```

#### 研发人员数量 (rd_employee_count)
- **业务定义**: 企业研发部门人员数量
- **数据来源**: 企业年报、研发投入表
- **注意事项**:
  - 数据更新频率低（年报）
  - 覆盖不全（非上市企业可能未披露）

### 5.2 人才质量类

#### 研发人员占比 (rd_employee_ratio)
- **业务定义**: 研发人员数量占员工总数的比例
- **单位**: 百分比
- **计算公式**:
  ```sql
  ROUND(rd_employee_count / employee_count * 100, 2)
  ```

## 六、项目指标

### 6.1 项目数量类

#### 承担项目总数 (project_count)
- **业务定义**: 企业作为承担单位的项目总数
- **取数逻辑**:
  ```sql
  COUNT(DISTINCT project_id)
  FROM fact_project_participation
  WHERE sk_enterprise_id = xxx
    AND participation_role = '承担单位'
  ```

#### 国家级项目数 (national_project_count)
- **业务定义**: 企业承担的国家级项目数量
- **项目级别**:
  - 国家级: 国家重点研发计划、国家自然科学基金等
  - 省级: 省科技重大专项等
  - 市级: 市科技计划等

### 6.2 项目金额类

#### 项目总金额 (total_project_amount)
- **业务定义**: 企业承担项目的总资助金额
- **单位**: 万元
- **取数逻辑**:
  ```sql
  SUM(project_funding_amount)
  FROM fact_project_participation
  WHERE sk_enterprise_id = xxx
  ```

## 指标标准化原则

### 1. 口径统一
- 相同名称的指标，在不同表中计算口径必须一致
- 例如: `营业收入` 在所有DWS/ADS表中都使用相同定义

### 2. 可追溯
- 每个指标必须能追溯到DWT层事实表
- 指标定义文档化（本文档）

### 3. 可解释
- 指标命名清晰易懂
- 包含完整的业务定义和计算公式

### 4. 可验证
- 提供SQL计算公式
- 可以通过SQL验证正确性

### 5. 版本管理
- 指标定义变更需要记录版本
- 历史版本保留用于追溯

## 指标定义流程

### 新增指标时

1. **需求分析**:
   - 明确指标的业务含义
   - 确定指标的取数范围
   - 识别数据来源

2. **口径定义**:
   - 编写指标定义文档
   - 定义SQL计算公式
   - 说明注意事项

3. **评审**:
   - 业务评审: 确认业务含义
   - 技术评审: 确认数据来源和计算逻辑
   - 质量评审: 确认数据准确性

4. **实现**:
   - 在DWT/DWS层实现
   - 编写单元测试
   - 数据质量验证

5. **发布**:
   - 更新本文档
   - 通知数据使用者
   - 记录变更日志
