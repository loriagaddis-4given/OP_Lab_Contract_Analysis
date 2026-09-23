-- =========================================================
-- Source Data Inventory and Validation
-- =========================================================

-- Displays the number of records contained in each source file.
SELECT 'lab_charge_master' AS dataset,
COUNT(*) AS row_count
FROM 'Lab Contract Review/lab_charge_master.csv'

UNION ALL

SELECT 'patient_charges',
COUNT(*) AS row_count
FROM 'Lab Contract Review/patient_charges.csv'

UNION ALL

SELECT 'patient_encounters',
COUNT(*) AS row_count
FROM 'Lab Contract Review/patient_encounters.csv'

UNION ALL

SELECT 'lab_fee_schedule',
COUNT(*) AS row_count
FROM 'Lab Contract Review/lab_fee_schedule.csv';


-- Displays a sample of the data in the lab_charge_master file.
SELECT *
FROM 'Lab Contract Review/lab_charge_master.csv'
ORDER BY description
LIMIT 10;


-- Displays a sample of the data in the patient_charges file.
SELECT *
FROM 'Lab Contract Review/patient_charges.csv'
ORDER BY svcDate
LIMIT 10;


-- Displays a sample of the data in the patient_encounters file.
SELECT *
FROM 'Lab Contract Review/patient_encounters.csv'
ORDER BY acctNum
LIMIT 10;


-- Displays a sample of the data in the lab_fee_schedule file.
SELECT *
FROM 'Lab Contract Review/lab_fee_schedule.csv'
ORDER BY CPT
LIMIT 10;


-- lab_charge_master file validation begins
-- Compares total records with distinct charge numbers to validate uniqueness.
SELECT
   COUNT (*) AS row_count,
   COUNT (DISTINCT chargeNum) as distinct_key_count
FROM 'Lab Contract Review/lab_charge_master.csv';


-- Identifies the specific charge numbers that violate the uniqueness rule.
-- A successful validation returns no rows.
SELECT
   chargeNum,
   COUNT(*) AS occurrences
FROM 'Lab Contract Review/lab_charge_master.csv'
GROUP BY chargeNum
HAVING COUNT(*) > 1;

-- Counts records with a missing chargeNum, the table's primary key.
-- A successful validation returns zero.
SELECT
    COUNT(*) FILTER (WHERE chargeNum IS NULL) AS "Missing Charge Numbers"
FROM 'Lab Contract Review/lab_charge_master.csv';


-- patient_charges file validation begins
-- Compares total records with distinct row numbers to validate uniqueness.
SELECT
   COUNT (*) AS row_count,
   COUNT (DISTINCT rowNum) as distinct_key_count
FROM 'Lab Contract Review/patient_charges.csv';


-- Identifies the specific row numbers that violate the uniqueness rule.
-- A successful validation returns no rows.
SELECT
    acctNum,
    chargeNum,
    svcDate,
    COUNT(*) AS transaction_count,
    SUM(qty) AS net_quantity
FROM 'Lab Contract Review/patient_charges.csv'
GROUP BY
    acctNum,
    chargeNum,
    svcDate
HAVING COUNT(*) > 1
   AND SUM(qty) > 0
ORDER BY
    acctNum,
    svcDate,
    chargeNum;

-- patient_encounters file validation begins
-- Compares total records with distinct account numbers to validate uniqueness.
SELECT
   COUNT (*) AS row_count,
   COUNT (DISTINCT acctNum) as distinct_key_count
FROM 'Lab Contract Review/patient_encounters.csv';


-- Counts records with a missing acctNum, the table's primary key.
-- A successful validation returns zero.
SELECT
    COUNT(*) FILTER (WHERE acctNum IS NULL) AS "Missing Account Numbers"
FROM 'Lab Contract Review/patient_encounters.csv';


-- lab_fee_schedule file validation begins
-- Compares total records with distinct CPT codes to validate uniqueness.
SELECT
   COUNT (*) AS row_count,
   COUNT (DISTINCT CPT) as distinct_key_count
FROM 'Lab Contract Review/lab_fee_schedule.csv';


-- Counts records with a missing CPT, the table's primary key.
-- A successful validation returns zero.
SELECT
    COUNT(*) FILTER (WHERE CPT IS NULL) AS "Missing CPT Codes"
FROM 'Lab Contract Review/lab_fee_schedule.csv';

-- Counts records with a missing CPT, the table's primary key.
-- A successful validation returns zero.
duckdb.sql("""
SELECT
   COUNT (*) AS row_count,
   COUNT (DISTINCT CPT) as distinct_key_count
FROM 'Lab Contract Review/lab_fee_schedule.csv';
""")


-- =========================================================
-- Cross-File Validation
-- =========================================================

-- Joins all for source tables and displays the complete combined
-- record structure to validate the table relationships.
SELECT
   *
FROM 'Lab Contract Review/patient_charges.csv' as c
JOIN 'Lab Contract Review/lab_charge_master.csv' as m
   ON c.chargeNum = m.chargeNum
JOIN 'Lab Contract Review/patient_encounters.csv' as v
   ON c.acctNum = v.acctNum
JOIN 'Lab Contract Review/lab_fee_schedule.csv' as f
   ON m.CPT = f.CPT

-- =========================================================
-- Account-Level Analysis Dataset
-- =========================================================

-- Creates the account level analysis dataset and calculates reimbursement rates at the current contract 
-- and proposed fee schedule amounts for analysis.
CREATE OR REPLACE TEMP VIEW account_level_analysis AS

SELECT
   v.acctNum AS "Account #",
   c.chargeNum AS "Charge #",
   m.description AS "Charge Description",
   c.qty AS "Qty",
   CAST((c.qty * m.price) AS DECIMAL(10, 2)) AS "Charge Amt",
   CAST(((c.qty * m.price) * .8) AS DECIMAL(10, 2)) AS "Current Contract Allowed Amt",
   CAST((f.fee) AS DECIMAL(10, 2)) AS "Proposed Fee Schedule Allowed Amt",
   (CAST(((c.qty * m.price) * .8) AS DECIMAL(10, 2))) -  (CAST((f.fee) AS DECIMAL(10, 2))) AS "Allowed Amt Difference (Current - Proposed)",
   CAST(((c.qty * m.price) - ((c.qty * m.price) * .8)) AS DECIMAL(10,2)) AS "Current Contractual Amt",
   CAST(((c.qty * m.price) - (c.qty * f.fee)) AS DECIMAL(10, 2)) AS "Proposed Fee Schedule Contractual Amt",
   (CAST(((c.qty * m.price) - ((c.qty * m.price) * .8)) AS DECIMAL(10,2)) - CAST(((c.qty * m.price) - (f.fee)) AS DECIMAL(10, 2))) AS "Contractual Amt Difference (Current - Proposed)" 
FROM 'Lab Contract Review/patient_charges.csv' as c
JOIN 'Lab Contract Review/lab_charge_master.csv' as m
   ON c.chargeNum = m.chargeNum
JOIN 'Lab Contract Review/patient_encounters.csv' as v
   ON c.acctNum = v.acctNum
JOIN 'Lab Contract Review/lab_fee_schedule.csv' as f
   ON m.CPT = f.CPT;


-- Displays a limited preview of the dataset previously created for analysis.
SELECT *
FROM account_level_analysis
ORDER BY "Account #", "Charge #"
LIMIT 20;

-- =========================================================
-- Charge-Code Summary
-- =========================================================

-- Summarizes the financial activity by charge code and description combining all individual patient charges.
-- Allows comparison of the total differences in the allowed amounts and contractual amounts between the current
-- contract rates and the new proposed fee schedule.
SELECT
   c.chargeNum as "Charge #",
   m.description as "Charge Description",
   SUM(c.qty) as "Net Quantity",
   SUM(CAST((c.qty * m.price) AS DECIMAL(10, 2))) AS "Total Charges",
   SUM(CAST(((c.qty * m.price) * .8) AS DECIMAL(10, 2))) AS "Total Current Contract Allowed Amt",
   SUM(CAST((c.qty * f.fee) AS DECIMAL(10, 2))) AS "Total Proposed Fee Schedule Allowed Amt",
   (SUM(CAST(((c.qty * m.price) * .8) AS DECIMAL(10, 2))) - SUM(CAST((c.qty * f.fee) AS DECIMAL(10, 2)))) AS "Total Allowed Amt Difference (Current - Proposed)",
   SUM(CAST(((c.qty * m.price) - ((c.qty * m.price) * .8)) AS DECIMAL(10,2))) AS "Total Current Contractual Amt",
   SUM(CAST(((c.qty * m.price) - (c.qty * f.fee)) AS DECIMAL(10, 2))) AS "Total Proposed Fee Schedule Contractual Amt",
   SUM((CAST(((c.qty * m.price) - ((c.qty * m.price) * .8)) AS DECIMAL(10,2)) - CAST(((c.qty * m.price) - (c.qty * f.fee)) AS DECIMAL(10, 2)))) AS "Total Contractual Amt Difference (Current - Proposed)" 
FROM 'Lab Contract Review/patient_charges.csv' as c
JOIN 'Lab Contract Review/lab_charge_master.csv' as m
   ON c.chargeNum = m.chargeNum
JOIN 'Lab Contract Review/patient_encounters.csv' as v
   ON c.acctNum = v.acctNum
JOIN 'Lab Contract Review/lab_fee_schedule.csv' as f
   ON m.CPT = f.CPT
GROUP BY c.chargeNum, m.description
ORDER BY "Total Allowed Amt Difference (Current - Proposed)" DESC; 


-- =========================================================
-- Overall Financial Summary
-- =========================================================

-- Aggregates all lab charges into a single financial summary. 
-- Created CTEs to deal with a rounding issue that was occurring and 
-- preventing the allowed amount and contractual amount differences from 
-- calculating correctly.
WITH line_amounts AS (
    SELECT
        CAST(c.qty * m.price AS DECIMAL(18, 2))
            AS charge_amount,

        CAST((c.qty * m.price) * 0.80 AS DECIMAL(18, 2))
            AS current_allowed_amount,

        CAST(c.qty * f.fee AS DECIMAL(18, 2))
            AS proposed_allowed_amount

    FROM 'Lab Contract Review/patient_charges.csv' AS c

    JOIN 'Lab Contract Review/lab_charge_master.csv' AS m
        ON c.chargeNum = m.chargeNum

    JOIN 'Lab Contract Review/patient_encounters.csv' AS v
        ON c.acctNum = v.acctNum

    JOIN 'Lab Contract Review/lab_fee_schedule.csv' AS f
        ON m.CPT = f.CPT
),

totals AS (
    SELECT
        SUM(charge_amount) AS total_charges,
        SUM(current_allowed_amount) AS current_allowed,
        SUM(proposed_allowed_amount) AS proposed_allowed
    FROM line_amounts
)

SELECT
    total_charges
        AS "Total Charges",

    current_allowed
        AS "Total Current Contract Allowed Amt",

    proposed_allowed
        AS "Total Proposed Fee Schedule Allowed Amt",

    current_allowed - proposed_allowed
        AS "Total Allowed Amt Difference (Current - Proposed)",

    total_charges - current_allowed
        AS "Total Current Contractual Amt",

    total_charges - proposed_allowed
        AS "Total Proposed Fee Schedule Contractual Amt",

    (total_charges - current_allowed)
        - (total_charges - proposed_allowed)
        AS "Total Contractual Amt Difference (Current - Proposed)",

    (current_allowed - proposed_allowed)
        + (
            (total_charges - current_allowed)
            - (total_charges - proposed_allowed)
          )
        AS "Reconciliation Check"

FROM totals;
