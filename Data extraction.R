#Libraries ----
require(readr)
require(dplyr)
require(extremevalues)

#Functions ----
source('functions.R')

#Establish list of cardiac surgical patient ----

#Read in icustays
ICU_STAYS <- read_csv(
  "mimiciv/3.1/icu/icustays.csv.gz",
  show_col_types = F,
  col_names = T,
  trim_ws = T,
  cols(
    subject_id = "i",
    hadm_id = "i",
    stay_id = "i",
    los = "d",
    first_careunit = "f",
    last_careunit = "f",
    intime = "T",
    outtime = "T"
  )
)

Hosp_proc <- read_csv(
  file = "mimiciv/3.1/hosp/procedures_icd.csv.gz",
  show_col_types = F,
  col_names = T,
  trim_ws = T,
  cols(
    hadm_id = "i",
    seq_num = "i",
    icd_code = "c",
    icd_version = "d"
  )
)

source('Procedure class.R', echo = F)

Hosp_proc <- Hosp_proc |> filter(icd_code %in% proc$icd_code)

#identify patients who had relevant surgeries
CTS.patients <- inner_join (
  Hosp_proc,
  ICU_STAYS,
  by = c('subject_id', 'hadm_id'),
  relationship = 'many-to-many'
)

#remove surgeries that did not occur on day of admission
CTS.patients <- CTS.patients[as.Date (CTS.patients$intime) == CTS.patients$chartdate, ]
Hosp_proc <- CTS.patients |>
  dplyr::select(subject_id, hadm_id, seq_num, icd_version, icd_code)

#keep record of all procedures included in study and how categorized for
#error-checking
procedurelist <- left_join(Hosp_proc, proc, by = c('icd_version', 'icd_code')) |>
  select(icd_version,
         icd_code,
         long_title,
         bypass,
         valve,
         exclusion,
         other,
         transplant,
         maze) |> distinct()

write_excel_csv(procedurelist, 'Working Data/study operations.csv')

#Censor for the first ICU admission for each hospital stay
#This drops all but one procedure performed where some patients had multiple,
#this issue is resolved near end of script (line 401)
CTS.patients <- CTS.patients |> group_by(hadm_id) |>
  filter(row_number(intime) == 1) |> ungroup()

rm(ICU_STAYS, proc, procedurelist)

#Add age and gender ----
AG <- read_csv(
  'mimiciv/3.1/hosp/patients.csv.gz',
  col_names = T,
  cols_only (
    subject_id = 'i',
    gender = 'f',
    anchor_age = 'd',
    anchor_year = '?',
    dod = 'D'
  )
) |>
  subset(subject_id %in% CTS.patients$subject_id) |>
  dplyr::mutate(male = as.logical(gender == 'M'))

AG <-  left_join(CTS.patients, AG, by = 'subject_id', relationship = 'many-to-one') |>
  select (hadm_id, male, anchor_age, anchor_year, dod, intime) |>
  dplyr::mutate (
    intime = as.POSIXlt(intime),
    inyear = intime$year + 1900,
    age = inyear - anchor_year + anchor_age
  ) |>
  select(hadm_id, male, age, dod)

CTS.patients <- left_join(CTS.patients, AG, by = 'hadm_id')
rm(AG)

#Import race, admission type ----
Admissions <- read_csv(
  'mimiciv/3.1/hosp/admissions.csv.gz',
  col_names = T,
  cols_only(
    hadm_id = 'i',
    admission_type = 'c',
    insurance = 'c',
    marital_status = 'c',
    race = 'c',
    hospital_expire_flag = 'l'
  )
)

CTS.patients <- left_join(CTS.patients, Admissions, by = 'hadm_id')

rm (Admissions)

#Load: Lab events (ABG calcium), rhythm events, weight, height , input events (calcium) ----
if (file.exists('Working Data/large reads.rda')) {
  load('Working Data/large reads.rda')
  
} else {
  source('Large Reads.R', echo = F)
}

#Add weight, height, BMI ----
CTS.patients <- CTS.patients |> left_join(weight, by = 'stay_id') |>
  left_join (height, by = 'stay_id')
heightout <- getOutliers(CTS.patients$`height(cm)`)
CTS.patients$`height(cm)`[CTS.patients$`height(cm)` <= heightout$limit[[1]] |
                            CTS.patients$`height(cm)` >= heightout$limit[[2]]] <- NA
weightout <- getOutliers(CTS.patients$`weight(kg)`,
                         rho = c(100, 5),
                         FLim = c(0.4, 0.95))
CTS.patients$`weight(kg)`[CTS.patients$`weight(kg)` <= weightout$limit[[1]] |
                            CTS.patients$`weight(kg)` >= weightout$limit[[2]]] <- NA

#Calculate BMI and remove outliers. Tolerate NA.
CTS.patients <- CTS.patients |> dplyr::mutate(BMI = `weight(kg)` / ((`height(cm)` / 100)^2))
bmiout <- getOutliers(CTS.patients$BMI, rho = c(90, 2)) #tuned to exclude bmi < 16
CTS.patients$BMI[CTS.patients$BMI <= bmiout$limit[[1]] |
                   CTS.patients$BMI >= bmiout$limit[[2]]] <- NA

#badweight is a list of stay_id of implausible weights and BMIs
#used to exclude them from inopressor analysis

badweight <- CTS.patients[c(weightout$iLeft,
                            weightout$iRight,
                            bmiout$iLeft,
                            bmiout$iRight) , 'stay_id']

rm(weight, height, weightout, heightout, bmiout)

#Isolate subjects who did NOT start with AF ----
#Discard is a list of ICU stay_id that had AF as their first relevant rhythm
#studysubjects is a list of ICU stay_id who will be included in results
#SkipR is a list of rhythms that do not differentiate between AF and non-AF (such as ventricular pacing)
#NomrR is a list of rhythms that define a patient as not being in AF
#These lists were produced manually
load ('working data/NormR.rda')
load ('working data/SkipR.rda')

studysubjects <- list()
Discard <- list()

l <- length(splitrhythms)

for (i in 1:l) {
  x <- nrow(splitrhythms[[i]])
  for (j in 1:x) {
    if (!(splitrhythms[[i]][j, 4] %in% SkipR)) {
      if (splitrhythms[[i]][j, 4] %in% NormR) {
        y <- length(studysubjects)
        studysubjects[y + 1] <- as.integer(splitrhythms[[i]][j, 1])
      } else {
        z <- length(Discard)
        Discard[z + 1] <- as.integer(splitrhythms[[i]][j, 1])
      }
      break
    }
  }
}
save(Discard, file = 'Working Data/hadm_id who started with AF.rda')

rm(i, j, x, y, z, NormR, SkipR, Discard)

#identify patients who subsequently developed AF ----
#This nested loop creates a dataframe called DevelopedAF containing all stay_id
#of patients who developed AF and time of AF. Setdiff is then used to take the
#opposite for a list of stay_id who did not develop AF in ICU
load('working data/AFR.rda')
DevelopedAF <- tribble ( ~ stay_id, ~ charttime, ~ itemid, ~ value)
for (i in 1:l) {
  if (splitrhythms[[i]][1, 1] %in% studysubjects) {
    x <- nrow (splitrhythms[[i]])
    for (j in 1:x) {
      if (splitrhythms[[i]][j, 4] %in% AFR) {
        DevelopedAF <- rbind.data.frame (DevelopedAF, splitrhythms[[i]][j, 1:2])
        break
      }
    }
  }
}

colnames(DevelopedAF)[colnames(DevelopedAF) == 'charttime'] <- 'FirstAFtime'
a <- setdiff (studysubjects, DevelopedAF$stay_id)
no.AF <- do.call(rbind.data.frame, a)
colnames(no.AF)[1] <- 'stay_id'

rm (studysubjects, AFR, i, j, l, x, a, splitrhythms)

#Add logical for yes/no AF and additional empty column to no.AF for joining
DevelopedAF[, 'Developed_AF'] <- T
no.AF[, 'Developed_AF'] <- F
no.AF[, 'FirstAFtime'] <- NA

#Add procedure name, admission times, LOS, admission unit ----
DevelopedAF <- inner_join(DevelopedAF, CTS.patients, by = 'stay_id')
no.AF <- inner_join(no.AF, CTS.patients, by = 'stay_id')

#Calcium level processing ----
#Add all ABG iCa levels and flag abnormal results
calcium_developed_af <- inner_join(Ci, DevelopedAF, by = 'hadm_id', relationship = 'many-to-one') |>
  arrange(hadm_id, charttime) |>
  dplyr::mutate(Low = (value < ref_range_lower),
                High = (value > ref_range_upper))
calcium_no_af <- inner_join(Ci, no.AF, by = 'hadm_id', relationship = 'many-to-one') |>
  arrange(hadm_id, charttime) |>
  dplyr::mutate(Low = (value < ref_range_lower),
                High = (value > ref_range_upper))

rm(Ci, CTS.patients)

#These next two blocks exclude results not during ICU admission and make a
#separate data frame for results in the first 24 hours

calcium_developed_af <- select (calcium_developed_af,
                                hadm_id,
                                value,
                                Low,
                                High,
                                charttime,
                                intime,
                                outtime)
calcium_developed_af <- filter (calcium_developed_af, charttime >= intime, charttime <= outtime)
calcium_developed_af.24 <- filter (calcium_developed_af,
                                   charttime <= intime + as.difftime(1, units = 'days'))
calcium_developed_af.24 <- split.data.frame (calcium_developed_af.24, calcium_developed_af.24$hadm_id)

calcium_no_af <- select (calcium_no_af,
                         hadm_id,
                         value,
                         Low,
                         High,
                         charttime,
                         intime,
                         outtime)
calcium_no_af <- filter (calcium_no_af, charttime >= intime, charttime <= outtime)
calcium_no_af.24 <- filter (calcium_no_af,
                            charttime <= intime + as.difftime(1, units = 'days'))
calcium_no_af.24 <- split.data.frame (calcium_no_af.24, calcium_no_af.24$hadm_id)

#Save all iCa values within ICU for graphical plotting & descriptive analysis
write_csv(calcium_developed_af,
          'Working Data/iCa values for AF developed.csv')
write_csv(calcium_no_af, 'Working Data/iCa values for no AF.csv')


#First iCa in ICU
calcium_first_developed_af <- calcium_developed_af |> group_by(hadm_id) |>
  filter(row_number(charttime) == 1) |>
  ungroup() |>
  select(hadm_id, value, Low) |>
  rename_at('value', ~ 'Initial_iCa') |>
  rename_at('Low', ~ 'Initial_iCa_low')

calcium_first_no_af <- calcium_no_af |> group_by(hadm_id) |>
  filter(row_number(charttime) == 1) |>
  ungroup() |>
  select(hadm_id, value, Low) |>
  rename_at('value', ~ 'Initial_iCa') |>
  rename_at('Low', ~ 'Initial_iCa_low')


#Find min and mean iCA from first 24 hours for both group

calcium_developed_af.24.min <- data.frame (sapply (calcium_developed_af.24, function (l)
  min(l$value, na.rm = T)))

calcium_developed_af.24.min <- dplyr::mutate(calcium_developed_af.24.min,
                                             hadm_id = as.integer(row.names.data.frame(calcium_developed_af.24.min)))
colnames(calcium_developed_af.24.min) <- c('min.iCa.24', 'hadm_id')

calcium_developed_af.24.mean <- data.frame (sapply (calcium_developed_af.24, function (l)
  mean(l$value, trim = 0.02, na.rm = T)))
calcium_developed_af.24.mean <- dplyr::mutate(calcium_developed_af.24.mean,
                                              hadm_id = as.integer(row.names.data.frame(calcium_developed_af.24.mean)))
colnames(calcium_developed_af.24.mean) <- c('mean.iCa.24', 'hadm_id')


calcium_no_af.24.min <- data.frame (sapply (calcium_no_af.24, function (l)
  min(l$value, na.rm = T)))
calcium_no_af.24.min <- dplyr::mutate(calcium_no_af.24.min, hadm_id = as.integer(row.names.data.frame(calcium_no_af.24.min)))
colnames(calcium_no_af.24.min) <- c('min.iCa.24', 'hadm_id')

calcium_no_af.24.mean <- data.frame (sapply (calcium_no_af.24, function (l)
  mean(
    l$value, trim = 0.02, na.rm = T
  )))

calcium_no_af.24.mean <- dplyr::mutate(calcium_no_af.24.mean, hadm_id = as.integer(row.names.data.frame(calcium_no_af.24.mean)))
colnames(calcium_no_af.24.mean) <- c('mean.iCa.24', 'hadm_id')


#Add initial, min and mean to respective target dataframes
DevelopedAF <- inner_join(DevelopedAF, calcium_developed_af.24.min, by = 'hadm_id')
DevelopedAF <- left_join(DevelopedAF, calcium_developed_af.24.mean, by = 'hadm_id')
DevelopedAF <- inner_join(DevelopedAF, calcium_first_developed_af, by = 'hadm_id')
no.AF <- inner_join(no.AF, calcium_no_af.24.min, by = 'hadm_id')
no.AF <- left_join(no.AF, calcium_no_af.24.mean, by = 'hadm_id')
no.AF <- inner_join(no.AF, calcium_first_no_af, by = 'hadm_id')

source('Procedure class.R')

#Recombine dataframes for cohorts ----
FinalData <- rbind.data.frame(DevelopedAF, no.AF) |>
  select(
    subject_id,
    hadm_id,
    stay_id,
    intime,
    outtime,
    Developed_AF,
    los,
    male,
    age,
    BMI,
    race,
    Initial_iCa,
    Initial_iCa_low,
    min.iCa.24,
    mean.iCa.24,
    insurance,
    marital_status,
    admission_type,
    FirstAFtime,
    hospital_expire_flag,
    dod
  ) |>
  mutate(any_hypocalcaemia = min.iCa.24 < 1.12) |>
  #Time to AF in days
  dplyr::mutate(timetoaf.days = difftime(FirstAFtime, intime, units = 'days'))

rm(
  calcium_no_af.24.mean,
  calcium_no_af.24.min,
  calcium_developed_af.24.mean,
  calcium_developed_af.24.min,
  calcium_developed_af,
  calcium_first_developed_af,
  calcium_first_no_af,
  calcium_no_af,
  DevelopedAF,
  no.AF
)

#Add columns to FinalData for procedure classes to be stored
newcols <- c('valvular',
             'coronary_bypass',
             'atrial_exclusion',
             'maze',
             'transplant',
             'other')
FinalData[, newcols] <- NA
rm(newcols)

#Add surgical categories
#I thought this should work without the 'for' loop, but it doesn't
l <- nrow(FinalData)
for (i in 1:l) {
  FinalData[i, ] <- FinalData[i, ] |>
    dplyr::mutate(
      valvular = surgcheck(hadm_id, surg = 'valvular'),
      coronary_bypass = surgcheck(hadm_id, surg = 'coronary_bypass'),
      atrial_exclusion = surgcheck(hadm_id, surg = 'atrial_exclusion'),
      maze = surgcheck(hadm_id, surg = 'maze'),
      transplant = surgcheck(hadm_id, surg = 'transplant'),
      other = surgcheck(hadm_id, surg = 'other')
    )
}

#Cleanup of errors ----

#Remove patients with atrial exclusion only as they were cath-lab patients
FinalData <- FinalData |>
  dplyr::filter(when_any(valvular, coronary_bypass, maze, transplant, other))

#The false_mazes vector disentangles several patients with Cox-maze surgery from
#catheter procedures based on ICD code for Cardiopulmonary bypass.
procedures_icd <- csvpull('procedures_icd')
mazes <- FinalData %>%
  filter(when_all(
    maze,
    !valvular,
    !coronary_bypass,
    !atrial_exclusion,
    !transplant,
    !other
  )) %>%
  select(hadm_id)

d_icd_procedures <- csvpull('d_icd_pro')

true_mazes <- dplyr::left_join(mazes, procedures_icd, by = 'hadm_id') %>%
  dplyr::filter(icd_code == 3961) #"Extracorporeal circulation auxiliary to open heart surgery"
false_mazes <- dplyr::anti_join(mazes, true_mazes, by = 'hadm_id')

FinalData <- dplyr::anti_join(FinalData, false_mazes, by = 'hadm_id')

#Blood product usage ----

source('bloodevents.R')
FinalData <- dplyr::left_join(FinalData, Bloodvols, by = 'hadm_id')

FinalData[is.na(FinalData$`PRBC_72`), 'PRBC_72'] <- 0
FinalData[is.na(FinalData$`FFP_72`), 'FFP_72'] <- 0
FinalData[is.na(FinalData$`Plt_72`), 'Plt_72'] <- 0
FinalData[is.na(FinalData$`Cryo_72`), 'Cryo_72'] <- 0

#Vasopressor & inotrope usage ----

source('inopressors.R')
FinalData <- left_join(FinalData, vimax)
rm(vimax)

#Calcium supplementation ----
#This block loads in codes from MIMIC that classify interventions performed
#Returns those with 'calcium' in description, will return some irrelevant codes
#Codes are then searched for in 'inputevents' table, which refers to medications
#given to the patient, in this instance calcium gluconate and calcium chloride.
#A filter is then applied to isolate to only doses given in first 24h, and a
#logical returned to FinalData table to mark if received calcium dose in first day
d_items <- csvpull('d_items')
ca_items <- d_items |> filter(grepl('Calcium', label))
ca_events <- inputevents |> #inputevents was part of LargeReads
  filter(itemid %in% ca_items$itemid &
           stay_id %in% FinalData$stay_id) |>
  left_join(FinalData, by = 'stay_id') |>
  select(
    stay_id,
    starttime,
    intime,
    itemid,
    ordercategoryname,
    secondaryordercategoryname,
    ordercomponenttypedescription,
    ordercategorydescription,
    linkorderid
  ) |>
  dplyr::mutate(time = (difftime(starttime, intime, units = 'hours'))) |>
  filter(time <= 24 & time > 0)
FinalData <- FinalData |> dplyr::mutate(`recievedcafirstday` = stay_id %in% ca_events$stay_id)

#Add Charlson Comorbidity index ----
#See comments in script
source("CCI.R", echo = F)

newcols <- c(
  'age_score',
  'Myocardial_Infarction',
  'Congestive_Cardiac_Failure',
  'Peripheral_Vascular_Disease',
  'Cerebrovascular_Disease',
  'Dementia',
  'Chronic_Pulmonary_Disease',
  'Rheumatic_disease',
  'Peptic_ulcer_disease',
  'Liver_disease',
  'Diabetes_Mellitus',
  'Any_malignancy',
  'Hemiplegia_Paraplegia',
  'Renal_disease',
  'AIDS_HIV'
)
FinalData[, newcols] <- NA
rm (newcols)

#loop runs CCI function for each row in FinalData
#nested loop parses returned list to add to matched columns in each row
l <- nrow (FinalData)
a <- which(colnames(FinalData) == 'age_score')
for (i in 1:l) {
  C <- CCI (FinalData[[i, 'hadm_id']], FinalData[[i, 'age']])
  for (j in 0:14) {
    #the CCI function returns a list of 15 elements to be added to row
    FinalData[[i, j + a]] <- C[[j + 1]]
  }
}
rm (l, i, j, C, a, diag_icd, diag_icd10, diag_icd9, d9, d10)


#This step adds the completed score in to the working dataframe FinalData
#This could be achieved within the CCI function as well, but I felt this was
#clearer than manipulating the list before returning
FinalData <- FinalData |>
  dplyr::mutate(
    Charlson =
      age_score +
      Myocardial_Infarction +
      Congestive_Cardiac_Failure +
      Peripheral_Vascular_Disease +
      Cerebrovascular_Disease +
      Dementia +
      Chronic_Pulmonary_Disease +
      Rheumatic_disease +
      Peptic_ulcer_disease +
      Liver_disease +
      Diabetes_Mellitus +
      Any_malignancy +
      Hemiplegia_Paraplegia +
      Renal_disease +
      AIDS_HIV
  ) |>
  dplyr::mutate(across(Myocardial_Infarction:AIDS_HIV, as.logical))


rm(list = setdiff(ls(), "FinalData"))

#Complete ----
#Save clean data for separate statistical work
write_csv (FinalData, 'Working Data/FinalData.csv')