# MIMIC-IV Calcium-AF-CTS: Hypocalcaemia and Postoperative Atrial Fibrillation

## Overview

This repository contains R scripts and statistical analyses investigating the hypothesis that **hypocalcaemia following cardiac surgical procedures is associated with a higher incidence of postoperative atrial fibrillation (AF)**. 

The project leverages the MIMIC-IV critical care database to extract patient cohorts undergoing cardiac surgery, assess perioperative serum calcium levels, identify postoperative atrial fibrillation events, and perform adjusted statistical analyses to evaluate this association.

## Research Question

**Primary Hypothesis**: Does postoperative hypocalcaemia (low serum calcium) following cardiac surgical procedures increase the risk of developing atrial fibrillation in the immediate postoperative period?

## Project Structure

### Data Processing
- **Data extraction.R** - Main data extraction pipeline; identifies patients undergoing cardiac procedures, extracts perioperative calcium measurements, and AF outcomes from MIMIC-IV
- **Large Reads.R** - Utilities for handling large dataset reads efficiently
- **Working Data/** - Directory for intermediate working datasets

### Clinical Variable Processing
- **AF ICD codes script.R** - Extraction and ICD-9/10 coding of postoperative atrial fibrillation events
- **CCI.R** - Charlson Comorbidity Index calculation for risk adjustment
- **Procedure class.R** - Classification of cardiac surgical procedures
- **Additional Ca explanation.R** - Supplementary serum calcium variable definitions and categorization
- **bloodevents.R** - Blood event data processing
- **inopressors.R** - Inotropic support medication processing (relevant to cardiac surgery outcomes)

### Statistical Analysis & Visualization
- **Statistics and plots.R** - Main statistical analysis (logistic regression, risk adjustment, subgroup analyses) and figure generation
- **Statistics draft v1.Rmd** - Initial analysis draft (R Markdown)
- **Statistics draft v2.Rmd** - Updated analysis draft with refined methods
- **Statistics-draft-v2.tex** - LaTeX version of statistical report (for manuscript preparation)
- **Statistics-draft-v2.docx** - Word format statistical report

### Data Transformations
- **log transformation.R** - Logarithmic transformation utilities for skewed calcium distributions
- **square root transformation.R** - Square root transformation utilities
- **cube root transformation.R** - Cube root transformation utilities

### Utilities
- **functions.R** - Custom helper functions used throughout the analysis
- **MIMIC-IV_Calcium-AF-CTS.Rproj** - RStudio project configuration

## Requirements

- R (version 3.6+)
- Access to MIMIC-IV database
- Required R packages:
  - tidyverse
  - data.table (for large dataset handling)
  - ggplot2 (for visualizations)
  - rmarkdown (for rendering markdown documents)

## Study Design & Methodology

**Cohort**: Patients in MIMIC-IV who underwent cardiac surgical procedures

**Exposure**: Postoperative serum calcium level (categorized as normal vs. hypocalcaemia)

**Outcome**: Incidence of atrial fibrillation in the postoperative period

**Analysis Approach**:
- Descriptive statistics comparing patient characteristics by calcium status
- Logistic regression with adjustment for relevant covariates (Charlson Comorbidity Index, procedure type, inotropic support, etc.)
- Stratified analyses by procedure type
- Assessment of data transformations for optimal model fit

## Workflow

1. **Data Extraction** → Identify cardiac surgery patients, extract perioperative calcium and AF data
2. **Variable Processing** → Calculate clinical covariates (CCI, procedure classification)
3. **Data Transformations** → Apply appropriate transformations to normalize calcium distributions
4. **Statistical Analysis** → Perform unadjusted and adjusted analyses
5. **Visualization** → Create publication-ready figures and tables

## Key Variables

- **Serum Calcium** - Primary exposure; measured postoperatively with multiple transformation options
  - Hypocalcaemia defined as: lower than analyser reference range (1.12mmol/l) on ICU ABG analyser.
- **Postoperative Atrial Fibrillation** - Primary outcome; identified via ICD codes or clinical documentation
- **Cardiac Surgical Procedure** - Exposure moderator; classified by procedure type
- **Charlson Comorbidity Index** - Key covariate for risk adjustment
- **Inotropic Support** - Marker of perioperative hemodynamic status

## Usage

Run scripts in sequential order:
1. `Data extraction.R` - Generate study cohort and extract variables
2. Variable-specific scripts (AF ICD codes, CCI, Procedure class, etc.)
3. `Statistics and plots.R` - Perform statistical analyses and generate visualizations

Alternatively, see `.Rmd` files for complete, documented workflow with inline code and explanations.

## Expected Outputs

- Cohort characteristics table (stratified by calcium status)
- Unadjusted and adjusted odds ratios for AF association with hypocalcaemia
- Subgroup analyses by procedure type
- Publication-quality visualizations (forest plots, distribution plots, outcome curves)
- LaTeX/Word formatted statistical report

## Database & Access

This analysis uses the **MIMIC-IV** database, a large, freely-available intensive care unit database containing de-identified health records from over 40,000 hospital admissions. 

**Note**: Ensure you have proper credentials and institutional approval to access MIMIC-IV.

## References

[Add key citations on hypocalcaemia, cardiac surgery, and atrial fibrillation as appropriate]

## License

[Specify your license here, if applicable]

## Contact

For questions or contributions, please contact [your contact information].
