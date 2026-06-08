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

# Age: Should be reasonable

plausibility_age <- patients %>%
  filter(anchor_age < 18 | anchor_age > 120) %>%
  mutate(flag = "Implausible age") %>%
  select(subject_id, anchor_age, flag)

plausibility_age

# Length of stay in ICU: Should be positive

plausibility_los <- icustays %>%
  filter(los < 0) %>%
  mutate(flag = "Negative ICU length of stay") %>%
  select(subject_id, hadm_id, stay_id, los,flag)

plausibility_los

# Death time: If deathtime is present, it should be within admission period

plausibility_death <- admissions %>%
  filter(!is.na(deathtime)) %>%
  filter(deathtime < admittime | deathtime > dischtime) %>%
  mutate(flag = "Death time outside admission window") %>%
  select(subject_id, hadm_id, admittime, dischtime, deathtime, flag)

plausibility_death


# Inspect the flagged records more closely

admissions %>%
  filter(!is.na(deathtime)) %>%
  filter(deathtime < admittime | deathtime > dischtime) %>%
  select(subject_id, hadm_id, admittime, dischtime, deathtime) %>%
  mutate(
    death_before_admission = deathtime < admittime,
    death_after_discharge  = deathtime > dischtime
  ) %>%
  print(width = Inf)
  

# INTERPRETATION:
# All 4 flagged records show deathtime after dischtime by a few hours
# dischtime is recorded as 00:00:00 (midnight start of day)
# deathtime is recorded as evening of the same date (22:00-23:00)
# This is a known MIMIC data convention, not a genuine error
# Resolution: exclude from discrepancy log, document as known artefact



# CONSISTENCY CHECKS: -----------------------------------------------------

# Check 1: hospital_expire_flag vs deathtime
# If expire flag = 1, deathtime should be present and vice versa
consistency_death <- admissions %>%
  mutate(
    flag_without_time = hospital_expire_flag == 1 & is.na(deathtime),
    time_without_flag = hospital_expire_flag == 0 & !is.na(deathtime)
  ) %>%
  filter(flag_without_time | time_without_flag) %>%
  select(subject_id, hadm_id, hospital_expire_flag, deathtime,
         flag_without_time, time_without_flag) %>%
  print(width = Inf)


# Check 2: ICU stay should fall within hospital admission window

consistency_icu_window <- icustays %>%
  left_join(admissions %>% select(hadm_id, admittime, dischtime),
            by = "hadm_id") %>%
  filter(intime < admittime | outtime > dischtime) %>%
  mutate(flag = "ICU stay outside hospital admission window") %>%
  select(subject_id, hadm_id, stay_id, admittime, dischtime,
         intime, outtime, flag)%>%
  print(width = Inf)

consistency_icu_window %>%
  mutate(
    gap_hours_intime  = as.numeric(difftime(admittime, intime,   units = "hours")),
    gap_hours_outtime = as.numeric(difftime(outtime,   dischtime, units = "hours"))
  ) %>%
  select(subject_id, hadm_id, gap_hours_intime, gap_hours_outtime) %>%
  print(n = 24, width = Inf)


# Check 3: duplicate admission IDs
consistency_dupes <- admissions %>%
  group_by(hadm_id) %>%
  filter(n() > 1) %>%
  mutate(flag = "Duplicate admission ID") %>%
  select(subject_id, hadm_id, flag) %>%
  print(width = Inf)

# INTERPRETATION - ICU window consistency:
# Category 1: Small gaps (<6hrs) - MIMIC timestamp convention, not genuine errors
# Category 2: Large negative intime (rows 3,4,7,12) - ICU admission recorded
#             days before hospital admission - FLAGGED as genuine discrepancy
# Category 3: Large outtime gaps (rows 17,18) - ICU discharge recorded
#             days before hospital discharge - FLAGGED as genuine discrepancy



# ── 4. DISCREPANCY LOG ────────────────────────────────────────────

# Category 2: ICU admission days before hospital admission
discrepancy_icu_intime <- consistency_icu_window %>%
  mutate(
    gap_hours_intime = as.numeric(difftime(admittime, intime, units = "hours"))
  ) %>%
  filter(gap_hours_intime < -6) %>%
  select(subject_id, hadm_id, stay_id, admittime, intime, gap_hours_intime) %>%
  mutate(
    check_type  = "Consistency",
    variable    = "intime vs admittime",
    flag        = "ICU admission recorded before hospital admission",
    severity    = "High",
    resolution  = "Under investigation — likely MIMIC date-shift artefact; exclude from primary analysis"
  )

# Category 3: ICU discharge days before hospital discharge
discrepancy_icu_outtime <- consistency_icu_window %>%
  mutate(
    gap_hours_outtime = as.numeric(difftime(outtime, dischtime, units = "hours"))
  ) %>%
  filter(gap_hours_outtime < -6) %>%
  select(subject_id, hadm_id, stay_id, dischtime, outtime, gap_hours_outtime) %>%
  mutate(
    check_type  = "Consistency",
    variable    = "outtime vs dischtime",
    flag        = "ICU discharge recorded before hospital discharge by >6 hours",
    severity    = "High",
    resolution  = "Under investigation — likely MIMIC date-shift artefact; exclude from primary analysis"
  )

# Category 4: discharge_location missing
discrepancy_missing_discharge <- admissions %>%
  filter(is.na(discharge_location)) %>%
  select(subject_id, hadm_id) %>%
  mutate(
    check_type  = "Completeness",
    variable    = "discharge_location",
    flag        = "Discharge location not recorded",
    severity    = "Medium",
    resolution  = "Missing — would be queried back to submitting unit in a live audit"
  )

# Combine into single discrepancy log
discrepancy_log <- bind_rows(
  discrepancy_icu_intime,
  discrepancy_icu_outtime,
  discrepancy_missing_discharge
) %>%
  mutate(record_id = row_number()) %>%
  select(record_id, subject_id, hadm_id, check_type, variable, flag, severity, resolution) %>%
  print(n = 60, width = Inf)



# Save Outputs: -----------------------------------------------------------

write_csv(discrepancy_log, "outputs/discrepancy_log.csv")
