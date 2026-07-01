# RetailIQ — E-Commerce Finance Analytics

> An end-to-end retail analytics project: clean a dirty multi-table e-commerce dataset with Python, model it into a relational MySQL schema, diagnose 12 core business problems (plus 6 supplementary analyses) and an executive KPI view in SQL, and present the findings in a 7-page Power BI dashboard and a polished Word report.

![Status](https://img.shields.io/badge/Status-Completed-brightgreen?style=flat)
![Python](https://img.shields.io/badge/Python-3-blue?style=flat&logo=python&logoColor=white)
![MySQL](https://img.shields.io/badge/MySQL-8.0-4479A1?style=flat&logo=mysql&logoColor=white)
![Jupyter](https://img.shields.io/badge/Jupyter-EDA-F37626?style=flat&logo=jupyter&logoColor=white)
![Power BI](https://img.shields.io/badge/Power_BI-F2C811?style=flat&logo=powerbi&logoColor=black)

---

## 📚 Table of Contents

- [📁 Repository Structure](#-repository-structure)
- [🎯 Project Objectives](#-project-objectives)
- [📊 Dataset Overview](#-dataset-overview)
- [🧼 Data Cleaning Pipeline](#-data-cleaning-pipeline)
- [🗄️ Relational Schema](#️-relational-schema)
- [🐍 Python EDA](#-python-eda)
- [📈 SQL Business Analysis (12 Core + 6 Supplementary)](#-sql-business-analysis-12-core--6-supplementary)
- [📊 Executive KPIs](#-executive-kpis)
- [📶 Power BI Dashboard](#-power-bi-dashboard)
- [📄 Final Project Report](#-final-project-report)
- [🛠️ Tech Stack](#️-tech-stack)
- [🚀 Getting Started](#-getting-started)
- [📌 Key Insights](#-key-insights)
- [👤 Author](#-author)

---

## 🎯 Project Objectives

- 🧼 **Clean** a raw, messy retail dataset (city typos, supplier casing, type errors, missing values, duplicates) into analysis-ready tables
- 🏗️ **Model** a normalised MySQL schema with 8 tables and 12 foreign keys sharing a calendar dimension
- 📈 **Diagnose** 12 core business problems plus 6 supplementary analyses — churn, profit leaks, marketing ROI, stockouts, supplier quality, retention, RFM, cohorts, affinity & turnover
- 📊 **Produce** a single-query executive KPI dashboard (revenue, profit, LTV, CAC, returns, stockout loss)
- 📶 **Visualise** the findings in a 7-page Power BI executive dashboard
- 🐍 **Profile** every table with a dedicated Python EDA notebook
- 📄 **Document** the full analysis in a professional Word (.docx) project report

---

## 📁 Repository Structure

```
finance-new/
│
├── 📂 dirty_dataset/                    # Raw source data (8 CSV files) — contains data quality issues
│   ├── 📄 customers.csv
│   ├── 📄 date_dim.csv
│   ├── 📄 inventory.csv
│   ├── 📄 marketing_spend.csv
│   ├── 📄 order_items.csv
│   ├── 📄 orders.csv
│   ├── 📄 products.csv
│   └── 📄 returns.csv
│
├── 📂 clean_dataset/                   # Cleaned, analysis-ready output produced by the notebooks (8 CSV files)
│   ├── 📄 customers.csv
│   ├── 📄 date_dim.csv
│   ├── 📄 inventory.csv
│   ├── 📄 marketing_spend.csv
│   ├── 📄 order_items.csv
│   ├── 📄 orders.csv
│   ├── 📄 products.csv
│   └── 📄 returns.csv
│
├── 📂 eda_python/                       # One notebook per table — cleans AND profiles each table
│   ├── 📓 eda_customers.ipynb
│   ├── 📓 eda_date_dim.ipynb
│   ├── 📓 eda_inventory.ipynb
│   ├── 📓 eda_marketing_spend.ipynb
│   ├── 📓 eda_order_items.ipynb
│   ├── 📓 eda_orders.ipynb
│   ├── 📓 eda_products.ipynb
│   └── 📓 eda_returns.ipynb
│
├── 📂 eda_sql/                          # MySQL schema + analysis
│   ├── 🗄️ table_creation.sql            # CREATE TABLE for all 8 tables (PKs + FKs inline)
│   ├── 🔗 relation.sql                  # Adds 12 foreign keys, marketing surrogate PK, derived date column
│   ├── 🛠️ fix_relation.sql             # Type fixes, indexes, constraint repair, dim_date → date_dim rename
│   ├── 📈 main_sql_eda.sql             # 12 core + 6 supplementary problems (queries only)
│   ├── 📈 main_sql_eda_with_output.sql # Same 18 problems with embedded results + written insights
│   └── 📊 kpis.sql                      # Executive KPI dashboard (single multi-CTE query)
│
├── 📂 power_bi_dashboard/               # Power BI report + export
│   ├── 📊 dashboard.pbix                 # Published 7-page Power BI report
│   ├── 📄 dashboard.pdf                  # PDF export of the dashboard
│   ├── 📂 data/                          # The 8 cleaned CSVs consumed by the report
│   │   └── (customers, date_dim, inventory, marketing_spend, orders, order_items, products, returns)
│   └── 📂 sql_reference/                # Copies of the eda_sql/ scripts used as DAX reference
│       └── (table_creation, relation, fix_relation, main_sql_eda, main_sql_eda_with_output, kpis)
│
├── 📄 RetailIQ_Project_Report.docx       # Final professional project report (Word)
└── 🐍 build_report.py                   # Script that generates the .docx report
```

---

## 📊 Dataset Overview

A UK e-commerce dataset spanning **Jan 2022 – Dec 2024** for orders (returns extend into Jan 2025), organised as a star-style schema around a shared `date_dim` calendar table.

| Table | Rows | Grain | Purpose |
|---|---|---|---|
| `customers` | 5,519 | 1 row / customer | Demographics, acquisition channel, signup date, CAC |
| `date_dim` | 1,096 | 1 row / day | Calendar attributes (year, quarter, month, weekend, month-end, peak season, season) |
| `products` | 30 | 1 row / product | Product master — category, supplier, cost/sell price, margin, demand rank |
| `orders` | 11,431 | 1 row / order | Order header — subtotal, shipping, total, discount, status |
| `order_items` | 19,642 | 1 row / line item | Line economics — qty, unit price, discount, line total, cost price, weight |
| `returns` | 3,716 | 1 row / return | Return reason, refund amount, qty returned |
| `inventory` | 32,880 | 1 row / product / day | Daily stock level, units sold, stockout flag |
| `marketing_spend` | 180 | 1 row / channel / month | Spend, impressions, clicks, conversions, CAC, budget share |

**Acquisition channels:** Paid Social, Google Ads, Referral, Email, Organic
**Order statuses:** Completed, Pending, Cancelled, Returned

---

## 🧼 Data Cleaning Pipeline

The `dirty_dataset/` contains genuine data quality problems. Each `eda_python/` notebook loads its dirty CSV, cleans it, and writes a cleaned file plus an `<table>_issues.csv` audit of flagged rows. The cleaned outputs populate `clean_dataset/`.

### Issues found & fixed in the raw data
- **City typos** → standardised (`londen`/`londn` → `london`, `manchestor` → `manchester`, `liverpol` → `liverpool`, `leeds `/`leds`/`leedes` → `leeds`)
- **Supplier name variants** → unified (`novatech supply` / `Nova Tech Supply` / `Novatech Supply` → `NovaTech Supply`)
- **Gender values** → standardised (`MALE` → `M`)
- **Type coercion** → floats to ints (`age` 31.0 → 31, `cost_price` 14.0 → 14), booleans (`"True"`/`"False"` strings → real booleans)
- **Missing values** → imputed (e.g. missing `shipping_cost` recalculated from order components)
- **Whitespace** → trimmed on all text columns; IDs normalised
- **Dates** → parsed with `pd.to_datetime`; derived fields (`order_month`, `order_year`, `day_of_week`, `order_quarter`) recomputed and cross-checked via `year_check` / `month_check` / `quarter_check` flags
- **Duplicates** → detected and dropped
- **Consistency audits** → rows failing shipping/total/year/month/quarter checks are isolated into an issues file for review

---

## 🗄️ Relational Schema

Built in MySQL 8.0 across three scripts:

| File | Role |
|---|---|
| `table_creation.sql` | `CREATE TABLE` for all 8 tables with inline primary and foreign keys |
| `relation.sql` | Adds all 12 FKs, a surrogate auto-increment PK for `marketing_spend`, and a derived `date` column from month/year |
| `fix_relation.sql` | Column type repairs, indexing (`idx_order_date`), constraint debugging, and `dim_date` → `date_dim` rename |

### Foreign keys (12 total)
```
orders.customer_id        → customers.customer_id
orders.order_date         → date_dim.date
order_items.order_id      → orders.order_id
order_items.product_id    → products.product_id
order_items.order_date    → date_dim.date
returns.order_id          → orders.order_id
returns.item_id           → order_items.item_id
returns.product_id        → products.product_id
returns.return_date       → date_dim.date
inventory.product_id      → products.product_id
inventory.date            → date_dim.date
customers.signup_date     → date_dim.date
```

### Schema diagram
```
                       date_dim (calendar)
                            │ date (PK)
        ┌───────────────────┼───────────────────┐
        │                   │                   │
   customers           orders               inventory
   (PK customer_id)   (PK order_id)     (PK product_id, date)
        │ customer_id ─┘ order_date ─┐        │ product_id ─┐
        │ signup_date ──────────────┤        └─────────────┤
        │                            │                      │
        │                       order_items ──product_id────► products
        │                       (PK item_id)                (PK product_id)
        │                            │
        │                            ▼
        │                        returns
        └────────────────── (PK return_id)
```

---

## 🐍 Python EDA

Eight standalone Jupyter notebooks (`pandas`, `numpy`, `matplotlib`, `seaborn`) — **one per table**. Each notebook both cleans and profiles its table.

| Notebook | Cells | Focus |
|---|---|---|
| `eda_customers.ipynb` | 35 | ID validation, demographics, channel & CAC profiling |
| `eda_date_dim.ipynb` | 18 | Calendar coverage, seasonality & weekend flags |
| `eda_inventory.ipynb` | 28 | Stock levels, stockout frequency, units-sold distribution |
| `eda_marketing_spend.ipynb` | 25 | Spend vs conversions, CAC by channel, budget share |
| `eda_order_items.ipynb` | 34 | Line economics, discounts, category & supplier breakdown |
| `eda_orders.ipynb` | 31 | Order totals, shipping, discount, status, temporal trends |
| `eda_products.ipynb` | 24 | Pricing, margins, categories, supplier, demand rank |
| `eda_returns.ipynb` | 34 | Return reasons, refunds, supplier & product concentration |

### Typical notebook workflow
```python
import pandas as np, pandas as pd

df = pd.read_csv('orders.csv')
df.info(); df.describe(include='all')
df.isnull().sum()        # missing-value audit
df.duplicated().sum()    # duplicate audit

# clean → df.to_csv('orders_cleaned.csv', index=False)
# audit → issues.to_csv('orders_issues.csv', index=False)
```

---

## 📈 SQL Business Analysis (12 Core + 6 Supplementary)

`main_sql_eda.sql` solves 18 diagnostic problems in MySQL using CTEs, window functions (`NTILE`, `LAG`), self-joins, and multi-table joins. `main_sql_eda_with_output.sql` contains the same queries with embedded result tables and written insights. Problems **1–12** are the headline business problems listed in the script header; problems **13–18** are supplementary analyses that feed several Power BI visuals.

| # | Business problem |
|---|---|
| 1 | Silent customer churn — why customers buy once and never return |
| 2 | Bestsellers generating negative true profit after costs & refunds |
| 3 | Marketing channels getting heavy budget despite the worst ROI |
| 4 | Revenue lost to stockouts during peak seasonal demand |
| 5 | Cities/regions where shipping costs erode profitability |
| 6 | Discount addiction, concentrated at month-end |
| 7 | VIP (top 10%) customers and whether they get enough attention |
| 8 | Rising return rate over time and its financial impact |
| 9 | Low-value orders made unprofitable by shipping costs |
| 10 | NovaTech Supply quality — excessive returns & refunds |
| 11 | Weekend vs weekday demand gap |
| 12 | CAC rising faster than LTV — collapsing unit economics |
| 13 | RFM customer segmentation (Champion / Loyal / At Risk / Lost / …) |
| 14 | Cohort retention analysis |
| 15 | Month-over-month revenue growth |
| 16 | Product affinity / cross-sell pairs |
| 17 | Rolling 30-day revenue trend |
| 18 | Inventory turnover ratio & stock classification |

---

## 📊 Executive KPIs

`kpis.sql` is a single multi-CTE query producing a one-row executive dashboard:

| KPI | Definition |
|---|---|
| Total Customers | Distinct customers with completed orders |
| Total Orders | Completed order count |
| Total Revenue | Sum of completed `order_total` |
| Net Profit | Revenue − COGS − refunds |
| Customer Lifetime Value | Avg revenue per customer |
| Repeat Purchase Rate (%) | Share of customers with ≥ 2 orders |
| Return Rate (%) | Returns ÷ items fulfilled |
| Refund Amount | Total refunds paid |
| LTV to CAC Ratio | Overall + per channel (Email, Organic, Referral, Paid Social, Google Ads) |
| Stockout Lost Revenue | Estimated peak-season revenue lost to stockouts |
| Average Shipping Cost (%) | Shipping as % of order total |
| Month-End Discount Rate (%) | Avg discount at month-end |

---

## 📶 Power BI Dashboard

`power_bi_dashboard/dashboard.pbix` is a 7-page executive dashboard that consumes the 8 cleaned CSVs from `power_bi_dashboard/data/` and uses calculated DAX logic to reproduce the KPI definitions from `kpis.sql`. A PDF export is provided as `dashboard.pdf`.

### Dashboard pages
| Page | Theme | Key visuals |
|---|---|---|
| 1 | Finance Overview | KPI cards (Total Revenue, Customers, AOV, Returns, Stockout Lost Revenue, Marketing Spend, NovaTech Return Rate, 2024 LTV:CAC); Cohort LTV vs Blended CAC; Quarterly Return Rate % |
| 2 | Customer Analytics | Revenue by Order Count Band; VIP vs Non-VIP revenue; Cohort LTV & Size by Signup Year; DOW Revenue; DOW AOV & Order Count; RFM segment table |
| 3 | Marketing Analytics | Channel LTV-to-CAC; Channel summary table; CAC by Channel Year-by-Year; Customers Acquired vs Blended CAC |
| 4 | Returns Analytics | Supplier Return Rate %; Annual Refunds by reason (donut); NovaTech Product Returns; Annual Return Rate & Refunds |
| 5 | Geography & Shipping | City Revenue; Size Band Avg Shipping %; City Shipping Pct %; Size Band Orders |
| 6 | Discount Analytics | Period Discount Given; Yearly Discount Given by Year & Period; Discount Period summary table |
| 7 | Product & Inventory | Product Net Profit; Inventory Turnover Ratio; Stockout Lost Revenue per product; Category Revenue; Category Stockout Rate % |

> The `power_bi_dashboard/sql_reference/` folder holds copies of the `eda_sql/` scripts used as reference while building the DAX measures.

---

## 📄 Final Project Report

`RetailIQ_Project_Report.docx` is the professional final report generated by `build_report.py` (using `python-docx`). It contains 18 sections, 32 tables and an auto-updating Table of Contents:

- Title Page, Table of Contents, Executive Summary, Project Overview, Business Background, Problem Statement, Business Objectives
- Dataset Overview (Dirty & Cleaned), Data Cleaning Process, Python EDA, SQL EDA, Power BI Dashboard Overview
- Key KPIs, Key Findings, Business Insights
- All **12 business questions** deep-dived (Analysis → Findings → Insight → Recommendation)
- Recommendations (by theme + summary table) and Conclusion

Every figure in the report is sourced directly from the project files and cross-checked against the cleaned datasets, the SQL embedded outputs, and the Power BI dashboard. Currency is shown in **£ (British Pound)** throughout.

### Rebuild the report
```bash
pip install python-docx
python build_report.py          # writes RetailIQ_Project_Report.docx
```
After opening in Word, right-click the Table of Contents → **Update Field** to refresh page numbers.

---



| Tool | Purpose |
|---|---|
| ![MySQL](https://img.shields.io/badge/MySQL-4479A1?style=flat&logo=mysql&logoColor=white) | Schema modelling + 18-problem SQL EDA + KPIs |
| ![Python](https://img.shields.io/badge/Python-3776AB?style=flat&logo=python&logoColor=white) | Cleaning + per-table EDA |
| ![Pandas](https://img.shields.io/badge/Pandas-150458?style=flat&logo=pandas&logoColor=white) | Data manipulation |
| ![NumPy](https://img.shields.io/badge/NumPy-013243?style=flat&logo=numpy&logoColor=white) | Numerical operations |
| ![Matplotlib](https://img.shields.io/badge/Matplotlib-11557C?style=flat&logo=python&logoColor=white) | Plotting |
| ![Seaborn](https://img.shields.io/badge/Seaborn-4C72B0?style=flat&logo=python&logoColor=white) | Statistical visualisation |
| ![Jupyter](https://img.shields.io/badge/Jupyter-F37626?style=flat&logo=jupyter&logoColor=white) | Notebook environment |
| ![Power BI](https://img.shields.io/badge/Power_BI-F2C811?style=flat&logo=powerbi&logoColor=black) | 7-page executive dashboard |
| ![python-docx](https://img.shields.io/badge/python--docx-1F3255?style=flat) | Final Word report generation |

---

## 🚀 Getting Started

### Prerequisites
```bash
pip install pandas numpy matplotlib seaborn jupyter
pip install python-docx          # only needed to rebuild the .docx report
```

### 1. Clean the data (produces clean_dataset/)
```bash
jupyter notebook eda_python/eda_customers.ipynb   # run each notebook in turn
# each writes <table>_cleaned.csv + <table>_issues.csv
```

### 2. Build the MySQL schema and load data
```sql
SOURCE eda_sql/table_creation.sql;
-- import the 8 cleaned CSVs from clean_dataset/ into:
--   customers, date_dim, products, orders, order_items, returns, inventory, marketing_spend

-- apply / repair relationships if needed:
USE retail_shop;
SOURCE eda_sql/fix_relation.sql;
```

### 3. Run the analysis
```sql
SOURCE eda_sql/main_sql_eda.sql;   -- 12 core + 6 supplementary problems
SOURCE eda_sql/kpis.sql;           -- executive KPI dashboard
```

### 4. Open the Power BI dashboard
Open `power_bi_dashboard/dashboard.pbix` in Power BI Desktop. The report reads the 8 cleaned CSVs from `power_bi_dashboard/data/`. A PDF export is provided at `power_bi_dashboard/dashboard.pdf`.

### 5. (Optional) Rebuild the Word report
```bash
python build_report.py          # writes RetailIQ_Project_Report.docx
```
After opening in Word, right-click the Table of Contents → **Update Field**.

---

## 📌 Key Insights

All figures are taken from the embedded results in `main_sql_eda_with_output.sql`.

- 🧍 **Churn dominates the base.** 68.8% of customers (3,437) buy once and never return, generating only £531,971.53. The 7.1% with 6+ orders (355) generate £472,886.01 — nearly matching the entire one-time segment.
- 💸 **Two products run at a net loss.** Noise Cancel Headphones (−£12,228.12) and Power Bank 20000mAh (−£6,929.30). Profit is driven by premium hardware: 27in Monitor 4K (+£101,562.18), Smart Watch Fitness (+£69,704.50), Mechanical Keyboard TKL (+£52,225.49).
- 📣 **Marketing budget is misallocated.** Email (LTV:CAC 33.41) and Organic (24.52) are the most efficient channels, but Paid Social (4.31) and Google Ads (4.65) absorb 84.3% of spend.
- 📦 **Stockouts are a bigger lever than acquisition.** Peak-season stockouts cost an estimated >£1.5M; 27in Monitor 4K alone lost £264,719.18.
- 🚚 **Shipping erodes regional margin.** Cardiff pays 17.1% of order value in shipping (worst); London delivers the highest volume (£538,096.27 from 3,580 orders) at only 8.9%.
- 🏷️ **Discount addiction is structural.** Month-end avg discount is 20.11% vs 0.72% the rest of the month; month-end discount cost £73,663.32 vs £8,081.70 elsewhere — and it has grown every year (2022→2024).
- 📉 **Unit economics are collapsing.** LTV:CAC fell 13.41 (2022) → 9.05 (2023) → 4.06 (2024), as CAC rose £24.70 → £49.21 while LTV fell £331.26 → £199.65.
- 🏭 **NovaTech Supply is the quality outlier.** ~42.1% return rate vs 10–20% for other suppliers — a product-failure problem, not a broad catalog issue.
- 🎯 **RFM shows value concentration.** Champions (751 customers) hold £615,685.07 of revenue; 1,498 Lost customers still represent £233,686.73 of historical value; 500 At-Risk customers (LTV £481.17) are the prime reactivation target.

---

## 👤 Author

| | |
|---|---|
| **Name** | Dharmesh Makwana |
| **GitHub** | [@dharmesh9](https://github.com/dharmesh9) |

---

*⭐ If you found this project helpful, please consider giving it a star on GitHub!*

*Built as an e-commerce finance analytics portfolio project — 2026.*
