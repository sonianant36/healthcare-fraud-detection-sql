-- ============================================================
-- providers
-- ============================================================
CREATE TABLE providers (
    provider_id      TEXT PRIMARY KEY,
    potential_fraud  TEXT NOT NULL CHECK (potential_fraud IN ('Yes', 'No'))
);

-- ============================================================
-- beneficiaries
-- ============================================================
CREATE TABLE beneficiaries (
    bene_id                            TEXT PRIMARY KEY,
    dob                                DATE,
    dod                                DATE,
    gender                             INTEGER,
    race                               INTEGER,
    renal_disease_indicator            TEXT,
    state                              INTEGER,
    county                             INTEGER,
    no_of_months_part_a_coverage       INTEGER,
    no_of_months_part_b_coverage       INTEGER,
    chronic_cond_alzheimer             INTEGER,
    chronic_cond_heart_failure         INTEGER,
    chronic_cond_kidney_disease        INTEGER,
    chronic_cond_cancer                INTEGER,
    chronic_cond_obstr_pulmonary       INTEGER,
    chronic_cond_depression            INTEGER,
    chronic_cond_diabetes              INTEGER,
    chronic_cond_ischemic_heart        INTEGER,
    chronic_cond_osteoporosis          INTEGER,
    chronic_cond_rheumatoid_arthritis  INTEGER,
    chronic_cond_stroke                INTEGER,
    ip_annual_reimbursement_amt        NUMERIC(12, 2),
    ip_annual_deductible_amt           NUMERIC(12, 2),
    op_annual_reimbursement_amt        NUMERIC(12, 2),
    op_annual_deductible_amt           NUMERIC(12, 2)
);

-- ============================================================
-- inpatient_claims
-- ============================================================
CREATE TABLE inpatient_claims (
    claim_id                   TEXT PRIMARY KEY,
    bene_id                    TEXT REFERENCES beneficiaries(bene_id),
    provider_id                TEXT REFERENCES providers(provider_id),
    claim_start_dt             DATE,
    claim_end_dt               DATE,
    insc_claim_amt_reimbursed  NUMERIC(12, 2),
    attending_physician        TEXT,
    operating_physician        TEXT,
    other_physician            TEXT,
    admission_dt               DATE,
    clm_admit_diagnosis_code   TEXT,
    deductible_amt_paid        NUMERIC(12, 2),
    discharge_dt               DATE,
    diagnosis_group_code       TEXT
);

-- ============================================================
-- outpatient_claims
-- ============================================================
CREATE TABLE outpatient_claims (
    claim_id                   TEXT PRIMARY KEY,
    bene_id                    TEXT REFERENCES beneficiaries(bene_id),
    provider_id                TEXT REFERENCES providers(provider_id),
    claim_start_dt             DATE,
    claim_end_dt               DATE,
    insc_claim_amt_reimbursed  NUMERIC(12, 2),
    attending_physician        TEXT,
    operating_physician        TEXT,
    other_physician            TEXT,
    clm_admit_diagnosis_code   TEXT,
    deductible_amt_paid        NUMERIC(12, 2)
);

-- ============================================================
-- claim_diagnoses (long format)
-- ============================================================
CREATE TABLE claim_diagnoses (
    claim_id            TEXT,
    diagnosis_position  INTEGER NOT NULL,
    diagnosis_code      TEXT NOT NULL,
    PRIMARY KEY (claim_id, diagnosis_position)
);

-- ============================================================
-- claim_procedures (long format)
-- ============================================================
CREATE TABLE claim_procedures (
    claim_id            TEXT,
    procedure_position  INTEGER NOT NULL,
    procedure_code      TEXT NOT NULL,
    PRIMARY KEY (claim_id, procedure_position)
);



CREATE TABLE staging_inpatient (
    "BeneID" TEXT,
    "ClaimID" TEXT,
    "ClaimStartDt" DATE,
    "ClaimEndDt" DATE,
    "Provider" TEXT,
    "InscClaimAmtReimbursed" NUMERIC(12,2),
    "AttendingPhysician" TEXT,
    "OperatingPhysician" TEXT,
    "OtherPhysician" TEXT,
    "AdmissionDt" DATE,
    "ClmAdmitDiagnosisCode" TEXT,
    "DeductibleAmtPaid" NUMERIC(12,2),
    "DischargeDt" DATE,
    "DiagnosisGroupCode" TEXT,
    "ClmDiagnosisCode_1" TEXT,
    "ClmDiagnosisCode_2" TEXT,
    "ClmDiagnosisCode_3" TEXT,
    "ClmDiagnosisCode_4" TEXT,
    "ClmDiagnosisCode_5" TEXT,
    "ClmDiagnosisCode_6" TEXT,
    "ClmDiagnosisCode_7" TEXT,
    "ClmDiagnosisCode_8" TEXT,
    "ClmDiagnosisCode_9" TEXT,
    "ClmDiagnosisCode_10" TEXT,
    "ClmProcedureCode_1" TEXT,
    "ClmProcedureCode_2" TEXT,
    "ClmProcedureCode_3" TEXT,
    "ClmProcedureCode_4" TEXT,
    "ClmProcedureCode_5" TEXT,
    "ClmProcedureCode_6" TEXT
);

CREATE TABLE staging_outpatient (
    "BeneID" TEXT,
    "ClaimID" TEXT,
    "ClaimStartDt" DATE,
    "ClaimEndDt" DATE,
    "Provider" TEXT,
    "InscClaimAmtReimbursed" NUMERIC(12,2),
    "AttendingPhysician" TEXT,
    "OperatingPhysician" TEXT,
    "OtherPhysician" TEXT,
    "ClmDiagnosisCode_1" TEXT,
    "ClmDiagnosisCode_2" TEXT,
    "ClmDiagnosisCode_3" TEXT,
    "ClmDiagnosisCode_4" TEXT,
    "ClmDiagnosisCode_5" TEXT,
    "ClmDiagnosisCode_6" TEXT,
    "ClmDiagnosisCode_7" TEXT,
    "ClmDiagnosisCode_8" TEXT,
    "ClmDiagnosisCode_9" TEXT,
    "ClmDiagnosisCode_10" TEXT,
    "ClmProcedureCode_1" TEXT,
    "ClmProcedureCode_2" TEXT,
    "ClmProcedureCode_3" TEXT,
    "ClmProcedureCode_4" TEXT,
    "ClmProcedureCode_5" TEXT,
    "ClmProcedureCode_6" TEXT,
    "DeductibleAmtPaid" NUMERIC(12,2),
    "ClmAdmitDiagnosisCode" TEXT
);