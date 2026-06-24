# MIMIC Hypocalcaemia and Atrial Fibrillation Project

## Project Overview

This repository contains code for data extraction, processing, and analysis examining associations between ionised hypocalcaemia in the ICU and early postoperative atrial fibrillation (AF) after cardiac surgery. The scripts extract and clean MIMIC-IV data, construct an analysis-ready dataset, perform descriptive and multivariable statistical modelling, and produce summary tables and figures used in the manuscript.

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
6. [Statistics & Figures (Statistics and plots.R)](#statistics--figures-statistics-and-plotsr)
7. [Installation & Requirements](#installation--requirements)
8. [Usage](#usage)
9. [Results](#results)
10. [License](#license)

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
├── Statistics and plots.R     # Descriptive tables, regression models, and plots
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

(omitted other technical sections for brevity in this README snippet)

## Methods

### Statistical Approach

1. **Descriptive Analysis:** Baseline characteristics by AF development status
2. **Univariable Analysis:** Associations between calcium metrics and AF using Fisher's exact test (categorical) or t-tests (continuous)
3. **Multivariable Adjustment:** Logistic regression controlling for demographics, comorbidities, surgical factors, and ICU factors
4. **Sensitivity Analyses:** Data transformations (log, sqrt, cube root) to assess normality assumptions
5. **Stratification:** By procedure type, age group, or comorbidity burden

## Statistics & Figures (Statistics and plots.R)

Purpose:
- Produces descriptive cohort tables, fits univariable and multivariable logistic regression models investigating the relationship between ionized calcium (iCa) metrics and postoperative AF (POAF), and creates the main figures used in the manuscript.

Key behaviours of the script:
- Loads the analysis-ready dataset `Working Data/FinalData.csv` and calcium measurement files:
  - `Working Data/iCa values for AF developed.csv`
  - `Working Data/iCa values for no AF.csv`
- Excludes patients with Cox–Maze or similar ablation procedures (filtered via `maze` flag).
- Generates Table 1 (cohort characteristics) and Table 2 (interventions and outcomes) using gtsummary.
- Builds several logistic regression models:
  - glm_model_init: outcome Developed_AF with Initial_iCa
  - glm_model_supp / glm_model_supp_b: models using min.iCa.24 or any_hypocalcaemia respectively
  - glm_model_stepped / glm_model_stepped2: stepwise-reduced models (backward selection)
  - glm_model_death: model for in-hospital mortality
  - glm_model_rc: alternative (retrospective cohort-style) model with any_hypocalcaemia as outcome
- Produces the following principal figures (printed to the active R plotting device):
  - Figure 1: Distribution (area histogram) of iCa values in the first 24 hours
  - Figure 2: Predicted POAF risk vs first-day nadir iCa (multivariable model predictions with 95% CI)
  - Figure 3: Mean iCa trend across the first 7 days in ICU by cohort (LOESS with 95% CI)
  - Additional boxplots, violin plots, length-of-stay histogram, and supplementation effect plot

Dependencies (R packages used by the script):
- ggplot2
- ggeffects
- mgcv
- gtsummary
- readr
- dplyr
- scales (used within plotting; ensure installed)

Inputs (must be generated by running the main data pipeline first):
- Working Data/FinalData.csv
- Working Data/iCa values for AF developed.csv
- Working Data/iCa values for no AF.csv

How to run:
1. Ensure you have run `Data extraction.R` to produce the Working Data files.
2. From an R session with required packages installed, run:

```r
source('Statistics and plots.R')
```

Notes & reproducibility considerations:
- The script prints tables and plots to the R console/plotting device; it does not automatically save figures to disk. To persist figures, wrap individual plot objects with ggsave() or modify the script to save outputs to `figures/`.
- Several continuous variables are rescaled inside the script (e.g., iCa metrics are centered on 1 mmol/L and multiplied to give interpretable odds ratios; blood volumes are converted to per-100 mL units). See the script comments for details on scaling and interpretation of model coefficients.
- There is a commented option to exclude patients who developed AF within the first 24 hours or with ICU stays <24 hours; this is intentionally not applied in the default run to preserve the planned analysis population.
- The stepwise selection uses base R's step() with backward direction on a complete-case model — results depend on missingness handling and should be interpreted accordingly.

## Installation & Requirements

### System Requirements
- **R Version:** 4.0 or higher
- **Operating System:** Cross-platform (Linux, macOS, Windows)

### Required R Packages

Install via:
```bash
install.packages(c("readr", "dplyr", "ggplot2", "ggeffects", "mgcv", "gtsummary", "scales"))
```

## Usage

### Running the Pipeline

1. **Update Data Paths:** Modify MIMIC file paths in `Data extraction.R` (lines 12-40) to match your local setup

2. **Execute Main Script:**
```r
source('Data extraction.R')
```
This will generate the analysis-ready `Working Data/FinalData.csv` and supporting iCa files.

3. **Run Statistics and Plots:**
```r
source('Statistics and plots.R')
```
This will print Tables and Figures to your R session.

## Results

Results are documented in the associated manuscript: "Associations between ionised hypocalcaemia in the ICU and early postoperative atrial fibrillation after cardiac surgery: an analysis of the MIMIC-IV database".

### Expected Outputs
- Baseline cohort characteristics (Table 1)
- Cohort interventions and outcomes (Table 2)
- Multivariable logistic regression (Table 3 and appendices)
- Figures showing iCa distributions and predicted POAF risk

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
