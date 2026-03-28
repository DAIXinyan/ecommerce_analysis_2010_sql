# E-commerce User Behavior SQL Analysis

## Overview
This project analyzes user behavior on a UK e-commerce platform using the UCI Online Retail II dataset. Through RFM segmentation, cohort retention analysis, and conversion funnel analysis, it provides data-driven insights and strategic recommendations for operations teams.

**Key Highlights**:
- Processed 400,000 real e-commerce transaction records
- RFM model classified users into 8 segments to identify high-value customers
- Cohort retention analysis identified critical retention periods
- Conversion funnel analysis pinpointed user churn bottlenecks
- Interactive Power BI dashboard for data visualization

## Dataset
https://archive.ics.uci.edu/dataset/502/online+retail+ii
| Item | Description |
|------|-------------|
| Source | UCI Machine Learning Repository - Online Retail II |
| Volume | ~400,000 transaction records (after cleaning) |
| Fields | Invoice, StockCode, Description, Quantity, InvoiceDate, Price, Customer ID, Country |

## Tech Stack
- **SQL (MySQL/SQLite)**: Data cleaning, RFM analysis, retention analysis, funnel analysis
- **Power BI**: Interactive dashboard
- **GitHub**: Version control

## Project Structure
ecommerce-sql-analysis/
├── README.md
├── scripts/
│ ├── 01_data_cleaning.sql
│ ├── 02_rfm_analysis.sql
│ ├── 03_retention_analysis.sql
│ └── 04_funnel_analysis.sql
├── outputs/
│ └── analysis_report.pdf
└── dashboard/
└── ecommerce_dashboard.pbix

## Deliverables
- 12-page analysis report (PPT) with differentiated operation strategies：
  https://www.canva.cn/design/DAHD6ArEIik/2XS636xIlQsaDPLYwYPVwQ/edit
  utm_content=DAHD6ArEIik&utm_campaign=designshare&utm_medium=link2&utm_source=sharebutton
- SQL scripts for all analyses
- Power BI interactive dashboard
