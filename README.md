# In-Hospital Cardiac Arrest & ICU Outcomes Audit

A clinical audit pipeline modelled on ICNARC's National Cardiac Arrest 
Audit (NCAA) and Case Mix Programme (CMP), built using the MIMIC-IV 
Clinical Database Demo dataset.

---

## Project Overview

This project demonstrates a full clinical audit data management and analysis 
pipeline, from raw data ingestion through data quality validation, cohort 
definition, outcome analysis, and reporting. It was built as a portfolio 
project to showcase skills in clinical audit data coordination, data quality 
assurance, and reproducible analytical reporting.

The pipeline is modelled on the methodology and objectives of ICNARC's two 
national clinical audits:
- **National Cardiac Arrest Audit (NCAA)** — identification and outcome 
  analysis of in-hospital cardiac arrest cases
- **Case Mix Programme (CMP)** — benchmarking ICU outcomes across 
  participating critical care units

---

## Dataset

**MIMIC-IV Clinical Database Demo v2.2**
- Source: [PhysioNet](https://physionet.org/content/mimic-iv-demo/2.2/)
- 100 de-identified ICU patients from Beth Israel Deaconess Medical Center
- Openly available, no credentialing required
- Full MIMIC-IV dataset contains 300,000+ admissions — this pipeline is 
  designed to scale

---

## Pipeline Structure

```
icnarc-cardiac-arrest-audit/
├── R/
│   ├── 01_ingest.R        # Data loading and inspection
│   ├── 02_qc.R            # Data quality checks and discrepancy log
│   ├── 03_cohort.R        # Cohort definition and exclusions
│   ├── 04_analysis.R      # Outcome analysis and logistic regression
│   └── 05_report.R        # (reserved for report automation)
├── outputs/
│   └── discrepancy_log.csv
├── audit_report.Rmd       # R Markdown audit report
└── README.md
```

---

## Methods Summary

### Data Quality Assurance
Three categories of checks were applied across all core tables:
- **Completeness** — missingness per variable
- **Plausibility** — age, length of stay, and date range checks
- **Consistency** — cross-field validation (expire flag vs deathtime, 
  ICU stay within admission window, duplicate IDs)

51 discrepancies were identified and logged with severity ratings and 
resolution notes, replicating ICNARC's query-raising process.

### Cohort Definition
- **Cardiac arrest cohort:** ICD-10 I46x / ICD-9 4275x, adults ≥18, 
  no high-severity QC flags — n=1 in demo dataset
- **Full ICU cohort:** All ICU admissions — n=100 patients, 140 stays

### Key Findings
| Metric | Value |
|---|---|
| Overall in-hospital mortality | 13% |
| Highest mortality care unit | CCU (38.5%) |
| Mean ICU length of stay | 3.68 days |
| Significant predictor of mortality | ICU LOS (OR 1.30, p=0.002) |
| Total discrepancies logged | 51 (9 High, 42 Medium) |

---

## Audit Report

The full rendered audit report is available here:
[View Audit Report](audit_report.html)

---

## Reproducibility

This pipeline was built with reproducibility as a core principle:
- All code is version-controlled on GitHub
- Package environment locked with `renv`
- All analytical steps documented with inline comments
- Discrepancy log exported as a structured CSV

To reproduce:
```r
# Install renv if needed
install.packages("renv")

# Restore package environment
renv::restore()

# Run scripts in order
source("R/01_ingest.R")
source("R/02_qc.R")
source("R/03_cohort.R")
source("R/04_analysis.R")

# Knit report
rmarkdown::render("audit_report.Rmd")
```

---

## Author

**Hussein Kassir**  
MSc Genomic Medicine , Queen Mary University of London  
BSc Pharmacy, Lebanese International University  
[GitHub](https://github.com/h-kassir) | h.kassir99@gmail.com