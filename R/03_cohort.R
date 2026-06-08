# 03_cohort.R
# Purpose: Define and build the cardiac arrest analysis cohort
# Inclusion: Adult patients (>=18) with ICD-10 I46x or ICD-9 4275x
# Exclusion: Patients flagged with high-severity QC discrepancies
# ─────────────────────────────────────────────────────────────────

library(tidyverse)
library(lubridate)