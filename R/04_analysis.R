# 04_analysis.R
# Purpose: Outcome analysis on final cardiac arrest cohort
# Outputs: Summary statistics, outcome tables, risk model
# ─────────────────────────────────────────────────────────

library(tidyverse)
library(lubridate)

# Load final cohort
cohort_final <- read_csv("outputs/cohort_final.csv")

# ── BUILD FULL ICU COHORT ─────────────────────────────────────────

icu_cohort <- icustays %>%
  left_join(
    admissions %>% select(
      subject_id, hadm_id, admittime, dischtime,
      admission_type, discharge_location,
      hospital_expire_flag, race, insurance
    ),
    by = c("subject_id", "hadm_id")
  ) %>%
  left_join(
    patients %>% select(subject_id, gender, anchor_age),
    by = "subject_id"
  ) %>%
  mutate(
    hospital_los      = as.numeric(difftime(dischtime, admittime, units = "days")),
    in_hospital_death = hospital_expire_flag == 1,
    age_band = case_when(
      anchor_age < 40              ~ "Under 40",
      anchor_age >= 40 & anchor_age < 60 ~ "40-59",
      anchor_age >= 60 & anchor_age < 80 ~ "60-79",
      anchor_age >= 80             ~ "80 and over"
    )
  )

cat("Full ICU cohort size:", n_distinct(icu_cohort$subject_id), "patients\n")
cat("Total ICU stays:", nrow(icu_cohort), "\n")


# ── PART 1: CARDIAC ARREST COHORT ────────────────────────────────

cat("\n--- CARDIAC ARREST COHORT (n=1) ---\n")
cat("In-hospital death:", cohort_final$in_hospital_death, "\n")
cat("ICU length of stay (days):", round(cohort_final$los, 2), "\n")
cat("Hospital length of stay (days):", round(cohort_final$hospital_los, 2), "\n")
cat("Care unit:", cohort_final$first_careunit, "\n")
cat("Admission type:", cohort_final$admission_type, "\n")
cat("NOTE: Single-patient cohort - statistics not meaningful at this scale.\n")
cat("Pipeline designed to scale to full MIMIC-IV dataset.\n")

# ── PART 2: FULL ICU COHORT ───────────────────────────────────────

cat("\n--- FULL ICU COHORT (n=100 patients, 140 stays) ---\n")

# 1. In-hospital mortality rate
mortality_rate <- icu_cohort %>%
  distinct(subject_id, hadm_id, in_hospital_death) %>%
  distinct(subject_id, .keep_all = TRUE) %>%
  summarise(
    total_patients  = n(),
    deaths          = sum(in_hospital_death),
    survival        = sum(!in_hospital_death),
    mortality_pct   = round(mean(in_hospital_death) * 100, 1)
  )

cat("\nIn-hospital mortality:\n")
print(mortality_rate)

# 2. ICU length of stay
los_summary <- icu_cohort %>%
  summarise(
    mean_icu_los   = round(mean(los, na.rm = TRUE), 2),
    median_icu_los = round(median(los, na.rm = TRUE), 2),
    min_icu_los    = round(min(los, na.rm = TRUE), 2),
    max_icu_los    = round(max(los, na.rm = TRUE), 2)
  )

cat("\nICU length of stay (days):\n")
print(los_summary)

# 3. Breakdown by care unit
care_unit_breakdown <- icu_cohort %>%
  group_by(first_careunit) %>%
  summarise(
    n_stays       = n(),
    n_deaths      = sum(in_hospital_death),
    mortality_pct = round(mean(in_hospital_death) * 100, 1),
    mean_los      = round(mean(los, na.rm = TRUE), 2)
  ) %>%
  arrange(desc(n_stays))

cat("\nBreakdown by care unit:\n")
print(care_unit_breakdown)

# 4. Breakdown by age band
age_breakdown <- icu_cohort %>%
  distinct(subject_id, .keep_all = TRUE) %>%
  group_by(age_band) %>%
  summarise(
    n_patients    = n(),
    n_deaths      = sum(in_hospital_death),
    mortality_pct = round(mean(in_hospital_death) * 100, 1)
  ) %>%
  arrange(age_band)

cat("\nBreakdown by age band:\n")
print(age_breakdown)

# 5. Breakdown by admission type
admission_breakdown <- icu_cohort %>%
  distinct(subject_id, .keep_all = TRUE) %>%
  group_by(admission_type) %>%
  summarise(
    n_patients    = n(),
    n_deaths      = sum(in_hospital_death),
    mortality_pct = round(mean(in_hospital_death) * 100, 1)
  ) %>%
  arrange(desc(n_patients))

cat("\nBreakdown by admission type:\n")
print(admission_breakdown)


# ── 6. LOGISTIC REGRESSION: PREDICTORS OF IN-HOSPITAL MORTALITY ───

library(broom)

# Build model dataset - one row per patient
model_data <- icu_cohort %>%
  distinct(subject_id, .keep_all = TRUE) %>%
  mutate(
    death         = as.integer(in_hospital_death),
    age           = anchor_age,
    emergency     = as.integer(admission_type %in% c("EW EMER.", "DIRECT EMER.", "URGENT")),
    female        = as.integer(gender == "F")
  ) %>%
  select(death, age, emergency, female, los)

# Fit logistic regression
log_model <- glm(death ~ age + emergency + female + los,
                 data   = model_data,
                 family = binomial)

# Tidy output
model_results <- tidy(log_model, exponentiate = TRUE, conf.int = TRUE) %>%
  mutate(across(where(is.numeric), ~ round(., 3)))

cat("\nLogistic regression - predictors of in-hospital mortality:\n")
print(model_results)

# Observed vs expected
model_data <- model_data %>%
  mutate(
    predicted_prob = predict(log_model, type = "response"),
    expected_death = round(predicted_prob, 3)
  )

cat("\nObserved deaths:", sum(model_data$death), "\n")
cat("Expected deaths (sum of predicted probabilities):",
    round(sum(model_data$predicted_prob), 1), "\n")
cat("O/E ratio:", round(sum(model_data$death) /
                          sum(model_data$predicted_prob), 2), "\n")

