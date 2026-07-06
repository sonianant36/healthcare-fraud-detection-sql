# Healthcare Provider Fraud Detection — SQL Analytical Framework

A production-ready fraud detection framework built purely in SQL, analyzing 700,000+ real US Medicare claims to identify fraudulent providers with near-machine-learning precision. Achieves **98.36% precision** at Tier 1 risk stratification and **F1 = 0.639** with a single interpretable rule — approximately 70–75% of published ML performance using zero ML infrastructure.

---

## The Business Problem

The US healthcare industry loses an estimated **$80–$300 billion annually** to fraud, waste, and abuse. Every major US health insurer maintains a Special Investigations Unit (SIU) to detect fraudulent providers, but existing methods are reactive, resource-intensive, and produce inconsistent results.

This project develops and validates a **rule-based tiered fraud detection framework** designed to replace binary flagging with operational risk stratification. All detection logic is expressible in SQL, executes in sub-second time, and produces fully-auditable outputs suitable for regulatory review.

---

## Key Results

| Detector | Precision | Recall | F1 Score |
|---|---|---|---|
| Volume top-decile | 38.08% | 40.71% | 0.394 |
| Reimbursement top-decile (naive) | 12.18% | 9.31% | 0.106 |
| Reimbursement mid-decile (refined) | 19.02% | 43.63% | 0.264 |
| **Patient network overlap** | **77.00%** | **54.57%** | **0.639** |
| **Combined Score = 3 (Tier 1)** | **98.36%** | 11.86% | 0.212 |
| Combined Score ≥ 2 (Tier 2) | 51.30% | 38.93% | 0.443 |

**Benchmark comparison:** Published ML models on this dataset achieve F1 = 0.85–0.95 using 30–50+ engineered features. This rule-based framework achieves 70–75% of ML performance with a single interpretable signal, and matches or exceeds ML precision at the Tier 1 threshold.

---

## Repository Structure

├── README.md                                    ← You are here
├── analysis/
│   ├── Healthcare_Fraud_Detection_Report.docx   ← 23-page executive report
│   └── findings_log.md                          ← Detailed findings documentation
├── sql/
│   ├── 01_create_schema.sql                     ← Database schema (6 tables + view)
│   ├── 02_unpivot_codes.sql                     ← Wide-to-long transformation
│   └── 03_fraud_investigations.sql              ← All 4 detection investigations
└── data/
└── README.md                                ← Dataset source pointer

---

## Dataset

**Source:** [Kaggle Healthcare Provider Fraud Detection Analysis](https://www.kaggle.com/datasets/rohitrox/healthcare-provider-fraud-detection-analysis) (Rohit Anand)

**Scale:**
- 5,410 providers with ground-truth fraud labels (~9.4% baseline fraud rate)
- 138,556 beneficiaries with demographics and 11 chronic condition flags
- 40,474 Medicare Part A inpatient claims
- 517,737 Medicare Part B outpatient claims
- ~1.7 million normalized diagnosis codes (after wide-to-long transformation)

The dataset reflects real US Medicare Part A/B claims structure and is a widely-used benchmark for healthcare fraud detection research.

---

## Methodology

Four fraud signal categories were investigated, each empirically validated against ground-truth fraud labels using confusion matrix analysis.

### F-001: Volume-Based Detection
Ranked providers by total claim count. Top-decile providers show 4× baseline fraud rate. Established as a strong first-line filter.

### F-002: Reimbursement Analysis (Counterintuitive Finding)
Tested the intuitive hypothesis that high-reimbursement providers are fraudulent. **Falsified by the data.** Fraud actually clusters in mid-decile reimbursement (deciles 4–6) at 15–21% versus the 9% baseline. The refined mid-decile detector outperforms the naive top-decile approach by 2.5× on F1. This aligns with real fraud economics where mid-range amounts avoid payer scrutiny thresholds.

### F-003: Patient Network Analysis
Computed patient-provider network overlap: for each provider, the percentage of their patients also seen by 2+ other fraud providers. Emerged as the **strongest single signal** (F1 = 0.639). Network patterns are difficult to fake because they require coordinated behavior across multiple providers — this is why real government fraud units (OIG, FBI Healthcare Fraud Strike Force) invest heavily in graph-based patient analysis.

### F-004: Combined Multi-Signal Detector
Combined the three signals into a fraud score (0–3) enabling tiered investigation prioritization:

| Score | Providers | Fraud Rate | Recommended Action |
|---|---|---|---|
| 3 | 61 | 98.36% | Immediate senior-investigator review (Tier 1) |
| 2 | 323 | 42.41% | Standard investigation queue (Tier 2) |
| 1 | 935 | 16.15% | Automated monitoring watchlist (Tier 3) |
| 0 | 4,091 | 3.86% | No investigation (below baseline) |

---

## Business Impact

Investigating just the 61 Tier 1 providers would identify approximately 60 confirmed fraud cases at ~$30,500 investigation cost, yielding estimated recovery of **$3M–$12M — a return on investment of approximately 100–400×**.

Broader deployment across Tier 1 + Tier 2 (384 providers) would yield an estimated **$14.8M recovery at ~$192,000 investigation cost (~77× ROI)**.

---

## Technical Stack

- **Database:** PostgreSQL 16
- **Client:** DBeaver Community Edition
- **SQL Techniques:** CTEs, window functions (NTILE, RANK, PERCENT_RANK), filtered aggregation (`FILTER (WHERE ...)`), UNION ALL unpivots, views, statistical percentile functions (`percentile_cont`)

---

## Schema Design

Six-table hybrid normalized schema:

- `providers` — 5,410 rows with fraud labels
- `beneficiaries` — 138,556 patient records with demographics and chronic conditions
- `inpatient_claims` — 40,474 Part A claims
- `outpatient_claims` — 517,737 Part B claims
- `claim_diagnoses` — ~1.7M rows (normalized from wide-format 10-column source)
- `claim_procedures` — ~30K rows (normalized from wide-format 6-column source)

Ten strategic indexes optimize the most common query patterns.

---

## How to Reproduce

1. Download the Kaggle dataset (see `data/README.md` for the link and file list)
2. Install PostgreSQL 16 and create a database named `healthcare_fraud`
3. Run `sql/01_create_schema.sql` to build the schema
4. Load CSVs into staging tables and main tables via PostgreSQL's `COPY` command with `NULL 'NA'` clause
5. Run `sql/02_unpivot_codes.sql` to normalize diagnosis and procedure codes
6. Run `sql/03_fraud_investigations.sql` to reproduce all detection metrics

Full step-by-step data loading instructions are documented in the executive report appendix.

---

## Key Takeaways

1. **Patient network signals dominate simple aggregate signals.** F1 = 0.639 from network analysis alone versus 0.394 from volume alone.

2. **Counterintuitive findings emerge from rigorous validation.** The naive "high reimbursement = fraud" hypothesis was falsified by the data — fraud actually concentrates in mid-range reimbursement providers.

3. **Rule-based systems can approach ML performance while retaining full interpretability.** The combined Tier 1 detector achieves 98.36% precision using pure SQL rules any analyst can audit.

4. **Risk stratification is more operationally valuable than binary classification.** Real SIU teams have limited resources — tiered scoring enables explicit investigation prioritization aligned with real workflows.

---

## About This Project

This project was developed as part of a structured Data Analyst portfolio focused on the US healthcare industry. It demonstrates:

- Production-grade SQL analytical skills (CTEs, window functions, unpivot transformations)
- Rigorous experimental methodology (hypothesis → test → validate against ground truth)
- Business acumen (translating analytical findings into ROI and operational recommendations)
- Domain expertise in US healthcare fraud detection

**Author:** Anant Soni | Data Analyst
