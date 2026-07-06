COPY providers(provider_id, potential_fraud)
FROM 'C:/NEU - Anant Soni/Full Time/projects/healthcare_fraud_project/data/raw/Train.csv'
WITH (FORMAT csv, HEADER true, NULL 'NA');


SELECT COUNT(*) FROM providers;


SELECT potential_fraud, COUNT(*) FROM providers GROUP BY potential_fraud;


COPY beneficiaries(
    bene_id, dob, dod, gender, race, renal_disease_indicator,
    state, county, no_of_months_part_a_coverage, no_of_months_part_b_coverage,
    chronic_cond_alzheimer, chronic_cond_heart_failure, chronic_cond_kidney_disease,
    chronic_cond_cancer, chronic_cond_obstr_pulmonary, chronic_cond_depression,
    chronic_cond_diabetes, chronic_cond_ischemic_heart, chronic_cond_osteoporosis,
    chronic_cond_rheumatoid_arthritis, chronic_cond_stroke,
    ip_annual_reimbursement_amt, ip_annual_deductible_amt,
    op_annual_reimbursement_amt, op_annual_deductible_amt
)
FROM 'C:/NEU - Anant Soni/Full Time/projects/healthcare_fraud_project/data/raw/Train_Beneficiarydata.csv'
WITH (FORMAT csv, HEADER true, NULL 'NA');


SELECT COUNT(*) FROM beneficiaries;

SELECT COUNT(*) AS deceased FROM beneficiaries WHERE dod IS NOT NULL;

SELECT gender, COUNT(*) FROM beneficiaries GROUP BY gender;

SELECT MIN(dob), MAX(dob) FROM beneficiaries;


COPY staging_inpatient
FROM 'C:/NEU - Anant Soni/Full Time/projects/healthcare_fraud_project/data/raw/Train_Inpatientdata.csv'
WITH (FORMAT csv, HEADER true, NULL 'NA');

INSERT INTO inpatient_claims(
    claim_id, bene_id, provider_id, claim_start_dt, claim_end_dt,
    insc_claim_amt_reimbursed, attending_physician, operating_physician,
    other_physician, admission_dt, clm_admit_diagnosis_code,
    deductible_amt_paid, discharge_dt, diagnosis_group_code
)
SELECT
    "ClaimID", "BeneID", "Provider", "ClaimStartDt", "ClaimEndDt",
    "InscClaimAmtReimbursed", "AttendingPhysician", "OperatingPhysician",
    "OtherPhysician", "AdmissionDt", "ClmAdmitDiagnosisCode",
    "DeductibleAmtPaid", "DischargeDt", "DiagnosisGroupCode"
FROM staging_inpatient;


SELECT COUNT(*) FROM inpatient_claims;

SELECT MIN(claim_start_dt), MAX(claim_start_dt) FROM inpatient_claims;

SELECT ROUND(AVG(insc_claim_amt_reimbursed), 2) AS avg_reimbursement FROM inpatient_claims;


COPY staging_outpatient
FROM 'C:/NEU - Anant Soni/Full Time/projects/healthcare_fraud_project/data/raw/Train_Outpatientdata.csv'
WITH (FORMAT csv, HEADER true, NULL 'NA');


INSERT INTO outpatient_claims(
    claim_id, bene_id, provider_id, claim_start_dt, claim_end_dt,
    insc_claim_amt_reimbursed, attending_physician, operating_physician,
    other_physician, clm_admit_diagnosis_code, deductible_amt_paid
)
SELECT
    "ClaimID", "BeneID", "Provider", "ClaimStartDt", "ClaimEndDt",
    "InscClaimAmtReimbursed", "AttendingPhysician", "OperatingPhysician",
    "OtherPhysician", "ClmAdmitDiagnosisCode", "DeductibleAmtPaid"
FROM staging_outpatient;


SELECT COUNT(*) FROM outpatient_claims;

SELECT ROUND(AVG(insc_claim_amt_reimbursed), 2) AS avg_reimbursement FROM outpatient_claims;


SELECT 'providers' AS table_name, COUNT(*) AS rows FROM providers
UNION ALL SELECT 'beneficiaries', COUNT(*) FROM beneficiaries
UNION ALL SELECT 'inpatient_claims', COUNT(*) FROM inpatient_claims
UNION ALL SELECT 'outpatient_claims', COUNT(*) FROM outpatient_claims
UNION ALL SELECT 'staging_inpatient', COUNT(*) FROM staging_inpatient
UNION ALL SELECT 'staging_outpatient', COUNT(*) FROM staging_outpatient
UNION ALL SELECT 'claim_diagnoses', COUNT(*) FROM claim_diagnoses
UNION ALL SELECT 'claim_procedures', COUNT(*) FROM claim_procedures
ORDER BY table_name;



