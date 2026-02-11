# Marketing Performance and ROI Analysis (SQL)

## Project Overview
This project focuses on analyzing multi-channel advertising data from **Facebook Ads** and **Google Ads** to evaluate campaign performance, budget efficiency, and business growth. By consolidating fragmented data from different platforms, the analysis provides key performance indicators (KPIs) such as **Return on Marketing Investment (ROMI)** and monthly reach trends.

---

## Tech Stack and Skills

### Database
- PostgreSQL  
- Google BigQuery  

### SQL Techniques
- Common Table Expressions (CTEs)
- Window Functions (`LAG`, `ROW_NUMBER`)
- `UNION ALL`
- `COALESCE`
- `DATE_TRUNC`
- Advanced joins

### Data Engineering
- Handling `NULL` values
- Data normalization
- Parsing campaign names from URL parameters using regular expressions

---

## Business Insights and Results

### 1. ROI and Financial Efficiency
- **Peak Performance:**  
  The highest efficiency was recorded on **January 11, 2022**, with a **ROMI of 2.49**, indicating that every unit of currency spent on ads generated **2.49 units in value**.
- **Budget Stability:**  
  The analysis shows a consistent spend-to-value ratio across both platforms, confirming that **Facebook handled higher volumes while maintaining overall profitability**.

### 2. Campaign Growth and Reach
- **Reach Milestone:**  
  The **"Hobbies"** campaign showed significant growth in **April 2022**, reaching an additional **4,266,575 users** compared to the previous month.
- **Top Performer:**  
  The **"Expansion"** campaign emerged as the **top weekly earner**, generating **2,294,120** in value during the week of **April 11, 2022**.

### 3. Operational Consistency (Streak Analysis)
- **Ad Continuity:**  
  The **"Narrow"** ad set demonstrated exceptional stability, running continuously for **108 days** (from **May 17 to September 1, 2021**). This suggests a highly optimized ad set with sustainable audience engagement.

---

## Project Structure
- `marketing_analysis.sql` — Contains the optimized SQL queries used for the analysis.
- - `results/` — Directory containing the query output screenshots as evidence of the analysis.

