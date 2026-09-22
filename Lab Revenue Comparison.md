# Lab Contract Reimbursement Analysis: Percent of Charges vs. Fee Schedule

   This project evaluates the financial impact of a proposed change to a rural hospital’s managed care contract with a major payer. Under the current agreement, outpatient services are reimbursed based on a percentage of billed charges. During contract renewal negotiations, the payer proposed moving outpatient laboratory services to a fixed fee schedule. The hospital requested an analysis of two years of outpatient lab activity to compare the current and proposed reimbursement methods and identify the tests driving the financial variance.
To protect confidential patient information and contract terms, this portfolio recreation uses fully synthetic visit, laboratory charge-master, and patient-charge data. The proposed payer fee schedule was also simulated using CMS Clinical Laboratory Fee Schedule rates increased by 25%, or 125% of the CMS rate. I performed the analysis with DuckDB SQL in a Jupyter Notebook.
This project is based on a real-world analysis I previously completed, but all data, reimbursement rates, and results presented here are synthetic and illustrative.

**Tools:** Jupyter Notebook, DuckDB SQL, Python (DuckDB package);  <br>**Data Source:** Synthetic data created for portfolio demonstration; no protected health information or actual contract materials included.

## Project Objectives

 - Quantify outpatient laboratory volume and billed charges from January 1, 2024 through December 31, 2025
 - Estimate reimbursement under the current percent-of-charges methodology
 - Model reimbursement under the proposed laboratory fee schedule
 - Compare the two methodologies to calculate the estimated dollar and percentage variance
 - Identify the laboratory tests contributing most to the projected gains or losses


```python
import duckdb
```

## Source Files and Data Limitations

   The project uses synthetic CSV files stored in the 'data/raw' directory. The data was created solely to demonstrate data validation, relational data modeling, SQL analysis, and data visualization techniques. It does not represent real patients, encounters, or healthcare activity.

## Source Data Inventory


```python
duckdb.sql("""
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
""")
```




    ┌────────────────────┬───────────┐
    │      dataset       │ row_count │
    │      varchar       │   int64   │
    ├────────────────────┼───────────┤
    │ lab_charge_master  │        81 │
    │ patient_charges    │      1450 │
    │ patient_encounters │      1200 │
    │ lab_fee_schedule   │        81 │
    └────────────────────┴───────────┘



The following queries display a small sample from each source table to show its structure and representative values before validation.


```python
duckdb.sql("""
SELECT *
FROM 'Lab Contract Review/lab_charge_master.csv'
ORDER BY description
LIMIT 10;
""")
```




    ┌───────────┬───────────────────────────────────┬─────────┬───────┬────────┐
    │ chargeNum │            description            │ revCode │  CPT  │ price  │
    │  varchar  │              varchar              │ varchar │ int64 │ double │
    ├───────────┼───────────────────────────────────┼─────────┼───────┼────────┤
    │ LAB100052 │ ABO Blood Typing                  │ 0305    │ 86900 │   88.0 │
    │ LAB100036 │ Alanine Aminotransferase          │ 0301    │ 84460 │   59.0 │
    │ LAB100007 │ Albumin                           │ 0301    │ 82040 │   62.0 │
    │ LAB100030 │ Alkaline Phosphatase              │ 0301    │ 84075 │   61.0 │
    │ LAB100009 │ Amylase                           │ 0301    │ 82150 │  104.0 │
    │ LAB100068 │ Antimicrobial Susceptibility, MIC │ 0306    │ 87186 │  167.0 │
    │ LAB100054 │ Antinuclear Antibody Screen       │ 0302    │ 86038 │  174.0 │
    │ LAB100028 │ B-Type Natriuretic Peptide        │ 0301    │ 83880 │  319.0 │
    │ LAB100066 │ Bacterial Culture, Other Source   │ 0306    │ 87070 │  139.0 │
    │ LAB100067 │ Bacterial Isolate Identification  │ 0306    │ 87077 │  128.0 │
    └───────────┴───────────────────────────────────┴─────────┴───────┴────────┘
      10 rows                                                        5 columns




```python
duckdb.sql("""
SELECT *
FROM 'Lab Contract Review/patient_charges.csv'
ORDER BY svcDate
LIMIT 10;
""")
```




    ┌────────┬────────────┬───────────┬────────────┬───────┐
    │ rowNum │  acctNum   │ chargeNum │  svcDate   │  qty  │
    │ int64  │  varchar   │  varchar  │    date    │ int64 │
    ├────────┼────────────┼───────────┼────────────┼───────┤
    │      1 │ ACCT000001 │ LAB100081 │ 2024-01-01 │     1 │
    │      2 │ ACCT000002 │ LAB100077 │ 2024-01-01 │     1 │
    │      3 │ ACCT000003 │ LAB100077 │ 2024-01-02 │     1 │
    │      4 │ ACCT000004 │ LAB100048 │ 2024-01-03 │     1 │
    │      5 │ ACCT000005 │ LAB100021 │ 2024-01-04 │     1 │
    │      6 │ ACCT000006 │ LAB100018 │ 2024-01-04 │     1 │
    │      7 │ ACCT000007 │ LAB100021 │ 2024-01-05 │     1 │
    │      8 │ ACCT000008 │ LAB100077 │ 2024-01-05 │     1 │
    │      9 │ ACCT000009 │ LAB100001 │ 2024-01-06 │     1 │
    │     10 │ ACCT000009 │ LAB100031 │ 2024-01-06 │     1 │
    └────────┴────────────┴───────────┴────────────┴───────┘
      10 rows                                    5 columns




```python
duckdb.sql("""
SELECT *
FROM 'Lab Contract Review/patient_encounters.csv'
ORDER BY acctNum
LIMIT 10;
""")
```




    ┌────────────┬────────────┐
    │  acctNum   │ admitDate  │
    │  varchar   │    date    │
    ├────────────┼────────────┤
    │ ACCT000001 │ 2024-01-01 │
    │ ACCT000002 │ 2024-01-01 │
    │ ACCT000003 │ 2024-01-02 │
    │ ACCT000004 │ 2024-01-03 │
    │ ACCT000005 │ 2024-01-04 │
    │ ACCT000006 │ 2024-01-04 │
    │ ACCT000007 │ 2024-01-05 │
    │ ACCT000008 │ 2024-01-05 │
    │ ACCT000009 │ 2024-01-06 │
    │ ACCT000010 │ 2024-01-07 │
    └────────────┴────────────┘
      10 rows       2 columns




```python
duckdb.sql("""
SELECT *
FROM 'Lab Contract Review/lab_fee_schedule.csv'
ORDER BY CPT
LIMIT 10;
""")
```




    ┌───────┬───────────────────────────────┬────────┐
    │  CPT  │          description          │  fee   │
    │ int64 │            varchar            │ double │
    ├───────┼───────────────────────────────┼────────┤
    │ 80048 │ Basic Metabolic Panel         │  10.58 │
    │ 80051 │ Electrolyte Panel             │   8.76 │
    │ 80053 │ Comprehensive Metabolic Panel │   13.2 │
    │ 80061 │ Lipid Panel                   │  16.74 │
    │ 80069 │ Renal Function Panel          │  10.85 │
    │ 80076 │ Hepatic Function Panel        │  10.21 │
    │ 80162 │ Digoxin Level                 │   16.6 │
    │ 80202 │ Vancomycin Level              │  16.93 │
    │ 80307 │ Presumptive Drug Screen       │  77.68 │
    │ 81001 │ Urinalysis with Microscopy    │   3.96 │
    └───────┴───────────────────────────────┴────────┘
      10 rows                              3 columns



## Source Data Validation

### 'lab_charge_master' Validation

The following query verifies that each charge number uniquely identifies one record.


```python
duckdb.sql("""
SELECT
   COUNT (*) AS row_count,
   COUNT (DISTINCT chargeNum) as distinct_key_count
FROM 'Lab Contract Review/lab_charge_master.csv';
""")
```




    ┌───────────┬────────────────────┐
    │ row_count │ distinct_key_count │
    │   int64   │       int64        │
    ├───────────┼────────────────────┤
    │        81 │                 81 │
    └───────────┴────────────────────┘




```python
duckdb.sql("""
SELECT
   chargeNum,
   COUNT(*) AS occurrences
FROM 'Lab Contract Review/lab_charge_master.csv'
GROUP BY chargeNum
HAVING COUNT(*) > 1;
""")
```




    ┌───────────┬─────────────┐
    │ chargeNum │ occurrences │
    │  varchar  │    int64    │
    └───────────┴─────────────┘
              0 rows         



The following query checks required fields for missing values.


```python
duckdb.sql("""
SELECT
    COUNT(*) FILTER (WHERE chargeNum IS NULL) AS "Missing Charge Numbers"
FROM 'Lab Contract Review/lab_charge_master.csv';
""")
```




    ┌────────────────────────┐
    │ Missing Charge Numbers │
    │         int64          │
    ├────────────────────────┤
    │                      0 │
    └────────────────────────┘



### 'patient_charges' Validation

The following query verifies that the sequential rowNum field uniquely identifies every charge record.


```python
duckdb.sql("""
SELECT
   COUNT (*) AS row_count,
   COUNT (DISTINCT rowNum) as distinct_key_count
FROM 'Lab Contract Review/patient_charges.csv';
""")
```




    ┌───────────┬────────────────────┐
    │ row_count │ distinct_key_count │
    │   int64   │       int64        │
    ├───────────┼────────────────────┤
    │      1450 │               1450 │
    └───────────┴────────────────────┘



Charge corrections may produce multiple records for the same account, charge number, and service date because an incorrect charge is retained with an offsetting negative quantity. The following query excludes fully reversed charges and identifies repeated charge combinations that retain a positive net quantity for further review.


```python
duckdb.sql("""
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
""")
```




    ┌─────────┬───────────┬─────────┬───────────────────┬──────────────┐
    │ acctNum │ chargeNum │ svcDate │ transaction_count │ net_quantity │
    │ varchar │  varchar  │  date   │       int64       │    int128    │
    └─────────┴───────────┴─────────┴───────────────────┴──────────────┘
                                   0 rows                             



### 'patient_encounters' Validation

The following query verifies that each account number identifies one unique record.


```python
duckdb.sql("""
SELECT
   COUNT (*) AS row_count,
   COUNT (DISTINCT acctNum) as distinct_key_count
FROM 'Lab Contract Review/patient_encounters.csv';
""")
```




    ┌───────────┬────────────────────┐
    │ row_count │ distinct_key_count │
    │   int64   │       int64        │
    ├───────────┼────────────────────┤
    │      1200 │               1200 │
    └───────────┴────────────────────┘



The following query checks required fields for missing values.


```python
duckdb.sql("""
SELECT
    COUNT(*) FILTER (WHERE acctNum IS NULL) AS "Missing Account Numbers"
FROM 'Lab Contract Review/patient_encounters.csv';
""")
```




    ┌─────────────────────────┐
    │ Missing Account Numbers │
    │          int64          │
    ├─────────────────────────┤
    │                       0 │
    └─────────────────────────┘



### 'lab_fee_schedule' Validation

The following query verifies that each CPT code identifies one unique record.


```python
duckdb.sql("""
SELECT
   COUNT (*) AS row_count,
   COUNT (DISTINCT CPT) as distinct_key_count
FROM 'Lab Contract Review/lab_fee_schedule.csv';
""")
```




    ┌───────────┬────────────────────┐
    │ row_count │ distinct_key_count │
    │   int64   │       int64        │
    ├───────────┼────────────────────┤
    │        81 │                 81 │
    └───────────┴────────────────────┘



The following query checks required fields for missing values.


```python
duckdb.sql("""
SELECT
    COUNT(*) FILTER (WHERE CPT IS NULL) AS "Missing Account Numbers"
FROM 'Lab Contract Review/lab_fee_schedule.csv';
""")
```




    ┌─────────────────────────┐
    │ Missing Account Numbers │
    │          int64          │
    ├─────────────────────────┤
    │                       0 │
    └─────────────────────────┘




```python
duckdb.sql("""
SELECT
   COUNT (*) AS row_count,
   COUNT (DISTINCT chargeNum) as distinct_key_count
FROM 'Lab Contract Review/lab_charge_master.csv';
""")
```




    ┌───────────┬────────────────────┐
    │ row_count │ distinct_key_count │
    │   int64   │       int64        │
    ├───────────┼────────────────────┤
    │        81 │                 81 │
    └───────────┴────────────────────┘



The following query joins the four validated source tables to create the analysis dataset. patient_charges provides the transaction-level records, while patient_encounters, lab_charge_master, and lab_fee_schedule supply the related encounter, charge-description, and proposed reimbursement information. The selected columns avoid duplicating the foreign-key fields used in the joins.


```python
duckdb.sql("""
SELECT
   *
FROM 'Lab Contract Review/patient_charges.csv' as c
JOIN 'Lab Contract Review/lab_charge_master.csv' as m
   ON c.chargeNum = m.chargeNum
JOIN 'Lab Contract Review/patient_encounters.csv' as v
   ON c.acctNum = v.acctNum
JOIN 'Lab Contract Review/lab_fee_schedule.csv' as f
   ON m.CPT = f.CPT
""")
```




    ┌────────┬────────────┬───────────┬────────────┬───────┬───────────┬────────────────────────────────────────┬─────────┬───────┬────────┬────────────┬────────────┬───────┬────────────────────────────────────────┬────────┐
    │ rowNum │  acctNum   │ chargeNum │  svcDate   │  qty  │ chargeNum │              description               │ revCode │  CPT  │ price  │  acctNum   │ admitDate  │  CPT  │              description               │  fee   │
    │ int64  │  varchar   │  varchar  │    date    │ int64 │  varchar  │                varchar                 │ varchar │ int64 │ double │  varchar   │    date    │ int64 │                varchar                 │ double │
    ├────────┼────────────┼───────────┼────────────┼───────┼───────────┼────────────────────────────────────────┼─────────┼───────┼────────┼────────────┼────────────┼───────┼────────────────────────────────────────┼────────┤
    │      1 │ ACCT000001 │ LAB100081 │ 2024-01-01 │     1 │ LAB100081 │ Presumptive Drug Screen                │ 0309    │ 80307 │  258.0 │ ACCT000001 │ 2024-01-01 │ 80307 │ Presumptive Drug Screen                │  77.68 │
    │      2 │ ACCT000002 │ LAB100077 │ 2024-01-01 │     1 │ LAB100077 │ Urinalysis without Microscopy          │ 0307    │ 81003 │   51.0 │ ACCT000002 │ 2024-01-01 │ 81003 │ Urinalysis without Microscopy          │   2.81 │
    │      3 │ ACCT000003 │ LAB100077 │ 2024-01-02 │     1 │ LAB100077 │ Urinalysis without Microscopy          │ 0307    │ 81003 │   51.0 │ ACCT000003 │ 2024-01-02 │ 81003 │ Urinalysis without Microscopy          │   2.81 │
    │      4 │ ACCT000004 │ LAB100048 │ 2024-01-03 │     1 │ LAB100048 │ Prothrombin Time                       │ 0305    │ 85610 │   73.0 │ ACCT000004 │ 2024-01-03 │ 85610 │ Prothrombin Time                       │   5.36 │
    │      5 │ ACCT000005 │ LAB100021 │ 2024-01-04 │     1 │ LAB100021 │ Glucose, Point of Care                 │ 0301    │ 82962 │   42.0 │ ACCT000005 │ 2024-01-04 │ 82962 │ Glucose, Point of Care                 │    4.1 │
    │      6 │ ACCT000006 │ LAB100018 │ 2024-01-04 │     1 │ LAB100018 │ Ferritin                               │ 0301    │ 82728 │  134.0 │ ACCT000006 │ 2024-01-04 │ 82728 │ Ferritin                               │  17.04 │
    │      7 │ ACCT000007 │ LAB100021 │ 2024-01-05 │     1 │ LAB100021 │ Glucose, Point of Care                 │ 0301    │ 82962 │   42.0 │ ACCT000007 │ 2024-01-05 │ 82962 │ Glucose, Point of Care                 │    4.1 │
    │      8 │ ACCT000008 │ LAB100077 │ 2024-01-05 │     1 │ LAB100077 │ Urinalysis without Microscopy          │ 0307    │ 81003 │   51.0 │ ACCT000008 │ 2024-01-05 │ 81003 │ Urinalysis without Microscopy          │   2.81 │
    │      9 │ ACCT000009 │ LAB100001 │ 2024-01-06 │     1 │ LAB100001 │ Basic Metabolic Panel                  │ 0301    │ 80048 │  168.0 │ ACCT000009 │ 2024-01-06 │ 80048 │ Basic Metabolic Panel                  │  10.58 │
    │     10 │ ACCT000009 │ LAB100031 │ 2024-01-06 │     1 │ LAB100031 │ Potassium                              │ 0301    │ 84132 │   51.0 │ ACCT000009 │ 2024-01-06 │ 84132 │ Potassium                              │   5.95 │
    │      · │     ·      │     ·     │     ·      │     · │     ·     │     ·                                  │  ·      │   ·   │     ·  │     ·      │     ·      │   ·   │     ·                                  │     ·  │
    │      · │     ·      │     ·     │     ·      │     · │     ·     │     ·                                  │  ·      │   ·   │     ·  │     ·      │     ·      │   ·   │     ·                                  │     ·  │
    │      · │     ·      │     ·     │     ·      │     · │     ·     │     ·                                  │  ·      │   ·   │     ·  │     ·      │     ·      │   ·   │     ·                                  │     ·  │
    │   1441 │ ACCT001191 │ LAB100044 │ 2025-12-29 │     1 │ LAB100044 │ Complete Blood Count with Differential │ 0305    │ 85025 │  118.0 │ ACCT001191 │ 2025-12-29 │ 85025 │ Complete Blood Count with Differential │   9.71 │
    │   1442 │ ACCT001192 │ LAB100055 │ 2025-12-29 │     1 │ LAB100055 │ C-Reactive Protein                     │ 0302    │ 86140 │   93.0 │ ACCT001192 │ 2025-12-29 │ 86140 │ C-Reactive Protein                     │   6.48 │
    │   1443 │ ACCT001193 │ LAB100020 │ 2025-12-30 │     1 │ LAB100020 │ Glucose, Quantitative                  │ 0301    │ 82947 │   49.0 │ ACCT001193 │ 2025-12-30 │ 82947 │ Glucose, Quantitative                  │   4.91 │
    │   1444 │ ACCT001194 │ LAB100001 │ 2025-12-30 │     1 │ LAB100001 │ Basic Metabolic Panel                  │ 0301    │ 80048 │  168.0 │ ACCT001194 │ 2025-12-30 │ 80048 │ Basic Metabolic Panel                  │  10.58 │
    │   1445 │ ACCT001195 │ LAB100066 │ 2025-12-30 │     1 │ LAB100066 │ Bacterial Culture, Other Source        │ 0306    │ 87070 │  139.0 │ ACCT001195 │ 2025-12-30 │ 87070 │ Bacterial Culture, Other Source        │  10.78 │
    │   1446 │ ACCT001196 │ LAB100027 │ 2025-12-31 │     1 │ LAB100027 │ Magnesium                              │ 0301    │ 83735 │   77.0 │ ACCT001196 │ 2025-12-31 │ 83735 │ Magnesium                              │   8.38 │
    │   1447 │ ACCT001197 │ LAB100022 │ 2025-12-31 │     1 │ LAB100022 │ Hemoglobin A1c                         │ 0301    │ 83036 │  106.0 │ ACCT001197 │ 2025-12-31 │ 83036 │ Hemoglobin A1c                         │  12.14 │
    │   1448 │ ACCT001198 │ LAB100020 │ 2025-12-31 │     1 │ LAB100020 │ Glucose, Quantitative                  │ 0301    │ 82947 │   49.0 │ ACCT001198 │ 2025-12-31 │ 82947 │ Glucose, Quantitative                  │   4.91 │
    │   1449 │ ACCT001199 │ LAB100077 │ 2025-12-31 │     1 │ LAB100077 │ Urinalysis without Microscopy          │ 0307    │ 81003 │   51.0 │ ACCT001199 │ 2025-12-31 │ 81003 │ Urinalysis without Microscopy          │   2.81 │
    │   1450 │ ACCT001200 │ LAB100021 │ 2025-12-31 │     1 │ LAB100021 │ Glucose, Point of Care                 │ 0301    │ 82962 │   42.0 │ ACCT001200 │ 2025-12-31 │ 82962 │ Glucose, Point of Care                 │    4.1 │
    └────────┴────────────┴───────────┴────────────┴───────┴───────────┴────────────────────────────────────────┴─────────┴───────┴────────┴────────────┴────────────┴───────┴────────────────────────────────────────┴────────┘
      1450 rows (20 shown)                                                                                                                                                                                          15 columns



The join query returned the number of rows expected and did not unexpectedly multiply or omit charge records.

The following query creates the account-level analysis dataset by combining charge activity with the current contract and proposed fee schedule amounts. A limited preview is displayed for verification; subsequent queries summarize the results by charge code and across the full population.


```python
duckdb.sql("""
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
   CAST(((c.qty * m.price) - (f.fee)) AS DECIMAL(10, 2)) AS "Proposed Fee Schedule Contractual Amt",
   (CAST(((c.qty * m.price) - ((c.qty * m.price) * .8)) AS DECIMAL(10,2)) - CAST(((c.qty * m.price) - (f.fee)) AS DECIMAL(10, 2))) AS "Contractual Amt Difference (Current - Proposed)" 
FROM 'Lab Contract Review/patient_charges.csv' as c
JOIN 'Lab Contract Review/lab_charge_master.csv' as m
   ON c.chargeNum = m.chargeNum
JOIN 'Lab Contract Review/patient_encounters.csv' as v
   ON c.acctNum = v.acctNum
JOIN 'Lab Contract Review/lab_fee_schedule.csv' as f
   ON m.CPT = f.CPT
ORDER BY m.description
LIMIT 20
""")
```




    ┌────────────┬───────────┬──────────────────────────┬───────┬───────────────┬──────────────────────────────┬───────────────────────────────────┬─────────────────────────────────────────────┬─────────────────────────┬───────────────────────────────────────┬─────────────────────────────────────────────────┐
    │ Account #  │ Charge #  │    Charge Description    │  Qty  │  Charge Amt   │ Current Contract Allowed Amt │ Proposed Fee Schedule Allowed Amt │ Allowed Amt Difference (Current - Proposed) │ Current Contractual Amt │ Proposed Fee Schedule Contractual Amt │ Contractual Amt Difference (Current - Proposed) │
    │  varchar   │  varchar  │         varchar          │ int64 │ decimal(10,2) │        decimal(10,2)         │           decimal(10,2)           │                decimal(11,2)                │      decimal(10,2)      │             decimal(10,2)             │                  decimal(11,2)                  │
    ├────────────┼───────────┼──────────────────────────┼───────┼───────────────┼──────────────────────────────┼───────────────────────────────────┼─────────────────────────────────────────────┼─────────────────────────┼───────────────────────────────────────┼─────────────────────────────────────────────────┤
    │ ACCT000834 │ LAB100052 │ ABO Blood Typing         │     1 │         88.00 │                        70.40 │                              3.74 │                                       66.66 │                   17.60 │                                 84.26 │                                          -66.66 │
    │ ACCT000780 │ LAB100052 │ ABO Blood Typing         │     1 │         88.00 │                        70.40 │                              3.74 │                                       66.66 │                   17.60 │                                 84.26 │                                          -66.66 │
    │ ACCT001075 │ LAB100052 │ ABO Blood Typing         │     1 │         88.00 │                        70.40 │                              3.74 │                                       66.66 │                   17.60 │                                 84.26 │                                          -66.66 │
    │ ACCT000017 │ LAB100052 │ ABO Blood Typing         │     1 │         88.00 │                        70.40 │                              3.74 │                                       66.66 │                   17.60 │                                 84.26 │                                          -66.66 │
    │ ACCT000977 │ LAB100052 │ ABO Blood Typing         │     1 │         88.00 │                        70.40 │                              3.74 │                                       66.66 │                   17.60 │                                 84.26 │                                          -66.66 │
    │ ACCT000327 │ LAB100052 │ ABO Blood Typing         │     1 │         88.00 │                        70.40 │                              3.74 │                                       66.66 │                   17.60 │                                 84.26 │                                          -66.66 │
    │ ACCT000572 │ LAB100036 │ Alanine Aminotransferase │     1 │         59.00 │                        47.20 │                              6.63 │                                       40.57 │                   11.80 │                                 52.37 │                                          -40.57 │
    │ ACCT000924 │ LAB100036 │ Alanine Aminotransferase │     1 │         59.00 │                        47.20 │                              6.63 │                                       40.57 │                   11.80 │                                 52.37 │                                          -40.57 │
    │ ACCT000247 │ LAB100036 │ Alanine Aminotransferase │     1 │         59.00 │                        47.20 │                              6.63 │                                       40.57 │                   11.80 │                                 52.37 │                                          -40.57 │
    │ ACCT000453 │ LAB100036 │ Alanine Aminotransferase │     1 │         59.00 │                        47.20 │                              6.63 │                                       40.57 │                   11.80 │                                 52.37 │                                          -40.57 │
    │ ACCT000144 │ LAB100036 │ Alanine Aminotransferase │     1 │         59.00 │                        47.20 │                              6.63 │                                       40.57 │                   11.80 │                                 52.37 │                                          -40.57 │
    │ ACCT000162 │ LAB100036 │ Alanine Aminotransferase │     1 │         59.00 │                        47.20 │                              6.63 │                                       40.57 │                   11.80 │                                 52.37 │                                          -40.57 │
    │ ACCT001146 │ LAB100036 │ Alanine Aminotransferase │     1 │         59.00 │                        47.20 │                              6.63 │                                       40.57 │                   11.80 │                                 52.37 │                                          -40.57 │
    │ ACCT000751 │ LAB100036 │ Alanine Aminotransferase │     1 │         59.00 │                        47.20 │                              6.63 │                                       40.57 │                   11.80 │                                 52.37 │                                          -40.57 │
    │ ACCT000374 │ LAB100036 │ Alanine Aminotransferase │     1 │         59.00 │                        47.20 │                              6.63 │                                       40.57 │                   11.80 │                                 52.37 │                                          -40.57 │
    │ ACCT000123 │ LAB100007 │ Albumin                  │     1 │         62.00 │                        49.60 │                              6.19 │                                       43.41 │                   12.40 │                                 55.81 │                                          -43.41 │
    │ ACCT000890 │ LAB100007 │ Albumin                  │     1 │         62.00 │                        49.60 │                              6.19 │                                       43.41 │                   12.40 │                                 55.81 │                                          -43.41 │
    │ ACCT000320 │ LAB100007 │ Albumin                  │     1 │         62.00 │                        49.60 │                              6.19 │                                       43.41 │                   12.40 │                                 55.81 │                                          -43.41 │
    │ ACCT000958 │ LAB100007 │ Albumin                  │     1 │         62.00 │                        49.60 │                              6.19 │                                       43.41 │                   12.40 │                                 55.81 │                                          -43.41 │
    │ ACCT000196 │ LAB100007 │ Albumin                  │     1 │         62.00 │                        49.60 │                              6.19 │                                       43.41 │                   12.40 │                                 55.81 │                                          -43.41 │
    └────────────┴───────────┴──────────────────────────┴───────┴───────────────┴──────────────────────────────┴───────────────────────────────────┴─────────────────────────────────────────────┴─────────────────────────┴───────────────────────────────────────┴─────────────────────────────────────────────────┘
      20 rows                                                                                                                                                                                                                                                                                             11 columns



## Charge Code Summary

The following query summarizes financial activity by charge code and description. It combines all patient charge records for the same laboratory test and compares the current contract allowance with the modeled allowance under the proposed fee schedule.

The allowed amount difference and contractual adjustment difference are calculated as **current minus proposed**. A positive allowed amount difference indicates that the current contract allows more than the proposed fee schedule. A positive contractual adjustment difference indicates that the proposed fee schedule would reduce the contractual write-off.


```python
duckdb.sql("""
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
   SUM((CAST(((c.qty * m.price) - ((c.qty * m.price) * .8)) AS DECIMAL(10,2)) - CAST(((c.qty * m.price) - (f.fee)) AS DECIMAL(10, 2)))) AS "Total Contractual Amt Difference (Current - Proposed)" 
FROM 'Lab Contract Review/patient_charges.csv' as c
JOIN 'Lab Contract Review/lab_charge_master.csv' as m
   ON c.chargeNum = m.chargeNum
JOIN 'Lab Contract Review/patient_encounters.csv' as v
   ON c.acctNum = v.acctNum
JOIN 'Lab Contract Review/lab_fee_schedule.csv' as f
   ON m.CPT = f.CPT
GROUP BY c.chargeNum, m.description
ORDER BY "Total Allowed Amt Difference (Current - Proposed)" DESC; 
""")
```




    ┌───────────┬─────────────────────────────────────────────┬──────────────┬───────────────┬────────────────────────────────────┬─────────────────────────────────────────┬───────────────────────────────────────────────────┬───────────────────────────────┬─────────────────────────────────────────────┬───────────────────────────────────────────────────────┐
    │ Charge #  │             Charge Description              │ Net Quantity │ Total Charges │ Total Current Contract Allowed Amt │ Total Proposed Fee Schedule Allowed Amt │ Total Allowed Amt Difference (Current - Proposed) │ Total Current Contractual Amt │ Total Proposed Fee Schedule Contractual Amt │ Total Contractual Amt Difference (Current - Proposed) │
    │  varchar  │                   varchar                   │    int128    │ decimal(38,2) │           decimal(38,2)            │              decimal(38,2)              │                   decimal(38,2)                   │         decimal(38,2)         │                decimal(38,2)                │                     decimal(38,2)                     │
    ├───────────┼─────────────────────────────────────────────┼──────────────┼───────────────┼────────────────────────────────────┼─────────────────────────────────────────┼───────────────────────────────────────────────────┼───────────────────────────────┼─────────────────────────────────────────────┼───────────────────────────────────────────────────────┤
    │ LAB100002 │ Comprehensive Metabolic Panel               │           90 │      19260.00 │                           15408.00 │                                 1188.00 │                                          14220.00 │                       3852.00 │                                    18072.00 │                                             -14114.40 │
    │ LAB100001 │ Basic Metabolic Panel                       │           89 │      14952.00 │                           11961.60 │                                  941.62 │                                          11019.98 │                       2990.40 │                                    14010.38 │                                             -10956.50 │
    │ LAB100044 │ Complete Blood Count with Differential      │          109 │      12862.00 │                           10289.60 │                                 1058.39 │                                           9231.21 │                       2572.40 │                                    11803.61 │                                              -9231.21 │
    │ LAB100004 │ Lipid Panel                                 │           47 │       8742.00 │                            6993.60 │                                  786.78 │                                           6206.82 │                       1748.40 │                                     7955.22 │                                              -6173.34 │
    │ LAB100037 │ Troponin, Quantitative                      │           43 │       8041.00 │                            6432.80 │                                  670.37 │                                           5762.43 │                       1608.20 │                                     7370.63 │                                              -5700.07 │
    │ LAB100028 │ B-Type Natriuretic Peptide                  │           24 │       7656.00 │                            6124.80 │                                 1177.92 │                                           4946.88 │                       1531.20 │                                     6478.08 │                                              -4946.88 │
    │ LAB100075 │ Respiratory Virus Panel, SARS-CoV-2/Flu/RSV │           28 │      12264.00 │                            9811.20 │                                 4992.12 │                                           4819.08 │                       2452.80 │                                     7271.88 │                                              -4819.08 │
    │ LAB100035 │ Thyroid-Stimulating Hormone                 │           52 │       6656.00 │                            5324.80 │                                 1092.00 │                                           4232.80 │                       1331.20 │                                     5564.00 │                                              -4232.80 │
    │ LAB100065 │ Blood Culture                               │           26 │       4784.00 │                            3827.20 │                                  335.40 │                                           3491.80 │                        956.80 │                                     4448.60 │                                              -3466.00 │
    │ LAB100022 │ Hemoglobin A1c                              │           47 │       4982.00 │                            3985.60 │                                  570.58 │                                           3415.02 │                        996.40 │                                     4411.42 │                                              -3390.74 │
    │     ·     │     ·                                       │            · │           ·   │                                ·   │                                     ·   │                                               ·   │                           ·   │                                         ·   │                                                  ·    │
    │     ·     │     ·                                       │            · │           ·   │                                ·   │                                     ·   │                                               ·   │                           ·   │                                         ·   │                                                  ·    │
    │     ·     │     ·                                       │            · │           ·   │                                ·   │                                     ·   │                                               ·   │                           ·   │                                         ·   │                                                  ·    │
    │ LAB100069 │ Gram Stain                                  │            5 │        405.00 │                             324.00 │                                   26.70 │                                            297.30 │                         81.00 │                                      378.30 │                                               -297.30 │
    │ LAB100011 │ Fecal Occult Blood, Guaiac                  │            6 │        402.00 │                             321.60 │                                   32.88 │                                            288.72 │                         80.40 │                                      369.12 │                                               -288.72 │
    │ LAB100033 │ Protein, Total                              │            7 │        399.00 │                             319.20 │                                   32.13 │                                            287.07 │                         79.80 │                                      366.87 │                                               -287.07 │
    │ LAB100010 │ Bilirubin, Direct                           │            7 │        406.00 │                             324.80 │                                   43.96 │                                            280.84 │                         81.20 │                                      362.04 │                                               -280.84 │
    │ LAB100024 │ Iron Binding Capacity                       │            5 │        415.00 │                             332.00 │                                   54.65 │                                            277.35 │                         83.00 │                                      360.35 │                                               -277.35 │
    │ LAB100049 │ Erythrocyte Sedimentation Rate              │            5 │        355.00 │                             284.00 │                                   16.90 │                                            267.10 │                         71.00 │                                      338.10 │                                               -267.10 │
    │ LAB100007 │ Albumin                                     │            6 │        372.00 │                             297.60 │                                   37.14 │                                            260.46 │                         74.40 │                                      334.86 │                                               -260.46 │
    │ LAB100039 │ Uric Acid                                   │            5 │        340.00 │                             272.00 │                                   28.25 │                                            243.75 │                         68.00 │                                      311.75 │                                               -243.75 │
    │ LAB100016 │ Creatinine, Blood                           │            6 │        330.00 │                             264.00 │                                   38.40 │                                            225.60 │                         66.00 │                                      291.60 │                                               -225.60 │
    │ LAB100013 │ Calcium, Total                              │            5 │        270.00 │                             216.00 │                                   32.25 │                                            183.75 │                         54.00 │                                      237.75 │                                               -183.75 │
    └───────────┴─────────────────────────────────────────────┴──────────────┴───────────────┴────────────────────────────────────┴─────────────────────────────────────────┴───────────────────────────────────────────────────┴───────────────────────────────┴─────────────────────────────────────────────┴───────────────────────────────────────────────────────┘
      81 rows (20 shown)                                                                                                                                                                                                                                                                                                                                   10 columns



## Overall Financial Summary

The following query aggregates all laboratory charges into a single financial summary. It compares total charges, current contract allowances, proposed fee schedule allowances, and the resulting contractual adjustments across the complete analysis population.

The summary provides the overall modeled financial impact of replacing the current contract terms with the proposed fee schedule. Difference columns are calculated as **current minus proposed** and reconcile to equal amounts with opposite signs because the original charge amounts remain unchanged.


```python
duckdb.sql("""
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
""")
```




    ┌───────────────┬────────────────────────────────────┬─────────────────────────────────────────┬───────────────────────────────────────────────────┬───────────────────────────────┬─────────────────────────────────────────────┬───────────────────────────────────────────────────────┬──────────────────────┐
    │ Total Charges │ Total Current Contract Allowed Amt │ Total Proposed Fee Schedule Allowed Amt │ Total Allowed Amt Difference (Current - Proposed) │ Total Current Contractual Amt │ Total Proposed Fee Schedule Contractual Amt │ Total Contractual Amt Difference (Current - Proposed) │ Reconciliation Check │
    │ decimal(38,2) │           decimal(38,2)            │              decimal(38,2)              │                   decimal(38,2)                   │         decimal(38,2)         │                decimal(38,2)                │                     decimal(38,2)                     │    decimal(38,2)     │
    ├───────────────┼────────────────────────────────────┼─────────────────────────────────────────┼───────────────────────────────────────────────────┼───────────────────────────────┼─────────────────────────────────────────────┼───────────────────────────────────────────────────────┼──────────────────────┤
    │     197617.00 │                          158093.60 │                                24454.86 │                                         133638.74 │                      39523.40 │                                   173162.14 │                                            -133638.74 │                 0.00 │
    └───────────────┴────────────────────────────────────┴─────────────────────────────────────────┴───────────────────────────────────────────────────┴───────────────────────────────┴─────────────────────────────────────────────┴───────────────────────────────────────────────────────┴──────────────────────┘



## Findings and Limitations

### Findings

- Source validation confirmed that the four datasets contained the expected record counts, unique row identifiers, required values, and valid relationships between tables.
- Cross-file validation found no unexpected unmatched foreign keys or row multiplication during the joins.
- Charge corrections were accounted for using net quantity so that reversed charges did not inflate charge volume or modeled allowances.
- Under the current contract, the analyzed laboratory charges produced a total allowed amount of **\$158,093.60**.
- Applying the proposed fee schedule to the same charge activity produced a modeled allowed amount of **\$24,454.86**.
- The proposed fee schedule resulted in an allowed amount difference of **\$133,638.74**, calculated as current allowance minus proposed allowance.
- The modeled contractual adjustment changed by **-\$133,638.74**. This amount reconciles to the allowance difference with the opposite sign because the original charge amounts remain unchanged.
- The largest modeled differences were associated with **Comprehensive Metabolic Panel, Basic Metabolic Panel and Complete Blood Count with Differential**, driven by their charge volume, fee-schedule variance, or a combination of both.
- No laboratory test had a higher modeled allowance under the proposed fee schedule than under the current contract. 

### Limitations

- The project uses synthetic data and does not contain real patient, encounter, charge, or reimbursement information.
- The datasets were generated without intentional data-quality anomalies. Therefore, this project emphasizes source validation, relational integrity, and financial modeling rather than data cleaning.
- The analysis assumes that the proposed fee schedule applies uniformly to all included outpatient laboratory charges.
- Modeled allowances do not necessarily represent actual collected revenue. The analysis does not account for claim denials, patient responsibility, coordination of benefits, collection rates, or other adjudication outcomes.
- The model does not include contractual rules such as modifiers, multiple-procedure reductions, bundled services, coverage limitations, or payer-specific exceptions unless those rules are explicitly represented in the fee schedule.
- The analysis assumes that historical charge volume and test utilization would remain unchanged under the proposed fee schedule.
- Results apply only to the outpatient laboratory services represented in the synthetic dataset and should not be generalized to other departments, patient populations, or reimbursement arrangements.
