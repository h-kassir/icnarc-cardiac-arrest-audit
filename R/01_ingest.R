# # 01_ingest.R
# Purpose Load and Inspect raw MIMIC-IV Demo table --------

# Load the readr Library
library(readr)


# # Load the data ---------------------------------------------------------

patients <- read_csv("data/raw/mimic-iv-clinical-database-demo-2.2/hosp/patients.csv.gz")

admissions <- read_csv("data/raw/mimic-iv-clinical-database-demo-2.2/hosp/admissions.csv.gz")

diagnoses <- read_csv("data/raw/mimic-iv-clinical-database-demo-2.2/hosp/diagnoses_icd.csv.gz")

icustays <- read_csv("data/raw/mimic-iv-clinical-database-demo-2.2/icu/icustays.csv.gz")


# Inspect: Patients -------------------------------------------------------

dim(patients)
head(patients)
str(patients)
summary(patients)


# Inspect: admissions -----------------------------------------------------

dim(admissions)
head(admissions)
str(admissions)
summary(admissions)


# Inspect: diagnoses ------------------------------------------------------

dim(diagnoses)
head(diagnoses)
str(diagnoses)
summary(diagnoses)

#Hpw many unique ICD versions are there?

table(diagnoses$icd_version)

# Any Cardiac Arrest codes (I46 /ICD10) OR (4275 /ICD9)

diagnoses[startsWith(diagnoses$icd_code, "I46") & diagnoses$icd_version == 10,]

diagnoses[startsWith(diagnoses$icd_code, "4275") & diagnoses$icd_version == 9,]

# Inspect: icu stays ------------------------------------------------------

dim(icustays)
head(icustays)
str(icustays)
summary(icustays)


# Tracing the cardiac arrest patient ( subject_id = 10010471) -------------

patients[patients$subject_id ==10010471,]
admissions[admissions$hadm_id == 29842315,]
icustays[icustays$hadm_id == 29842315,]


# Cardiac arrest patient death location -----------------------------------

expire_flage <- admissions$hospital_expire_flag[admissions$hadm_id == 29842315]

if (expire_flage == 1) {
  message("Patient 10010471 died in hospital")
} else {
  message("Patient 10010471 survived to hospital discharge")
}

