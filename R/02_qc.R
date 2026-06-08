# 02_qc.R
# Purpose: Data quality checks and discrepancy log
# Checks: completeness, plausibility, consistency
# Scope: all 100 demo patients + cardiac arrest cohort
# ─────────────────────────────────────────────────


# Load the Required Libraries ---------------------------------------------

library(tidyverse)
library(lubridate)


# 1- Completeness Checks ------------------------------------------------------

# Check for missing patient data

# Function to summarise missingness in a table

check_missing <- function(df, table_name) {
  df %>%
    summarise(across(everything(), ~sum(is.na(.)))) %>%
    pivot_longer(everything(), names_to = "variable", values_to = "n_missing") %>%
    mutate (
      table = table_name,
      pct_missing = round(n_missing/nrow(df)*100, 1)
    ) %>%
    filter(n_missing >0) %>%
    arrange(desc(n_missing))
}

missing_patients <- check_missing(patients, "patients")
missing_admissions <- check_missing(admissions, "admissions")
missing_icustays <- check_missing(icustays, "icustays")
missing_diagnoses <- check_missing(diagnoses, "diagnoses")


# Print results:

missing_patients
missing_admissions
missing_icustays
missing_diagnoses


# INTERPRETATION:
# dod (69%) and deathtime (94.5%): expected - only populated for deaths
# edregtime/edouttime (33.8%): expected - not all patients admitted via ED
# discharge_location (15.3%): FLAGGED - unknown discharge destination
# marital_status (4.4%): minor gap, low audit relevance


# 2- PLAUSIBILITY CHECKS: ----------------------------------------------------


