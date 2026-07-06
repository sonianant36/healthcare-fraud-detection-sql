-- =====================================================================
-- Unpivot diagnosis codes from wide format (staging) to long format
-- =====================================================================
INSERT INTO claim_diagnoses (claim_id, diagnosis_position, diagnosis_code)

-- Inpatient diagnosis codes (10 positions)
SELECT "ClaimID", 1,  "ClmDiagnosisCode_1"  FROM staging_inpatient WHERE "ClmDiagnosisCode_1"  IS NOT NULL
UNION ALL
SELECT "ClaimID", 2,  "ClmDiagnosisCode_2"  FROM staging_inpatient WHERE "ClmDiagnosisCode_2"  IS NOT NULL
UNION ALL
SELECT "ClaimID", 3,  "ClmDiagnosisCode_3"  FROM staging_inpatient WHERE "ClmDiagnosisCode_3"  IS NOT NULL
UNION ALL
SELECT "ClaimID", 4,  "ClmDiagnosisCode_4"  FROM staging_inpatient WHERE "ClmDiagnosisCode_4"  IS NOT NULL
UNION ALL
SELECT "ClaimID", 5,  "ClmDiagnosisCode_5"  FROM staging_inpatient WHERE "ClmDiagnosisCode_5"  IS NOT NULL
UNION ALL
SELECT "ClaimID", 6,  "ClmDiagnosisCode_6"  FROM staging_inpatient WHERE "ClmDiagnosisCode_6"  IS NOT NULL
UNION ALL
SELECT "ClaimID", 7,  "ClmDiagnosisCode_7"  FROM staging_inpatient WHERE "ClmDiagnosisCode_7"  IS NOT NULL
UNION ALL
SELECT "ClaimID", 8,  "ClmDiagnosisCode_8"  FROM staging_inpatient WHERE "ClmDiagnosisCode_8"  IS NOT NULL
UNION ALL
SELECT "ClaimID", 9,  "ClmDiagnosisCode_9"  FROM staging_inpatient WHERE "ClmDiagnosisCode_9"  IS NOT NULL
UNION ALL
SELECT "ClaimID", 10, "ClmDiagnosisCode_10" FROM staging_inpatient WHERE "ClmDiagnosisCode_10" IS NOT NULL

-- Outpatient diagnosis codes (10 positions)
UNION ALL
SELECT "ClaimID", 1,  "ClmDiagnosisCode_1"  FROM staging_outpatient WHERE "ClmDiagnosisCode_1"  IS NOT NULL
UNION ALL
SELECT "ClaimID", 2,  "ClmDiagnosisCode_2"  FROM staging_outpatient WHERE "ClmDiagnosisCode_2"  IS NOT NULL
UNION ALL
SELECT "ClaimID", 3,  "ClmDiagnosisCode_3"  FROM staging_outpatient WHERE "ClmDiagnosisCode_3"  IS NOT NULL
UNION ALL
SELECT "ClaimID", 4,  "ClmDiagnosisCode_4"  FROM staging_outpatient WHERE "ClmDiagnosisCode_4"  IS NOT NULL
UNION ALL
SELECT "ClaimID", 5,  "ClmDiagnosisCode_5"  FROM staging_outpatient WHERE "ClmDiagnosisCode_5"  IS NOT NULL
UNION ALL
SELECT "ClaimID", 6,  "ClmDiagnosisCode_6"  FROM staging_outpatient WHERE "ClmDiagnosisCode_6"  IS NOT NULL
UNION ALL
SELECT "ClaimID", 7,  "ClmDiagnosisCode_7"  FROM staging_outpatient WHERE "ClmDiagnosisCode_7"  IS NOT NULL
UNION ALL
SELECT "ClaimID", 8,  "ClmDiagnosisCode_8"  FROM staging_outpatient WHERE "ClmDiagnosisCode_8"  IS NOT NULL
UNION ALL
SELECT "ClaimID", 9,  "ClmDiagnosisCode_9"  FROM staging_outpatient WHERE "ClmDiagnosisCode_9"  IS NOT NULL
UNION ALL
SELECT "ClaimID", 10, "ClmDiagnosisCode_10" FROM staging_outpatient WHERE "ClmDiagnosisCode_10" IS NOT NULL;


SELECT COUNT(*) FROM claim_diagnoses;


-- How many diagnosis codes does each claim have?
SELECT diagnosis_position, COUNT(*) AS occurrences
FROM claim_diagnoses
GROUP BY diagnosis_position
ORDER BY diagnosis_position;


-- Top 10 most common diagnosis codes
SELECT diagnosis_code, COUNT(*) AS occurrences
FROM claim_diagnoses
GROUP BY diagnosis_code
ORDER BY occurrences DESC
LIMIT 10;

-- =====================================================================
-- Unpivot procedure codes from wide format (staging) to long format
-- =====================================================================
INSERT INTO claim_procedures (claim_id, procedure_position, procedure_code)

-- Inpatient procedure codes (6 positions)
SELECT "ClaimID", 1, "ClmProcedureCode_1" FROM staging_inpatient WHERE "ClmProcedureCode_1" IS NOT NULL
UNION ALL
SELECT "ClaimID", 2, "ClmProcedureCode_2" FROM staging_inpatient WHERE "ClmProcedureCode_2" IS NOT NULL
UNION ALL
SELECT "ClaimID", 3, "ClmProcedureCode_3" FROM staging_inpatient WHERE "ClmProcedureCode_3" IS NOT NULL
UNION ALL
SELECT "ClaimID", 4, "ClmProcedureCode_4" FROM staging_inpatient WHERE "ClmProcedureCode_4" IS NOT NULL
UNION ALL
SELECT "ClaimID", 5, "ClmProcedureCode_5" FROM staging_inpatient WHERE "ClmProcedureCode_5" IS NOT NULL
UNION ALL
SELECT "ClaimID", 6, "ClmProcedureCode_6" FROM staging_inpatient WHERE "ClmProcedureCode_6" IS NOT NULL

-- Outpatient procedure codes (6 positions)
UNION ALL
SELECT "ClaimID", 1, "ClmProcedureCode_1" FROM staging_outpatient WHERE "ClmProcedureCode_1" IS NOT NULL
UNION ALL
SELECT "ClaimID", 2, "ClmProcedureCode_2" FROM staging_outpatient WHERE "ClmProcedureCode_2" IS NOT NULL
UNION ALL
SELECT "ClaimID", 3, "ClmProcedureCode_3" FROM staging_outpatient WHERE "ClmProcedureCode_3" IS NOT NULL
UNION ALL
SELECT "ClaimID", 4, "ClmProcedureCode_4" FROM staging_outpatient WHERE "ClmProcedureCode_4" IS NOT NULL
UNION ALL
SELECT "ClaimID", 5, "ClmProcedureCode_5" FROM staging_outpatient WHERE "ClmProcedureCode_5" IS NOT NULL
UNION ALL
SELECT "ClaimID", 6, "ClmProcedureCode_6" FROM staging_outpatient WHERE "ClmProcedureCode_6" IS NOT NULL;


SELECT COUNT(*) FROM claim_procedures;
-- Expected: ~40,000 to 60,000

SELECT procedure_position, COUNT(*) AS occurrences
FROM claim_procedures
GROUP BY procedure_position
ORDER BY procedure_position;

DROP TABLE staging_inpatient;
DROP TABLE staging_outpatient;

SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
ORDER BY table_name;


-- Indexes on foreign-key columns (most joined)
CREATE INDEX idx_inpatient_provider ON inpatient_claims(provider_id);
CREATE INDEX idx_inpatient_bene ON inpatient_claims(bene_id);
CREATE INDEX idx_inpatient_start_dt ON inpatient_claims(claim_start_dt);

CREATE INDEX idx_outpatient_provider ON outpatient_claims(provider_id);
CREATE INDEX idx_outpatient_bene ON outpatient_claims(bene_id);
CREATE INDEX idx_outpatient_start_dt ON outpatient_claims(claim_start_dt);

-- Indexes on diagnosis/procedure code lookups
CREATE INDEX idx_diagnoses_code ON claim_diagnoses(diagnosis_code);
CREATE INDEX idx_procedures_code ON claim_procedures(procedure_code);

-- Composite index for fraud analysis (frequently filter by provider + fraud label)
CREATE INDEX idx_provider_fraud ON providers(provider_id, potential_fraud);

SELECT 'providers' AS table_name, COUNT(*) AS rows FROM providers
UNION ALL SELECT 'beneficiaries', COUNT(*) FROM beneficiaries
UNION ALL SELECT 'inpatient_claims', COUNT(*) FROM inpatient_claims
UNION ALL SELECT 'outpatient_claims', COUNT(*) FROM outpatient_claims
UNION ALL SELECT 'claim_diagnoses', COUNT(*) FROM claim_diagnoses
UNION ALL SELECT 'claim_procedures', COUNT(*) FROM claim_procedures
ORDER BY table_name;


-- Top 10 fraud-labeled providers by total reimbursement
SELECT 
    p.provider_id,
    p.potential_fraud,
    COUNT(o.claim_id) AS claim_count,
    ROUND(SUM(o.insc_claim_amt_reimbursed), 2) AS total_reimbursed,
    ROUND(AVG(o.insc_claim_amt_reimbursed), 2) AS avg_per_claim
FROM providers p
INNER JOIN outpatient_claims o ON o.provider_id = p.provider_id
WHERE p.potential_fraud = 'Yes'
GROUP BY p.provider_id, p.potential_fraud
ORDER BY total_reimbursed DESC
LIMIT 10;