# 03_cohort.R
# Purpose: Define and build the cardiac arrest analysis cohort
# Inclusion: Adult patients (>=18) with ICD-10 I46x or ICD-9 4275x
# Exclusion: Patients flagged with high-severity QC discrepancies
# ─────────────────────────────────────────────────────────────────

library(tidyverse)
library(lubridate)


# STEP 1: Identify cardiac arrest admissions -----------------------------

# Define cardiac arrest ICD codes:

ca_icd10 <- c("I46", "I460", "I461", "I462", "I469")
ca_icd9  <- c("4275")

# Filter Diagnoses for cardiac arrest codes

ca_diagnoses <- diagnoses %>%
  filter(
    (icd_version == 10 & icd_code %in% ca_icd10) |
      (icd_version == 9 & icd_code %in% ca_icd9)) %>%
  select(subject_id, hadm_id, icd_code, icd_version)

# How many cardiac arrest admissions identified?
cat("Cardiac arrest admissions identified:", nrow(ca_diagnoses), "\n")
cat("Unique patients:", n_distinct(ca_diagnoses$subject_id), "\n")

ca_diagnoses


# STEP 2: Join demographics, admission details, ICU stay ------------------

cohort <- ca_diagnoses %>%
  left_join(
    patients %>% select(subject_id, gender, anchor_age),
    by = "subject_id"
  ) %>%
  left_join(
    admissions %>% select(subject_id, hadm_id, admittime, dischtime, deathtime,
                          admission_type, admission_location, discharge_location,
                          hospital_expire_flag, race, marital_status, insurance) ,
    by = c("subject_id", "hadm_id")
  ) %>%
  left_join(
    icustays %>% select(subject_id, hadm_id, stay_id, first_careunit,
                        intime, outtime, los),
    by = c("subject_id", "hadm_id")
  ) %>%  
  mutate(
    hospital_los = as.numeric(difftime(dischtime, admittime, units = "days")),
    in_hospital_death = hospital_expire_flag == 1
  )


# STEP 3: Apply exclusions ------------------------------------------------


# Exclusion 1: Under 18
excl_age <- cohort %>% filter(anchor_age < 18)
cat("Excluded - under 18:", nrow(excl_age), "\n")

# Exclusion 2: High severity QC discrepancies
high_severity_ids <- discrepancy_log %>%
  filter(severity == "High") %>%
  pull(subject_id) %>%
  unique()

excl_qc <- cohort %>% filter(subject_id %in% high_severity_ids)
cat("Excluded - high severity QC flag:", nrow(excl_qc), "\n")

# Apply exclusions
cohort_final <- cohort %>%
  filter(anchor_age >= 18) %>%
  filter(!subject_id %in% high_severity_ids)

cat("Final cohort size:", nrow(cohort_final), "\n")


# STEP 4: Save final cohort -----------------------------------------------

# Save as CSV for analysis and Power BI
write_csv(cohort_final, "outputs/cohort_final.csv")

cat("Cohort saved to outputs/cohort_final.csv\n")


# COHORT FLOWCHART SUMMARY:
# All MIMIC-IV Demo patients:          100
# Cardiac arrest ICD code identified:    1
# Excluded - under 18:                   0
# Excluded - high severity QC flag:      0
# ─────────────────────────────────────────
# Final analysis cohort:                 1
