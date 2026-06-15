# MIMIC Hypocalcaemia and Atrial Fibrillation Project

## Project Overview

This repository contains code for data extraction, processing, and analysis examining associations between ionised hypocalcaemia in the ICU and early postoperative atrial fibrillation (AF) after cardiac surgery. The study leverages the MIMIC-IV Critical Care Database, a comprehensive de-identified dataset of health information from critical care patients. The analysis investigates whether low serum calcium (ionised calcium, iCa) levels during the first 24 hours of ICU admission are associated with the development of AF in post-cardiac surgery patients.

## Key Study Objectives

- Identify cardiac surgical patients from the MIMIC-IV database
- Extract and validate ionised calcium measurements during ICU admission
- Determine incidence of new-onset atrial fibrillation post-surgery
- Quantify the association between hypocalcaemia and AF development
- Control for confounding variables including comorbidities and surgical characteristics

## Table of Contents

1. [Project Overview](#project-overview)
2. [Data Source](#data-source)
3. [File Structure](#file-structure)
4. [Technical Details](#technical-details)
5. [Methods](#methods)
6. [Installation & Requirements](#installation--requirements)
7. [Usage](#usage)
8. [Results](#results)
9. [License](#license)

## Data Source

**Database:** MIMIC-IV v3.1 Critical Care Database
- De-identified health records from critical care settings
- Contains: patient demographics, vital signs, lab results, medications, procedures, and clinical notes
- Access: Available through PhysioNet (https://physionet.org/) with credentialing

## File Structure

```
├── Data extraction.R           # Main data extraction and preprocessing pipeline
├── CCI.R                       # Charlson Comorbidity Index calculation
├── Procedure class.R           # Cardiac procedure classification and validation
├── AF ICD codes script.R       # Atrial fibrillation ICD code mapping
├── bloodevents.R              # Blood product utilization extraction
├── inopressors.R              # Vasopressor and inotrope usage extraction
├── Large Reads.R              # Loads large MIMIC tables efficiently
├── Additional Ca explanation.R # Calcium measurement methodology and analysis
├── Appendix 1.R               # Supplementary analyses
├── functions.R                # Utility functions for data processing
├── cube root transformation.R  # Data transformation for normality
├── log transformation.R        # Alternative log transformation approach
├── square root transformation.R # Alternative sqrt transformation approach
├── Working Data/               # Output directory for intermediate datasets
└── LICENSE                     # CC0 Public Domain License
```

## Technical Details

### Data Pipeline Overview

The analysis follows a sequential pipeline:

```
MIMIC-IV Raw Data
    ↓
Patient Selection (Cardiac Surgery)
    ↓
Calcium Measurement Extraction & Validation
    ↓
Atrial Fibrillation Status Classification
    ↓
Confounder & Covariate Extraction
    ↓
Data Quality Checks & Outlier Detection
    ↓
Final Analysis-Ready Dataset
```

### Key Data Processing Steps

#### 1. **Patient Cohort Identification** (`Data extraction.R`, lines 9-80)
- Extracts ICU stays from `icustays.csv`
- Identifies cardiac surgical procedures using ICD codes via `procedures_icd.csv`
- Filters for procedures performed on admission date
- Retains first ICU admission per hospital stay for each patient
- **Output:** List of `hadm_id` (hospital admission IDs) and `stay_id` (ICU stay IDs)

#### 2. **Demographic & Clinical Data Extraction**
- **Age Calculation:** Computes age at ICU admission using `anchor_age` and `anchor_year` from `patients.csv`
- **Gender:** Binary indicator (M/F) extracted from `patients.csv`
- **Admission Type & Insurance:** Sourced from `admissions.csv`
- **Race/Ethnicity:** Extracted for stratified analysis
- **Mortality:** Hospital mortality flag and date of death (if applicable)

#### 3. **Anthropometric Data with Outlier Detection** (`Data extraction.R`, lines 135-161)
Uses the `extremevalues` R package to detect physiologically implausible measurements:
- **Height (cm):** Outliers removed using IQR-based detection (default: <100 cm or >230 cm marked as NA)
- **Weight (kg):** Tuned outlier detection (ρ = c(100, 5), FLim = c(0.4, 0.95)) to flag values <30 kg or >200 kg
- **BMI Calculation:** Computed as weight/(height)², with aggressive outlier detection (ρ = c(90, 2)) to exclude BMI <16
- **Quality Flag:** `badweight` list maintains stay_ids with implausible measures, excluded from inopressor analysis

#### 4. **Ionised Calcium Measurement Processing** (`Data extraction.R`, lines 230-291)
- **Source:** Arterial blood gas (ABG) events containing ionised calcium (iCa) values
- **Reference Range Classification:** Values flagged as abnormal if <1.12 mmol/L (low) or >1.32 mmol/L (high)
- **Temporal Filtering:** Only measurements within ICU admission window (intime ≤ charttime ≤ outtime)
- **24-Hour Window Extraction:** Separate analysis of measurements from first 24 hours post-admission
- **Summary Metrics Computed:**
  - **Initial_iCa:** First iCa measurement during ICU stay
  - **min.iCa.24:** Minimum iCa value in first 24 hours
  - **mean.iCa.24:** Trimmed mean (2% trim) iCa value in first 24 hours
  - **any_hypocalcaemia:** Binary flag if min.iCa.24 < 1.12 mmol/L
- **Data Structure:** Separate dataframes for patients who developed AF vs. those who did not

#### 5. **Atrial Fibrillation Classification** (`Data extraction.R`, lines 163-225)
Uses rhythm event data from ICU charting:
- **Exclusion Criteria:** Patients with AF as first documented rhythm excluded (pre-existing AF)
- **Skip Rhythms:** Indeterminate rhythms (e.g., ventricular pacing) ignored
- **Normal Rhythms (NormR):** Define patients as not in AF at baseline
- **AF Rhythms (AFR):** Define transition to AF status
- **Timing:** Records first occurrence of AF rhythm post-surgery
- **Output Variables:**
  - **Developed_AF:** Binary outcome (TRUE/FALSE)
  - **FirstAFtime:** Timestamp of first AF rhythm or NA if no AF
  - **timetoaf.days:** Calculated as difftime(FirstAFtime, intime, units='days')

#### 6. **Procedure Classification** (`Procedure class.R`)
Categorizes cardiac procedures using ICD-10 codes:
- **Valvular Surgery:** Valve repair/replacement procedures
- **Coronary Bypass:** CABG (coronary artery bypass grafting)
- **Atrial Exclusion:** Surgical ablation procedures
- **Maze Procedure:** Cox-maze or modified maze procedures
- **Transplant:** Cardiac transplantation
- **Other:** Additional cardiac procedures
- **Validation:** ICD code 3961 (Extracorporeal circulation) confirms true Cox-maze vs. catheter procedures

#### 7. **Charlson Comorbidity Index (CCI)** (`CCI.R`)
Comprehensive comorbidity scoring adapted from MIT MIMIC-code SQL:
```
Component Weights:
- Age Score: 0-4 points based on age groups (≤50, 51-60, 61-70, 71-80, >80)
- Individual Conditions: 1-2 points each
- Severe Conditions: 3-6 points (metastatic cancer, severe liver disease, HIV)
```
**ICD Code Mapping:** Searches both ICD-9 and ICD-10 codes in `diagnoses_icd.csv`:
- Myocardial Infarction (410, 412, I21, I22, I252)
- Congestive Heart Failure (428, 50, I50)
- Peripheral Vascular Disease (440, 441, I70, I71)
- Cerebrovascular Disease (430-438, G45, G46, I60-I69)
- Diabetes (2500-2509, E10-E14) with complication weight adjustment
- Malignancy (140-208, C00-C97) with metastatic modifier (×2)
- And 10+ additional conditions...

#### 8. **Blood Product Utilization** (`bloodevents.R`)
Extracts transfusion events during first 72 hours:
- PRBC (Packed Red Blood Cell) volumes (mLs)
- FFP (Fresh Frozen Plasma) volumes (mLs)
- Platelet volumes (mLs)
- Cryoprecipitate volumes (mLs)
- **Missing Data Handling:** NA values replaced with 0 (no transfusion)

#### 9. **Vasopressor & Inotrope Usage** (`inopressors.R`)
Tracks vasoactive medication administration:
- Maximum dose/rate during ICU stay
- Medication categories: catecholamines, non-catecholamine inotropes, vasodilators
- Filtered to exclude patients with implausible weights (via `badweight` list)

#### 10. **Calcium Supplementation** (`Data extraction.R`, lines 443-469)
- Searches `d_items.csv` for items with "Calcium" in label
- Queries `inputevents.csv` for administration of calcium gluconate and calcium chloride
- Filters to first 24 hours post-ICU admission
- **Output:** Binary flag `recievedcafirstday` indicating whether patient received calcium supplementation

### Data Quality & Validation

- **Outlier Detection:** Uses `extremevalues` package with tuned parameters for anthropometric data
- **Missing Data:** Explicitly handled via NA preservation and explicit recoding (e.g., NAs to 0 for blood products)
- **Redundant Records:** Handles patients with multiple procedures in single admission
- **False Positives:** Validates maze procedures using extracorporeal circulation codes to exclude catheter ablations
- **Time Filtering:** All measurements validated to occur within ICU admission window

### Output Dataset

**Final Dataset (`FinalData`):** Comprehensive analysis-ready dataset with:
- **Cohort Variables:** subject_id, hadm_id, stay_id, intime, outtime
- **Outcome:** Developed_AF (binary), FirstAFtime, timetoaf.days
- **Primary Exposure:** Initial_iCa, min.iCa.24, mean.iCa.24, any_hypocalcaemia
- **Demographics:** age, male (binary), race, insurance, marital_status, admission_type
- **Anthropometrics:** BMI, weight(kg), height(cm)
- **Comorbidities:** Charlson score components (15 individual conditions)
- **Surgery Details:** procedure type indicators (valvular, coronary_bypass, etc.), los (ICU length of stay)
- **Medications/Products:** vasopressor max dose, blood product volumes, calcium supplementation
- **Outcomes:** hospital_expire_flag, date of death (dod)

## Methods

### Statistical Approach

1. **Descriptive Analysis:** Baseline characteristics by AF development status
2. **Univariable Analysis:** Associations between calcium metrics and AF using Fisher's exact test (categorical) or t-tests (continuous)
3. **Multivariable Adjustment:** Logistic regression controlling for:
   - Demographics (age, sex)
   - Comorbidities (Charlson score components)
   - Surgical factors (procedure type, CPB use)
   - ICU factors (vasopressor use, transfusions)
4. **Sensitivity Analyses:** Data transformations (log, sqrt, cube root) to assess normality assumptions
5. **Stratification:** By procedure type, age group, or comorbidity burden

### Data Transformations

The repository includes alternative data transformation approaches:
- **Log Transformation:** `log transformation.R` - For right-skewed continuous variables
- **Square Root Transformation:** `square root transformation.R` - Moderate skewness
- **Cube Root Transformation:** `cube root transformation.R` - Preserves negative values

## Installation & Requirements

### System Requirements
- **R Version:** 4.0 or higher
- **Operating System:** Cross-platform (Linux, macOS, Windows)

### Required R Packages

Install via:
```bash
install.packages(c("readr", "dplyr", "extremevalues"))
```

Required libraries:
- **readr** (≥2.0): Fast CSV reading with type specification
- **dplyr** (≥1.0.7): Data manipulation and filtering
- **extremevalues** (≥2.1): Outlier detection algorithms

### MIMIC-IV Data Access
1. Complete PhysioNet credentialing course (CITI training)
2. Request access at https://physionet.org/
3. Download MIMIC-IV v3.1 files (CSV or Parquet format)
4. Update file paths in `Data extraction.R` to match your local directory structure

## Usage

### Running the Pipeline

1. **Update Data Paths:** Modify MIMIC file paths in `Data extraction.R` (lines 12-40) to match your local setup

2. **Execute Main Script:**
```r
source('Data extraction.R')
```

This will:
- Load and process all MIMIC tables
- Generate intermediate analysis datasets
- Output final analysis-ready dataset to `Working Data/FinalData.csv`

3. **Output Files Generated:**
```
Working Data/
├── FinalData.csv                    # Main analysis dataset
├── large reads.rda                  # Cached large tables
├── iCa values for AF developed.csv  # All calcium measurements for AF+ patients
├── iCa values for no AF.csv         # All calcium measurements for AF- patients
├── study operations.csv             # Procedure coding reference
└── hadm_id who started with AF.rda  # Exclusion list
```

### Running Individual Analyses

Source individual scripts after main pipeline:
```r
# Comorbidity scoring
source('CCI.R')

# Procedure classification
source('Procedure class.R')

# Blood products
source('bloodevents.R')

# Vasopressors
source('inopressors.R')
```

## Results

Results are documented in the associated manuscript: "Associations between ionised hypocalcaemia in the ICU and early postoperative atrial fibrillation after cardiac surgery: an analysis of the MIMIC-IV database"

### Expected Outputs
- Baseline cohort characteristics (n = expected number of post-cardiac surgery patients)
- Incidence of new-onset AF (%)
- Univariable associations (odds ratios, 95% CI)
- Multivariable adjusted estimates with confounder adjustment
- Sensitivity analyses and subgroup findings

## License

This project is licensed under the **Creative Commons Zero v1.0 Universal (CC0)** License, placing all code in the public domain. See the [LICENSE](LICENSE) file for details.

### Citation
If using this code or data in your research, please cite:
- The MIMIC-IV database: Johnson et al. (2023) MIMIC-IV, a publicly available ICU database
- This repository and associated manuscript (when published)

## Acknowledgments

- MIMIC-IV database creators and MIT Critical Data Lab
- Code adapted from [MIT MIMIC-Code Repository](https://github.com/MIT-LCP/mimic-code/)
- Charlson Comorbidity Index SQL adapted from MIMIC-code project

---

**Last Updated:** June 2026  
**Repository:** https://github.com/crisp-onion/MIMIC-hypocalcaemia-and-AF
