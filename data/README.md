# Data Directory

## Source

The dataset used in this project is the publicly available **Healthcare Provider Fraud Detection Analysis** dataset on Kaggle:

**https://www.kaggle.com/datasets/rohitrox/healthcare-provider-fraud-detection-analysis**

## Files Required

To reproduce this analysis, download these four files from the Kaggle URL above:

- `Train.csv` — Provider fraud labels (~5,410 rows)
- `Train_Beneficiarydata.csv` — Patient demographics and chronic conditions (~138,556 rows)
- `Train_Inpatientdata.csv` — Medicare Part A inpatient claims (~40,474 rows)
- `Train_Outpatientdata.csv` — Medicare Part B outpatient claims (~517,737 rows)

Place them in a local `raw/` subdirectory before running the SQL scripts in `../sql/`.

## Dataset Context

This dataset reflects real US Medicare Part A/B claims structure and is a widely-used benchmark for healthcare fraud detection research. Fraud labels are applied at the provider level (not per-claim), with approximately 9.4% of providers labeled as `PotentialFraud = 'Yes'`.

## License

The dataset is published on Kaggle under the terms specified by the original publisher (Rohit Anand). Please review the Kaggle dataset page for usage terms before redistribution.

## Note on CSV Non-Republication

Raw CSV files are not included in this repository because:

1. They are large (~120 MB combined), which conflicts with GitHub best practices
2. They are already publicly available at the source URL above
3. Republishing may violate the original dataset's terms

This keeps the repository lightweight and focused on the analytical work.
