# Data Dictionary

## patient_encounters

| Table | Column | Data type | Required | Description | Example |
|---|---|---|---:|---|---|
| lab_charge_master | chargeNum | Varchar | Yes | Unique charge code identifier | LAB100001 |
| lab_charge_master | description | Varchar | Yes | Description of the charge | Basic Metabolic Panel |
| lab_charge_master | revCode | Varchar | Yes | UB-04 revenue code | 301 |
| lab_charge_master | CPT | Varchar | Yes | AMA CPT or HCPCS code | 80048 |
| lab_charge_master | price | Double | Yes | Price of the charge | 168.00 |
| patient_charges | rowNum | Integer | Yes | Primary Key | 1 |
| patient_charges | acctNum | Varchar | Yes | Number to identify a single date of service | ACCT000001 |
| patient_charges | chargeNum | Varchar | Yes | Foreign key from lab_charge_master table | LAB100081 |
| patient_charges | svcDate | Date | Yes | Date service was rendered | 01/01/24 |
| patient_charges | qty | Integer | Yes | Number of tests charged; can be negative | 1 |
| patient_encounters | acctNum | Varchar | Yes | Primary key unique to date of service | ACCT000001 |
| patient_encounters | admitDate | Date | Yes | Date of patient's admission | 01/01/24 |
| lab_fee_schedule | CPT | Varchar | Yes | AMA CPT or HCPCS code | 80048 |
| lab_fee_schedule | description | Varchar | Yes | Description of the charge | Basic Metabolic Panel |
| lab_fee_schedule | fee | Double | Yes | Allowed amount for test | 10.58 |
