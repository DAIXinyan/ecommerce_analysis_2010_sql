CREATE DATABASE ecommerce_analysis_2010;
USE ecommerce_analysis_2010;
# 创建表结构
CREATE TABLE online_retail (
    Invoice VARCHAR(20),
    StockCode VARCHAR(20),
    Description TEXT,
    Quantity INT,
    InvoiceDate DATETIME,
    Price DECIMAL(10,2),
    Customer_ID VARCHAR(20),
    Country VARCHAR(50)
);

# 数据质量检查
SELECT COUNT(*) FROM online_retail;
SELECT * FROM online_retail LIMIT 10;
SHOW COLUMNS FROM online_retail;

#检查异常值情况
SELECT
    COUNT(*) - COUNT(customer_ID) as missing_customer,
    COUNT(*) - COUNT(Description) as missing_desc,
    COUNT(*) - COUNT(InvoiceDate) as missing_date
FROM online_retail;

SELECT
    'Negative Quantity' as issue,
    COUNT(*) as count
FROM online_retail
WHERE Quantity < 0;

SELECT
    'Invalid Price' as issue,
    COUNT(*) as count
FROM online_retail
WHERE Price <= 0;

SELECT
    'Cancelled Orders' as issue,
    COUNT(*) as count
FROM online_retail
WHERE Invoice LIKE 'C%';

# 查看数据时间范围
SELECT
    MIN(InvoiceDate) as earliest_date,
    MAX(InvoiceDate) as latest_date
FROM online_retail;
#基本业务指标
SELECT
    COUNT(DISTINCT Customer_ID) as total_customers,
    COUNT(DISTINCT Invoice) as total_orders,
    SUM(Quantity * Price) as total_revenue,
    ROUND(SUM(Quantity * Price) / COUNT(DISTINCT Invoice), 2) as avg_order_value
FROM online_retail;

# 计算RFM值
CREATE VIEW rfm_base AS
SELECT
    customer_ID,
    DATEDIFF(
        (SELECT MAX(InvoiceDate) FROM online_retail),
        MAX(InvoiceDate)
    ) as recency, # R：最近一次消费距离今天的天数
    COUNT(DISTINCT Invoice) as frequency, # F：订单数
    SUM(Quantity * Price) as monetary # M：总消费金额
FROM online_retail
GROUP BY customer_ID;

#分布情况
SELECT
    ROUND(AVG(recency), 1) as avg_recency,
    ROUND(AVG(frequency), 1) as avg_frequency,
    ROUND(AVG(monetary), 2) as avg_monetary,
    MIN(recency) as min_recency,
    MAX(recency) as max_recency,
    MIN(frequency) as min_frequency,
    MAX(frequency) as max_frequency,
    MIN(monetary) as min_monetary,
    MAX(monetary) as max_monetary
FROM rfm_base;

#用五分制给用户rfm打分
CREATE VIEW rfm_scores AS
SELECT
    customer_ID,
    recency,
    frequency,
    monetary,
    -- R分：越近越高
    NTILE(5) OVER (ORDER BY recency DESC) as r_score,
    -- F分：越高越高
    NTILE(5) OVER (ORDER BY frequency) as f_score,
    -- M分：越高越高
    NTILE(5) OVER (ORDER BY monetary) as m_score
FROM rfm_base;

#查看打分分布
SELECT
    r_score,
    COUNT(*) as user_count,
    ROUND(AVG(recency), 1) as avg_recency
FROM rfm_scores
GROUP BY r_score
ORDER BY r_score;

SELECT
    f_score,
    COUNT(*) as user_count,
    ROUND(AVG(frequency), 1) as avg_frequency
FROM rfm_scores
GROUP BY f_score
ORDER BY f_score;

SELECT
    m_score,
    COUNT(*) as user_count,
    ROUND(AVG(monetary), 2) as avg_monetary
FROM rfm_scores
GROUP BY m_score
ORDER BY m_score;

#用户分层
#计算各维度平均值+分类客户+建立view
CREATE VIEW user_segments AS
WITH avg_scores AS (
    SELECT
        AVG(r_score) as avg_r,
        AVG(f_score) as avg_f,
        AVG(m_score) as avg_m
    FROM rfm_scores
)
SELECT
    rs.customer_ID,
    rs.r_score,
    rs.f_score,
    rs.m_score,
    rs.recency,
    rs.frequency,
    rs.monetary,
    CASE
        WHEN rs.r_score > avg_r AND rs.f_score > avg_f AND rs.m_score > avg_m THEN '重要价值用户'
        WHEN rs.r_score > avg_r AND rs.f_score > avg_f AND rs.m_score <= avg_m THEN '一般价值用户'
        WHEN rs.r_score > avg_r AND rs.f_score <= avg_f AND rs.m_score > avg_m THEN '重要发展用户'
        WHEN rs.r_score > avg_r AND rs.f_score <= avg_f AND rs.m_score <= avg_m THEN '一般发展用户'
        WHEN rs.r_score <= avg_r AND rs.f_score > avg_f AND rs.m_score > avg_m THEN '重要保持用户'
        WHEN rs.r_score <= avg_r AND rs.f_score > avg_f AND rs.m_score <= avg_m THEN '一般保持用户'
        WHEN rs.r_score <= avg_r AND rs.f_score <= avg_f AND rs.m_score > avg_m THEN '重要挽留用户'
        ELSE '一般挽留用户'
    END as user_segment
FROM rfm_scores rs
CROSS JOIN avg_scores;

#各用户层占比和贡献
SELECT
    user_segment,
    COUNT(*) as user_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) as user_pct,   #用户数占比(%)
    SUM(monetary) as total_revenue,                                  #总收入（每类客户）
    ROUND(SUM(monetary) * 100.0 / SUM(SUM(monetary)) OVER(), 2) as revenue_pct,#收入占比(%)
    ROUND(AVG(monetary), 2) as avg_revenue_per_user,                 #人均消费（每类客户）
    ROUND(AVG(recency), 1) as avg_recency_days,                      #平均最近消费天数
    ROUND(AVG(frequency), 1) as avg_orders                           #平均购物次数
FROM user_segments
GROUP BY user_segment
ORDER BY revenue_pct DESC;

#高价值用户画像
SELECT
    '重要价值用户' as segment,
    ROUND(AVG(recency), 1) as avg_recency_days,
    ROUND(AVG(frequency), 1) as avg_orders,
    ROUND(AVG(monetary), 2) as avg_spent,
    COUNT(*) as user_count
FROM user_segments
WHERE user_segment = '重要价值用户';

#重要价值客户top10爱买
SELECT
    cr.StockCode,
    cr.Description,
    COUNT(*) as purchase_count,
    SUM(cr.Quantity) as total_quantity,
    ROUND(SUM(cr.Quantity * cr.Price), 2) as revenue
FROM online_retail cr
JOIN user_segments us ON cr.customer_ID = us.customer_ID
WHERE us.user_segment = '重要价值用户'
GROUP BY cr.StockCode, cr.Description
ORDER BY revenue DESC
LIMIT 10;

#找到每个用户最先开始购买月份+建立view
CREATE VIEW cohort_base AS
SELECT
    customer_ID,
    DATE_FORMAT(MIN(InvoiceDate), '%Y-%m') as cohort_month
FROM online_retail
GROUP BY customer_ID;

#各月新用户数量
SELECT
    cohort_month,
    COUNT(*) as new_customers
FROM cohort_base
GROUP BY cohort_month
ORDER BY cohort_month;

#准备留存数据+建立view
CREATE VIEW retention_data AS
SELECT
    cb.customer_ID,                          #客户ID
    cb.cohort_month,                         #客户首次购买的月份（加入月份）
    DATE_FORMAT(o_r.InvoiceDate, '%Y-%m') as active_month,  #订单发生的月份
    (YEAR(o_r.InvoiceDate) - YEAR(STR_TO_DATE(CONCAT(cb.cohort_month, '-01'), '%Y-%m-%d'))) * 12
    + MONTH(o_r.InvoiceDate) - MONTH(STR_TO_DATE(CONCAT(cb.cohort_month, '-01'), '%Y-%m-%d')) as month_number #第N个月（0=首月，1=次月...）
FROM cohort_base cb                            #客户首次购买信息
JOIN online_retail o_r ON cb.customer_ID = o_r.customer_ID;

#计算留存率矩阵
WITH cohort_size AS (
    SELECT
        cohort_month,                          #加入月份
        COUNT(DISTINCT customer_ID) as total_users  #该月新用户总数
    FROM cohort_base
    GROUP BY cohort_month
),
    retention_counts AS (
    SELECT
        rd.cohort_month,
        rd.month_number,
        COUNT(DISTINCT rd.customer_ID) as retained_users
    FROM retention_data rd
    WHERE rd.month_number >= 0
    GROUP BY rd.cohort_month, rd.month_number
)
SELECT
    rc.cohort_month,
    rc.month_number,
    rc.retained_users,
    cs.total_users,
    ROUND(rc.retained_users * 100.0 / cs.total_users, 2) as retention_rate
FROM retention_counts rc
JOIN cohort_size cs ON rc.cohort_month = cs.cohort_month
WHERE rc.month_number <= 6  #只看前6个月
ORDER BY rc.cohort_month, rc.month_number;

#用户转化漏斗
WITH customer_stats AS (
    SELECT
        customer_ID,
        COUNT(DISTINCT Invoice) as order_count,
        SUM(Quantity * Price) as total_spent,
        MIN(InvoiceDate) as first_purchase,
        MAX(InvoiceDate) as last_purchase
    FROM online_retail
    GROUP BY customer_ID
)
SELECT
    '总用户数' as stage,
    COUNT(*) as user_count,
    '100.00' as pct_of_total
FROM customer_stats
UNION ALL
SELECT
    '首购用户' as stage,
    COUNT(*) as user_count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM customer_stats), 2) as pct_of_total
FROM customer_stats
WHERE order_count >= 1
UNION ALL
SELECT
    '复购用户 (2+订单)' as stage,
    COUNT(*) as user_count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM customer_stats), 2) as pct_of_total
FROM customer_stats
WHERE order_count >= 2
UNION ALL
SELECT
    '高频用户 (5+订单)' as stage,
    COUNT(*) as user_count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM customer_stats), 2) as pct_of_total
FROM customer_stats
WHERE order_count >= 5
UNION ALL
SELECT
    '高价值用户 (消费>1000)' as stage,
    COUNT(*) as user_count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM customer_stats), 2) as pct_of_total
FROM customer_stats
WHERE total_spent > 1000;



