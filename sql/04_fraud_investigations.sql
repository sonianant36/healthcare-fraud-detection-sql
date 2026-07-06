-- =====================================================================
-- Unified view: all claims (inpatient + outpatient) with fraud labels
-- =====================================================================
CREATE OR REPLACE VIEW all_claims_labeled AS
SELECT 
    ic.claim_id,
    ic.bene_id,
    ic.provider_id,
    ic.claim_start_dt,
    ic.claim_end_dt,
    ic.insc_claim_amt_reimbursed,
    ic.attending_physician,
    ic.deductible_amt_paid,
    'Inpatient' AS claim_type,
    p.potential_fraud
FROM inpatient_claims ic
INNER JOIN providers p ON p.provider_id = ic.provider_id

UNION ALL

SELECT 
    oc.claim_id,
    oc.bene_id,
    oc.provider_id,
    oc.claim_start_dt,
    oc.claim_end_dt,
    oc.insc_claim_amt_reimbursed,
    oc.attending_physician,
    oc.deductible_amt_paid,
    'Outpatient' AS claim_type,
    p.potential_fraud
FROM outpatient_claims oc
INNER JOIN providers p ON p.provider_id = oc.provider_id;


-- Quick verification
SELECT claim_type, potential_fraud, COUNT(*) AS claim_count
FROM all_claims_labeled
GROUP BY claim_type, potential_fraud
ORDER BY claim_type, potential_fraud;


-- Distribution of claim volumes per provider
WITH provider_volumes AS (
    SELECT 
        provider_id,
        COUNT(*) AS total_claims
    FROM all_claims_labeled
    GROUP BY provider_id
)
SELECT 
    MIN(total_claims) AS min_claims,
    ROUND(AVG(total_claims), 0) AS avg_claims,
    MAX(total_claims) AS max_claims,
    percentile_cont(0.50) WITHIN GROUP (ORDER BY total_claims) AS median,
    percentile_cont(0.75) WITHIN GROUP (ORDER BY total_claims) AS p75,
    percentile_cont(0.95) WITHIN GROUP (ORDER BY total_claims) AS p95,
    percentile_cont(0.99) WITHIN GROUP (ORDER BY total_claims) AS p99
FROM provider_volumes;


-- Top 50 providers by total claim volume
WITH provider_volumes AS (
    SELECT 
        provider_id,
        potential_fraud,
        COUNT(*) AS total_claims,
        SUM(insc_claim_amt_reimbursed) AS total_reimbursed
    FROM all_claims_labeled
    GROUP BY provider_id, potential_fraud
),
ranked AS (
    SELECT 
        provider_id,
        potential_fraud,
        total_claims,
        total_reimbursed,
        RANK() OVER (ORDER BY total_claims DESC) AS volume_rank,
        PERCENT_RANK() OVER (ORDER BY total_claims) AS pct_rank
    FROM provider_volumes
)
SELECT 
    volume_rank,
    provider_id,
    potential_fraud,
    total_claims,
    ROUND(total_reimbursed, 0) AS total_reimbursed,
    ROUND((pct_rank * 100)::numeric, 2) AS percentile
FROM ranked
WHERE volume_rank <= 50
ORDER BY volume_rank;


-- Fraud rate by volume decile (top 10% = decile 1, bottom 10% = decile 10)
WITH provider_volumes AS (
    SELECT 
        provider_id,
        potential_fraud,
        COUNT(*) AS total_claims
    FROM all_claims_labeled
    GROUP BY provider_id, potential_fraud
),
deciled AS (
    SELECT 
        provider_id,
        potential_fraud,
        total_claims,
        NTILE(10) OVER (ORDER BY total_claims DESC) AS volume_decile
    FROM provider_volumes
)
SELECT 
    volume_decile,
    COUNT(*) AS providers_in_decile,
    SUM(CASE WHEN potential_fraud = 'Yes' THEN 1 ELSE 0 END) AS fraud_labeled,
    ROUND(
        100.0 * SUM(CASE WHEN potential_fraud = 'Yes' THEN 1 ELSE 0 END) / COUNT(*),
        2
    ) AS fraud_rate_pct
FROM deciled
GROUP BY volume_decile
ORDER BY volume_decile;


-- Detection performance: flag top 10% by volume as suspicious
WITH provider_volumes AS (
    SELECT 
        provider_id,
        potential_fraud,
        COUNT(*) AS total_claims
    FROM all_claims_labeled
    GROUP BY provider_id, potential_fraud
),
scored AS (
    SELECT 
        provider_id,
        potential_fraud,
        total_claims,
        NTILE(10) OVER (ORDER BY total_claims DESC) AS volume_decile,
        CASE WHEN NTILE(10) OVER (ORDER BY total_claims DESC) = 1 THEN 'Flagged' ELSE 'Not Flagged' END AS my_flag
    FROM provider_volumes
),
confusion AS (
    SELECT 
        my_flag,
        potential_fraud,
        COUNT(*) AS providers
    FROM scored
    GROUP BY my_flag, potential_fraud
)
SELECT 
    -- True Positives: flagged AND actually fraud
    SUM(CASE WHEN my_flag = 'Flagged' AND potential_fraud = 'Yes' THEN providers ELSE 0 END) AS true_positives,
    -- False Positives: flagged but NOT fraud  
    SUM(CASE WHEN my_flag = 'Flagged' AND potential_fraud = 'No' THEN providers ELSE 0 END) AS false_positives,
    -- False Negatives: NOT flagged but actually fraud
    SUM(CASE WHEN my_flag = 'Not Flagged' AND potential_fraud = 'Yes' THEN providers ELSE 0 END) AS false_negatives,
    -- True Negatives: NOT flagged AND actually clean
    SUM(CASE WHEN my_flag = 'Not Flagged' AND potential_fraud = 'No' THEN providers ELSE 0 END) AS true_negatives,
    -- Metrics
    ROUND(
        100.0 * SUM(CASE WHEN my_flag = 'Flagged' AND potential_fraud = 'Yes' THEN providers ELSE 0 END)
        / NULLIF(SUM(CASE WHEN my_flag = 'Flagged' THEN providers ELSE 0 END), 0),
        2
    ) AS precision_pct,
    ROUND(
        100.0 * SUM(CASE WHEN my_flag = 'Flagged' AND potential_fraud = 'Yes' THEN providers ELSE 0 END)
        / NULLIF(SUM(CASE WHEN potential_fraud = 'Yes' THEN providers ELSE 0 END), 0),
        2
    ) AS recall_pct
FROM confusion;


-- Reimbursement baselines by claim type
SELECT 
    'Inpatient' AS claim_type,
    COUNT(*) AS total_claims,
    ROUND(AVG(insc_claim_amt_reimbursed), 2) AS mean_amt,
    ROUND(percentile_cont(0.50) WITHIN GROUP (ORDER BY insc_claim_amt_reimbursed)::numeric, 2) AS median,
    ROUND(percentile_cont(0.95) WITHIN GROUP (ORDER BY insc_claim_amt_reimbursed)::numeric, 2) AS p95,
    ROUND(MAX(insc_claim_amt_reimbursed), 2) AS max_amt
FROM inpatient_claims
UNION ALL
SELECT 
    'Outpatient',
    COUNT(*),
    ROUND(AVG(insc_claim_amt_reimbursed), 2),
    ROUND(percentile_cont(0.50) WITHIN GROUP (ORDER BY insc_claim_amt_reimbursed)::numeric, 2),
    ROUND(percentile_cont(0.95) WITHIN GROUP (ORDER BY insc_claim_amt_reimbursed)::numeric, 2),
    ROUND(MAX(insc_claim_amt_reimbursed), 2)
FROM outpatient_claims;


-- Providers ranked by average outpatient reimbursement
WITH provider_stats AS (
    SELECT 
        oc.provider_id,
        p.potential_fraud,
        COUNT(*) AS claim_count,
        ROUND(AVG(oc.insc_claim_amt_reimbursed), 2) AS avg_reimbursement,
        ROUND(SUM(oc.insc_claim_amt_reimbursed), 2) AS total_reimbursement
    FROM outpatient_claims oc
    INNER JOIN providers p ON p.provider_id = oc.provider_id
    GROUP BY oc.provider_id, p.potential_fraud
    HAVING COUNT(*) >= 20  -- filter noise: only providers with 20+ claims
)
SELECT 
    provider_id,
    potential_fraud,
    claim_count,
    avg_reimbursement,
    total_reimbursement,
    RANK() OVER (ORDER BY avg_reimbursement DESC) AS avg_rank
FROM provider_stats
ORDER BY avg_reimbursement DESC
LIMIT 30;


-- Fraud rate by outpatient reimbursement decile
WITH provider_stats AS (
    SELECT 
        oc.provider_id,
        p.potential_fraud,
        AVG(oc.insc_claim_amt_reimbursed) AS avg_reimbursement
    FROM outpatient_claims oc
    INNER JOIN providers p ON p.provider_id = oc.provider_id
    GROUP BY oc.provider_id, p.potential_fraud
    HAVING COUNT(*) >= 20
),
deciled AS (
    SELECT 
        provider_id,
        potential_fraud,
        avg_reimbursement,
        NTILE(10) OVER (ORDER BY avg_reimbursement DESC) AS reimbursement_decile
    FROM provider_stats
)
SELECT 
    reimbursement_decile,
    COUNT(*) AS providers_in_decile,
    SUM(CASE WHEN potential_fraud = 'Yes' THEN 1 ELSE 0 END) AS fraud_labeled,
    ROUND(
        100.0 * SUM(CASE WHEN potential_fraud = 'Yes' THEN 1 ELSE 0 END) / COUNT(*),
        2
    ) AS fraud_rate_pct
FROM deciled
GROUP BY reimbursement_decile
ORDER BY reimbursement_decile;


-- Detection performance: flag top 10% by reimbursement
WITH provider_stats AS (
    SELECT 
        oc.provider_id,
        p.potential_fraud,
        AVG(oc.insc_claim_amt_reimbursed) AS avg_reimbursement
    FROM outpatient_claims oc
    INNER JOIN providers p ON p.provider_id = oc.provider_id
    GROUP BY oc.provider_id, p.potential_fraud
    HAVING COUNT(*) >= 20
),
scored AS (
    SELECT 
        provider_id,
        potential_fraud,
        CASE 
            WHEN NTILE(10) OVER (ORDER BY avg_reimbursement DESC) = 1 
            THEN 'Flagged' 
            ELSE 'Not Flagged' 
        END AS my_flag
    FROM provider_stats
),
totals AS (
    SELECT
        SUM(CASE WHEN my_flag = 'Flagged' AND potential_fraud = 'Yes' THEN 1 ELSE 0 END) AS tp,
        SUM(CASE WHEN my_flag = 'Flagged' AND potential_fraud = 'No' THEN 1 ELSE 0 END) AS fp,
        SUM(CASE WHEN my_flag = 'Not Flagged' AND potential_fraud = 'Yes' THEN 1 ELSE 0 END) AS fn,
        SUM(CASE WHEN my_flag = 'Not Flagged' AND potential_fraud = 'No' THEN 1 ELSE 0 END) AS tn
    FROM scored
)
SELECT 
    tp AS true_positives,
    fp AS false_positives,
    fn AS false_negatives,
    tn AS true_negatives,
    ROUND(100.0 * tp / NULLIF(tp + fp, 0), 2) AS precision_pct,
    ROUND(100.0 * tp / NULLIF(tp + fn, 0), 2) AS recall_pct
FROM totals;


-- Alternative detector: flag providers in reimbursement deciles 4-6 (middle range)
WITH provider_stats AS (
    SELECT 
        oc.provider_id,
        p.potential_fraud,
        AVG(oc.insc_claim_amt_reimbursed) AS avg_reimbursement
    FROM outpatient_claims oc
    INNER JOIN providers p ON p.provider_id = oc.provider_id
    GROUP BY oc.provider_id, p.potential_fraud
    HAVING COUNT(*) >= 20
),
scored AS (
    SELECT 
        provider_id,
        potential_fraud,
        NTILE(10) OVER (ORDER BY avg_reimbursement DESC) AS reimb_decile
    FROM provider_stats
),
flagged AS (
    SELECT 
        provider_id,
        potential_fraud,
        CASE 
            WHEN reimb_decile BETWEEN 4 AND 6 THEN 'Flagged'
            ELSE 'Not Flagged'
        END AS my_flag
    FROM scored
),
totals AS (
    SELECT
        SUM(CASE WHEN my_flag = 'Flagged' AND potential_fraud = 'Yes' THEN 1 ELSE 0 END) AS tp,
        SUM(CASE WHEN my_flag = 'Flagged' AND potential_fraud = 'No' THEN 1 ELSE 0 END) AS fp,
        SUM(CASE WHEN my_flag = 'Not Flagged' AND potential_fraud = 'Yes' THEN 1 ELSE 0 END) AS fn,
        SUM(CASE WHEN my_flag = 'Not Flagged' AND potential_fraud = 'No' THEN 1 ELSE 0 END) AS tn
    FROM flagged
)
SELECT 
    tp AS true_positives,
    fp AS false_positives,
    fn AS false_negatives,
    tn AS true_negatives,
    ROUND(100.0 * tp / NULLIF(tp + fp, 0), 2) AS precision_pct,
    ROUND(100.0 * tp / NULLIF(tp + fn, 0), 2) AS recall_pct
FROM totals;


-- Per-provider: total claims and unique patients
WITH provider_patient_stats AS (
    SELECT 
        oc.provider_id,
        p.potential_fraud,
        COUNT(*) AS total_claims,
        COUNT(DISTINCT oc.bene_id) AS unique_patients,
        ROUND(COUNT(*)::numeric / COUNT(DISTINCT oc.bene_id), 3) AS claims_per_patient
    FROM outpatient_claims oc
    INNER JOIN providers p ON p.provider_id = oc.provider_id
    GROUP BY oc.provider_id, p.potential_fraud
    HAVING COUNT(*) >= 20
)
SELECT 
    MIN(claims_per_patient) AS min_ratio,
    ROUND(AVG(claims_per_patient), 3) AS mean_ratio,
    ROUND(percentile_cont(0.50) WITHIN GROUP (ORDER BY claims_per_patient)::numeric, 3) AS median,
    ROUND(percentile_cont(0.95) WITHIN GROUP (ORDER BY claims_per_patient)::numeric, 3) AS p95,
    ROUND(percentile_cont(0.99) WITHIN GROUP (ORDER BY claims_per_patient)::numeric, 3) AS p99,
    MAX(claims_per_patient) AS max_ratio
FROM provider_patient_stats;


-- Fraud concentration by claims-per-patient ratio
WITH provider_patient_stats AS (
    SELECT 
        oc.provider_id,
        p.potential_fraud,
        COUNT(*)::numeric / COUNT(DISTINCT oc.bene_id) AS claims_per_patient
    FROM outpatient_claims oc
    INNER JOIN providers p ON p.provider_id = oc.provider_id
    GROUP BY oc.provider_id, p.potential_fraud
    HAVING COUNT(*) >= 20
),
deciled AS (
    SELECT 
        provider_id,
        potential_fraud,
        claims_per_patient,
        NTILE(10) OVER (ORDER BY claims_per_patient DESC) AS ratio_decile
    FROM provider_patient_stats
)
SELECT 
    ratio_decile,
    COUNT(*) AS providers_in_decile,
    SUM(CASE WHEN potential_fraud = 'Yes' THEN 1 ELSE 0 END) AS fraud_labeled,
    ROUND(100.0 * SUM(CASE WHEN potential_fraud = 'Yes' THEN 1 ELSE 0 END) / COUNT(*), 2) AS fraud_rate_pct,
    ROUND(AVG(claims_per_patient)::numeric, 3) AS avg_ratio_in_decile
FROM deciled
GROUP BY ratio_decile
ORDER BY ratio_decile;


-- Bill-mill detector: flag top decile by claims-per-patient ratio
WITH provider_patient_stats AS (
    SELECT 
        oc.provider_id,
        p.potential_fraud,
        COUNT(*)::numeric / COUNT(DISTINCT oc.bene_id) AS claims_per_patient
    FROM outpatient_claims oc
    INNER JOIN providers p ON p.provider_id = oc.provider_id
    GROUP BY oc.provider_id, p.potential_fraud
    HAVING COUNT(*) >= 20
),
scored AS (
    SELECT 
        provider_id,
        potential_fraud,
        CASE 
            WHEN NTILE(10) OVER (ORDER BY claims_per_patient DESC) = 1 
            THEN 'Flagged' 
            ELSE 'Not Flagged' 
        END AS my_flag
    FROM provider_patient_stats
),
totals AS (
    SELECT
        SUM(CASE WHEN my_flag = 'Flagged' AND potential_fraud = 'Yes' THEN 1 ELSE 0 END) AS tp,
        SUM(CASE WHEN my_flag = 'Flagged' AND potential_fraud = 'No' THEN 1 ELSE 0 END) AS fp,
        SUM(CASE WHEN my_flag = 'Not Flagged' AND potential_fraud = 'Yes' THEN 1 ELSE 0 END) AS fn,
        SUM(CASE WHEN my_flag = 'Not Flagged' AND potential_fraud = 'No' THEN 1 ELSE 0 END) AS tn
    FROM scored
)
SELECT 
    tp AS true_positives,
    fp AS false_positives,
    fn AS false_negatives,
    tn AS true_negatives,
    ROUND(100.0 * tp / NULLIF(tp + fp, 0), 2) AS precision_pct,
    ROUND(100.0 * tp / NULLIF(tp + fn, 0), 2) AS recall_pct,
    ROUND(
        (2.0 * (100.0 * tp / NULLIF(tp + fp, 0)) * (100.0 * tp / NULLIF(tp + fn, 0)))
        / NULLIF((100.0 * tp / NULLIF(tp + fp, 0)) + (100.0 * tp / NULLIF(tp + fn, 0)), 0),
        2
    ) AS f1_score_pct
FROM totals;


-- Distribution: how many fraud-labeled providers has each patient seen?
WITH patient_fraud_provider_count AS (
    SELECT 
        oc.bene_id,
        COUNT(DISTINCT oc.provider_id) FILTER (WHERE p.potential_fraud = 'Yes') AS fraud_provider_count,
        COUNT(DISTINCT oc.provider_id) AS total_provider_count
    FROM outpatient_claims oc
    INNER JOIN providers p ON p.provider_id = oc.provider_id
    GROUP BY oc.bene_id
)
SELECT 
    fraud_provider_count,
    COUNT(*) AS patients,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_patients
FROM patient_fraud_provider_count
GROUP BY fraud_provider_count
ORDER BY fraud_provider_count
LIMIT 15;


-- For each provider, what % of their patients have ALSO been seen by ≥2 fraud providers?
WITH patient_fraud_count AS (
    -- Step A: For each patient, count how many fraud providers billed them
    SELECT 
        oc.bene_id,
        COUNT(DISTINCT oc.provider_id) FILTER (WHERE p.potential_fraud = 'Yes') AS fraud_providers_seen
    FROM outpatient_claims oc
    INNER JOIN providers p ON p.provider_id = oc.provider_id
    GROUP BY oc.bene_id
),
provider_overlap AS (
    -- Step B: For each provider, what fraction of their patients are "high-overlap"?
    SELECT 
        oc.provider_id,
        p.potential_fraud,
        COUNT(DISTINCT oc.bene_id) AS total_patients,
        COUNT(DISTINCT oc.bene_id) FILTER (WHERE pfc.fraud_providers_seen >= 2) AS overlapping_patients,
        ROUND(
            100.0 * COUNT(DISTINCT oc.bene_id) FILTER (WHERE pfc.fraud_providers_seen >= 2) 
            / COUNT(DISTINCT oc.bene_id),
            2
        ) AS overlap_pct
    FROM outpatient_claims oc
    INNER JOIN providers p ON p.provider_id = oc.provider_id
    INNER JOIN patient_fraud_count pfc ON pfc.bene_id = oc.bene_id
    GROUP BY oc.provider_id, p.potential_fraud
    HAVING COUNT(DISTINCT oc.bene_id) >= 20
)
SELECT 
    provider_id,
    potential_fraud,
    total_patients,
    overlapping_patients,
    overlap_pct
FROM provider_overlap
ORDER BY overlap_pct DESC
LIMIT 30;


-- Overlap detector: flag providers whose patients heavily overlap with other fraud providers
WITH patient_fraud_count AS (
    SELECT 
        oc.bene_id,
        COUNT(DISTINCT oc.provider_id) FILTER (WHERE p.potential_fraud = 'Yes') AS fraud_providers_seen
    FROM outpatient_claims oc
    INNER JOIN providers p ON p.provider_id = oc.provider_id
    GROUP BY oc.bene_id
),
provider_overlap AS (
    SELECT 
        oc.provider_id,
        p.potential_fraud,
        COUNT(DISTINCT oc.bene_id) AS total_patients,
        1.0 * COUNT(DISTINCT oc.bene_id) FILTER (WHERE pfc.fraud_providers_seen >= 2)
             / COUNT(DISTINCT oc.bene_id) AS overlap_ratio
    FROM outpatient_claims oc
    INNER JOIN providers p ON p.provider_id = oc.provider_id
    INNER JOIN patient_fraud_count pfc ON pfc.bene_id = oc.bene_id
    GROUP BY oc.provider_id, p.potential_fraud
    HAVING COUNT(DISTINCT oc.bene_id) >= 20
),
scored AS (
    SELECT 
        provider_id,
        potential_fraud,
        CASE 
            WHEN NTILE(10) OVER (ORDER BY overlap_ratio DESC) = 1 
            THEN 'Flagged' 
            ELSE 'Not Flagged' 
        END AS my_flag
    FROM provider_overlap
),
totals AS (
    SELECT
        SUM(CASE WHEN my_flag = 'Flagged' AND potential_fraud = 'Yes' THEN 1 ELSE 0 END) AS tp,
        SUM(CASE WHEN my_flag = 'Flagged' AND potential_fraud = 'No' THEN 1 ELSE 0 END) AS fp,
        SUM(CASE WHEN my_flag = 'Not Flagged' AND potential_fraud = 'Yes' THEN 1 ELSE 0 END) AS fn,
        SUM(CASE WHEN my_flag = 'Not Flagged' AND potential_fraud = 'No' THEN 1 ELSE 0 END) AS tn
    FROM scored
)
SELECT 
    tp AS true_positives,
    fp AS false_positives,
    fn AS false_negatives,
    tn AS true_negatives,
    ROUND(100.0 * tp / NULLIF(tp + fp, 0), 2) AS precision_pct,
    ROUND(100.0 * tp / NULLIF(tp + fn, 0), 2) AS recall_pct,
    ROUND(
        (2.0 * (100.0 * tp / NULLIF(tp + fp, 0)) * (100.0 * tp / NULLIF(tp + fn, 0)))
        / NULLIF((100.0 * tp / NULLIF(tp + fp, 0)) + (100.0 * tp / NULLIF(tp + fn, 0)), 0),
        2
    ) AS f1_score_pct
FROM totals;


-- =====================================================================
-- Combined Multi-Signal Fraud Detector
-- =====================================================================

WITH 
-- Signal 1: Volume (all claims: inpatient + outpatient)
volume_stats AS (
    SELECT 
        provider_id,
        COUNT(*) AS total_claims,
        NTILE(10) OVER (ORDER BY COUNT(*) DESC) AS volume_decile
    FROM all_claims_labeled
    GROUP BY provider_id
),

-- Signal 2: Reimbursement (outpatient only, ≥20 claims)
reimbursement_stats AS (
    SELECT 
        provider_id,
        AVG(insc_claim_amt_reimbursed) AS avg_reimb,
        NTILE(10) OVER (ORDER BY AVG(insc_claim_amt_reimbursed) DESC) AS reimb_decile
    FROM outpatient_claims
    GROUP BY provider_id
    HAVING COUNT(*) >= 20
),

-- Signal 3: Patient Network Overlap
patient_fraud_count AS (
    SELECT 
        oc.bene_id,
        COUNT(DISTINCT oc.provider_id) FILTER (WHERE p.potential_fraud = 'Yes') AS fraud_providers_seen
    FROM outpatient_claims oc
    INNER JOIN providers p ON p.provider_id = oc.provider_id
    GROUP BY oc.bene_id
),
overlap_stats AS (
    SELECT 
        oc.provider_id,
        1.0 * COUNT(DISTINCT oc.bene_id) FILTER (WHERE pfc.fraud_providers_seen >= 2)
             / COUNT(DISTINCT oc.bene_id) AS overlap_ratio,
        NTILE(10) OVER (
            ORDER BY 1.0 * COUNT(DISTINCT oc.bene_id) FILTER (WHERE pfc.fraud_providers_seen >= 2)
                          / COUNT(DISTINCT oc.bene_id) DESC
        ) AS overlap_decile
    FROM outpatient_claims oc
    INNER JOIN patient_fraud_count pfc ON pfc.bene_id = oc.bene_id
    GROUP BY oc.provider_id
    HAVING COUNT(DISTINCT oc.bene_id) >= 20
),

-- Combine all signals into a score
combined AS (
    SELECT 
        p.provider_id,
        p.potential_fraud,
        COALESCE(v.total_claims, 0) AS total_claims,
        COALESCE(r.avg_reimb, 0) AS avg_reimb,
        COALESCE(o.overlap_ratio, 0) AS overlap_ratio,
        -- Signal 1: Volume flag
        CASE WHEN v.volume_decile = 1 THEN 1 ELSE 0 END AS volume_flag,
        -- Signal 2: Middle-reimbursement flag
        CASE WHEN r.reimb_decile BETWEEN 4 AND 6 THEN 1 ELSE 0 END AS reimb_flag,
        -- Signal 3: Overlap flag
        CASE WHEN o.overlap_decile = 1 THEN 1 ELSE 0 END AS overlap_flag,
        -- Total fraud score
        (CASE WHEN v.volume_decile = 1 THEN 1 ELSE 0 END
         + CASE WHEN r.reimb_decile BETWEEN 4 AND 6 THEN 1 ELSE 0 END
         + CASE WHEN o.overlap_decile = 1 THEN 1 ELSE 0 END) AS fraud_score
    FROM providers p
    LEFT JOIN volume_stats v ON v.provider_id = p.provider_id
    LEFT JOIN reimbursement_stats r ON r.provider_id = p.provider_id
    LEFT JOIN overlap_stats o ON o.provider_id = p.provider_id
)
SELECT 
    fraud_score,
    COUNT(*) AS providers,
    SUM(CASE WHEN potential_fraud = 'Yes' THEN 1 ELSE 0 END) AS actual_fraud,
    ROUND(100.0 * SUM(CASE WHEN potential_fraud = 'Yes' THEN 1 ELSE 0 END) / COUNT(*), 2) AS fraud_rate_pct
FROM combined
GROUP BY fraud_score
ORDER BY fraud_score DESC;


WITH 
volume_stats AS (
    SELECT provider_id, NTILE(10) OVER (ORDER BY COUNT(*) DESC) AS volume_decile
    FROM all_claims_labeled GROUP BY provider_id
),
reimbursement_stats AS (
    SELECT provider_id, NTILE(10) OVER (ORDER BY AVG(insc_claim_amt_reimbursed) DESC) AS reimb_decile
    FROM outpatient_claims GROUP BY provider_id HAVING COUNT(*) >= 20
),
patient_fraud_count AS (
    SELECT oc.bene_id,
           COUNT(DISTINCT oc.provider_id) FILTER (WHERE p.potential_fraud = 'Yes') AS fraud_providers_seen
    FROM outpatient_claims oc
    INNER JOIN providers p ON p.provider_id = oc.provider_id
    GROUP BY oc.bene_id
),
overlap_stats AS (
    SELECT oc.provider_id,
           NTILE(10) OVER (ORDER BY 1.0 * COUNT(DISTINCT oc.bene_id) FILTER (WHERE pfc.fraud_providers_seen >= 2) 
                                    / COUNT(DISTINCT oc.bene_id) DESC) AS overlap_decile
    FROM outpatient_claims oc
    INNER JOIN patient_fraud_count pfc ON pfc.bene_id = oc.bene_id
    GROUP BY oc.provider_id HAVING COUNT(DISTINCT oc.bene_id) >= 20
),
scored AS (
    SELECT p.provider_id, p.potential_fraud,
        (CASE WHEN v.volume_decile = 1 THEN 1 ELSE 0 END
         + CASE WHEN r.reimb_decile BETWEEN 4 AND 6 THEN 1 ELSE 0 END
         + CASE WHEN o.overlap_decile = 1 THEN 1 ELSE 0 END) AS fraud_score
    FROM providers p
    LEFT JOIN volume_stats v ON v.provider_id = p.provider_id
    LEFT JOIN reimbursement_stats r ON r.provider_id = p.provider_id
    LEFT JOIN overlap_stats o ON o.provider_id = p.provider_id
),
totals AS (
    SELECT
        SUM(CASE WHEN fraud_score >= 2 AND potential_fraud = 'Yes' THEN 1 ELSE 0 END) AS tp,
        SUM(CASE WHEN fraud_score >= 2 AND potential_fraud = 'No' THEN 1 ELSE 0 END) AS fp,
        SUM(CASE WHEN fraud_score < 2 AND potential_fraud = 'Yes' THEN 1 ELSE 0 END) AS fn,
        SUM(CASE WHEN fraud_score < 2 AND potential_fraud = 'No' THEN 1 ELSE 0 END) AS tn
    FROM scored
)
SELECT 
    'Score >= 2 (Balanced)' AS threshold,
    tp AS true_positives,
    fp AS false_positives,
    fn AS false_negatives,
    tn AS true_negatives,
    ROUND(100.0 * tp / NULLIF(tp + fp, 0), 2) AS precision_pct,
    ROUND(100.0 * tp / NULLIF(tp + fn, 0), 2) AS recall_pct,
    ROUND(
        (2.0 * (100.0 * tp / NULLIF(tp + fp, 0)) * (100.0 * tp / NULLIF(tp + fn, 0)))
        / NULLIF((100.0 * tp / NULLIF(tp + fp, 0)) + (100.0 * tp / NULLIF(tp + fn, 0)), 0),
        2
    ) AS f1_score_pct
FROM totals;


WITH 
volume_stats AS (
    SELECT provider_id, NTILE(10) OVER (ORDER BY COUNT(*) DESC) AS volume_decile
    FROM all_claims_labeled GROUP BY provider_id
),
reimbursement_stats AS (
    SELECT provider_id, NTILE(10) OVER (ORDER BY AVG(insc_claim_amt_reimbursed) DESC) AS reimb_decile
    FROM outpatient_claims GROUP BY provider_id HAVING COUNT(*) >= 20
),
patient_fraud_count AS (
    SELECT oc.bene_id,
           COUNT(DISTINCT oc.provider_id) FILTER (WHERE p.potential_fraud = 'Yes') AS fraud_providers_seen
    FROM outpatient_claims oc
    INNER JOIN providers p ON p.provider_id = oc.provider_id
    GROUP BY oc.bene_id
),
overlap_stats AS (
    SELECT oc.provider_id,
           NTILE(10) OVER (ORDER BY 1.0 * COUNT(DISTINCT oc.bene_id) FILTER (WHERE pfc.fraud_providers_seen >= 2) 
                                    / COUNT(DISTINCT oc.bene_id) DESC) AS overlap_decile
    FROM outpatient_claims oc
    INNER JOIN patient_fraud_count pfc ON pfc.bene_id = oc.bene_id
    GROUP BY oc.provider_id HAVING COUNT(DISTINCT oc.bene_id) >= 20
),
scored AS (
    SELECT p.provider_id, p.potential_fraud,
        (CASE WHEN v.volume_decile = 1 THEN 1 ELSE 0 END
         + CASE WHEN r.reimb_decile BETWEEN 4 AND 6 THEN 1 ELSE 0 END
         + CASE WHEN o.overlap_decile = 1 THEN 1 ELSE 0 END) AS fraud_score
    FROM providers p
    LEFT JOIN volume_stats v ON v.provider_id = p.provider_id
    LEFT JOIN reimbursement_stats r ON r.provider_id = p.provider_id
    LEFT JOIN overlap_stats o ON o.provider_id = p.provider_id
),
totals AS (
    SELECT
        SUM(CASE WHEN fraud_score = 3 AND potential_fraud = 'Yes' THEN 1 ELSE 0 END) AS tp,
        SUM(CASE WHEN fraud_score = 3 AND potential_fraud = 'No' THEN 1 ELSE 0 END) AS fp,
        SUM(CASE WHEN fraud_score < 3 AND potential_fraud = 'Yes' THEN 1 ELSE 0 END) AS fn,
        SUM(CASE WHEN fraud_score < 3 AND potential_fraud = 'No' THEN 1 ELSE 0 END) AS tn
    FROM scored
)
SELECT 
    'Score = 3 (Strict)' AS threshold,
    tp AS true_positives,
    fp AS false_positives,
    fn AS false_negatives,
    tn AS true_negatives,
    ROUND(100.0 * tp / NULLIF(tp + fp, 0), 2) AS precision_pct,
    ROUND(100.0 * tp / NULLIF(tp + fn, 0), 2) AS recall_pct,
    ROUND(
        (2.0 * (100.0 * tp / NULLIF(tp + fp, 0)) * (100.0 * tp / NULLIF(tp + fn, 0)))
        / NULLIF((100.0 * tp / NULLIF(tp + fp, 0)) + (100.0 * tp / NULLIF(tp + fn, 0)), 0),
        2
    ) AS f1_score_pct
FROM totals;