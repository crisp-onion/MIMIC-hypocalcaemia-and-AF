#Setup ----
rm(list = ls())
#source('Data extraction.R', local = T, echo = F)

library(ggplot2)
library(ggeffects)
library(mgcv)
library(gtsummary)
library(readr)
library(dplyr)

Final <- read_csv('Working Data/FinalData.csv', show_col_types = F) |>
  #Remove all patients who had Cox-Maze or similar surgery
  filter(!maze) #|> 
#filter_out(difftime(FirstAFtime, intime, units = 'days') <1) #|> filter_out(difftime(outtime,intime, units = 'days') <1)

#Above commented-out line exclude patients with stay <24 hours or who developed AF within the first day
#This was done in response to concerns around temporality of calcium supplementation and AF development,
#but this significantly strengthened the association between hypocalcaemia and AF development, 
#and thus was not included in the final analysis as was not part of original question design.

iCa_AF <- read_csv('Working Data/iCa values for AF developed.csv', show_col_types = F)
iCa_AF <- iCa_AF |>
  mutate(time = as.numeric(difftime(charttime, intime, units = 'days'))) |>
  filter(hadm_id %in% Final$hadm_id)
iCa_SR <- read_csv('Working Data/iCa values for no AF.csv', show_col_types = F)
iCa_SR <- iCa_SR |>
  mutate(time = as.numeric(difftime(charttime, intime, units = 'days'))) |>
  filter(hadm_id %in% Final$hadm_id)
iCa_SR[, 'Cohort'] <- 'No AF'
iCa_AF[, 'Cohort'] <- 'Developed AF'
All_iCa <- rbind.data.frame(iCa_SR, iCa_AF)


labellist <- list(
  recievedcafirstday = 'Calcium supplemented',
  min.iCa.24 = 'Lowest iCa first 24h',
  Initial_iCa = 'First iCa',
  any_hypocalcaemia = 'Any hypocacaemia first day (<1.12mmol/L)',
  male = 'Male Gender',
  age = 'Age',
  Phenylephrine.max24 = 'Phenylephrine peak',
  Norepinephrine.max24 = 'Noradrenaline peak',
  Vasopressin.max24 = 'Vasopressin peak',
  Milrinone.max24 = 'Milrinone peak',
  Dobutamine.max24 = 'Dobutamine peak',
  Dopamine.max24 = 'Dopamine peak',
  Epinephrine.max24 = 'Adrenaline peak',
  Isuprel.max24 = 'Isoprenaline peak',
  PRBC_72 = 'PRBC volume',
  FFP_72 = 'FFP volume',
  Plt_72 = 'Platelet volume',
  Cryo_72 = 'Cryoprecipitate volume',
  valvular = 'Valvular procedure',
  coronary_bypass = 'CABG',
  atrial_exclusion = 'LAAE',
  other = 'Other surgeries',
  insurance = 'Insurance',
  race = 'Ethnicity',
  Myocardial_Infarction = 'Myocardial Infarction',
  Congestive_Cardiac_Failure = 'CCF',
  Peripheral_Vascular_Disease = 'Peripheral Vascular Disease',
  Cerebrovascular_Disease = 'Cerebrovascular Disease',
  Chronic_Pulmonary_Disease = 'Chronic Pulmonary Disease',
  Rheumatic_disease = 'Rheumatic disease',
  Peptic_ulcer_disease = 'Peptic Ulcer disease',
  Liver_disease = 'Liver disease',
  Diabetes_Mellitus = 'Diabetes Mellitus',
  Any_malignancy = 'Malignancy',
  Hemiplegia_Paraplegia = 'Hemiplegia/Paraplegia',
  Renal_disease = 'Chronic Kidney disease',
  AIDS_HIV = 'AIDS/HIV',
  admission_type = 'Admission Class',
  Diabetes_Mellitus = 'Diabetes',
  los = "Length of Stay",
  timetoaf.days = 'Median time to AF (in ICU)',
  hospital_expire_flag = 'In-hospital Mortality',
  Developed_AF = 'Developed AF'
)

#Number of samples ----
samples <- All_iCa |>
  filter(time < 1, hadm_id %in% Final$hadm_id) |>
  select(hadm_id, Cohort) |>
  group_by(hadm_id) |>
  summarise(count = n(), Cohort = max(Cohort))
print(
  paste(
    'Among patients who did not develop AF',
    signif(nrow (iCa_SR[iCa_SR$time < 1 &
                          iCa_SR$hadm_id %in% Final$hadm_id, ]) / length (unique (iCa_SR[iCa_SR$hadm_id %in% Final$hadm_id, ]$hadm_id)), 3),
    'ABGs were performed on the first day, while',
    signif(nrow (iCa_AF[iCa_AF$time < 1 &
                          iCa_AF$hadm_id %in% Final$hadm_id, ]) / length (unique (iCa_AF[iCa_AF$hadm_id %in% Final$hadm_id, ]$hadm_id)), 3),
    'were peformed in the group that did develop AF.'
  )
)


#Tables ----
Table1 <- Final |>   #Cohort characteristics
  dplyr::mutate(Procedure = (if_else(
    coronary_bypass,
    if_else(valvular, 'Combined CABG & Valvular', 'CABG Only'),
    if_else(valvular, 'Valvular Only', if_else(
      other, 'Other', if_else(
        maze,
        'Ablation Only',
        if_else(atrial_exclusion, 'Exclusion Only', 'data error')
      )
    ))
  ))) %>%
  select(
    'Developed_AF',
    'male',
    'age',
    'BMI',
    'Procedure',
    'atrial_exclusion',
    'Charlson',
    'Myocardial_Infarction',
    'Congestive_Cardiac_Failure',
    'Peripheral_Vascular_Disease',
    'Chronic_Pulmonary_Disease',
    'Renal_disease',
    'Diabetes_Mellitus',
    'Liver_disease',
    'Any_malignancy',
    'Dementia',
    'Cerebrovascular_Disease'
  ) |>
  tbl_summary(
    by = 'Developed_AF',
    statistic = male ~ '{n} ({p}%)',
    label = list(
      Charlson ~ 'Charlson Comorbidity Index',
      male ~ 'Male',
      age ~ 'Age',
      atrial_exclusion ~ 'LAAE',
      Myocardial_Infarction ~ 'MI',
      Congestive_Cardiac_Failure ~ 'CCF',
      Peripheral_Vascular_Disease ~ 'Periph. Vasc. Disease',
      Chronic_Pulmonary_Disease ~ 'Chronic Pulm. Disease',
      Renal_disease ~ 'CKD',
      Diabetes_Mellitus ~ 'Diabetes Mellitus',
      Liver_disease ~ 'Liver disease',
      Any_malignancy ~ 'Malignancy',
      Cerebrovascular_Disease ~ 'Cerebrovascular Disease'
    ),
    missing = 'ifany',
    missing_text = "(Invalid/Missing)"
  ) |>
  add_p(pvalue_fun = label_style_pvalue(digits = 2)) |>
  add_significance_stars() |>
  separate_p_footnotes() |>
  add_overall() |>
  bold_p() |>
  add_difference() |>
  modify_header(stat_1 = "**No AF**  \nN = {n}", stat_2 = "**Developed AF**  \nN = {n}") |>
  modify_spanning_header(c("stat_1", "stat_2") ~ "**Cohort**") |>
  modify_caption("**Table 1. Cohort Characteristics**") |>
  modify_abbreviation('AF = Atrial Fibrillation') |>
  modify_abbreviation('BMI = Body Mass Index') |>
  modify_abbreviation('CABG = Coronary Artery Bypass Grafting') |>
  modify_abbreviation('LAAE = Left Atrial Appendage Exclusion') |>
  modify_abbreviation('MI = Myocardial Infarction') |>
  modify_abbreviation('CCF = Congestive Cardiac Failure') |>
  modify_abbreviation('Periph. Vasc. Disease = Peripheral Vascular Disease') |>
  modify_abbreviation('Chronic Pulm. Disease = Chronic Pulmonary Disease') |>
  modify_abbreviation('CKD = Chronic Kidney Disease')


print(Table1)

Table2 <- Final |> #Cohort interventions/outcomes
  select(
    'timetoaf.days',
    'Developed_AF',
    'Initial_iCa',
    'min.iCa.24',
    'any_hypocalcaemia',
    'los',
    'PRBC_72',
    'FFP_72',
    'Plt_72',
    'Cryo_72',
    'recievedcafirstday',
    'hospital_expire_flag'
  ) |>
  tbl_summary(
    by = 'Developed_AF',
    statistic = list(
      c(
        `PRBC_72`,
        `FFP_72`,
        `Plt_72`,
        `Cryo_72`,
        Initial_iCa,
        min.iCa.24
      ) ~ "{mean} (±{sd})",
      c(los, timetoaf.days) ~ "{median} ({p25}, {p75})"
    ),
    label = labellist,
    missing = 'no',
    missing_text = "(Missing)",
    digits = list(`Cryo_72` ~ 2)
  ) |>
  add_p(pvalue_fun = label_style_pvalue(digits = 2)) |>
  add_significance_stars() |>
  separate_p_footnotes() |>
  bold_p() |>
  add_overall() |>
  modify_header(stat_1 = "**No AF**  \nN = {n}", stat_2 = "**Developed AF**  \nN = {n}") |>
  modify_spanning_header(c("stat_1", "stat_2") ~ "**Cohort**") |>
  modify_caption("**Table 2. Cohort interventions & outcomes**") |>
  modify_abbreviation ('iCa = Ionized Calcium') |>
  modify_abbreviation ('AF = Atrial Fibrillation') |>
  modify_abbreviation('ICU = Intensive Care Unit') |>
  modify_abbreviation ('PRBC = Packed Red Blood Cells') |>
  modify_abbreviation ('FFP = Fresh Frozen Plasma') 

Table2[["table_body"]][["stat_1"]][[1]] <- ' '
Table2[["table_body"]][["stat_0"]][[1]] <- ' '

print(Table2)

#Refactoring ----
refactored <- Final |>
  dplyr::select(!1:5) |>
  dplyr::select(-dod, -FirstAFtime, -timetoaf.days) |>
  mutate(BMI = cut(
    BMI,
    breaks = c(0, 18.5, 25, 30, 35, 40, 50, 80),
    labels = c(
      '<18.5',
      '18.5-24.9',
      '25-29.9',
      '30-34.9',
      '35-39.9',
      '40-49.9',
      '>50'
    ),
    include.lowest = T
  )) |>
  #change scales of factors to give OR's that make sense after glm
  mutate(
    min.iCa.24 = (min.iCa.24 - 1) * 100,
    Initial_iCa = (Initial_iCa - 1) * 100,
    PRBC_72 = PRBC_72 / 100,
    FFP_72 = FFP_72 / 100,
    Plt_72 = Plt_72 / 100,
    Cryo_72 = Cryo_72 / 100,
    Vasopressin.max24 = Vasopressin.max24 * 100,
    Norepinephrine.max24 = Norepinephrine.max24 * 100,
    Epinephrine.max24 = Epinephrine.max24 * 100,
    Isuprel.max24 = Isuprel.max24 * 100,
    Milrinone.max24 = Milrinone.max24 * 10
  )

refactored$BMI <- relevel(factor(refactored$BMI), ref = '18.5-24.9')
refactored$race <- as.factor(refactored$race) |> relevel(ref = 'WHITE')
refactored$insurance <- as.factor(refactored$insurance) |> relevel(ref = 'Private')
refactored$admission_type <- as.factor(refactored$admission_type) |> relevel(ref = 'ELECTIVE')

#calcium - per 0.01mmol/l & centered around 1mmol/l
#blood - per 100mL
#vasopressin, noradrenaline, adrenaline, isoprenaline * 100
#milrinone * 10

#  mutate(age = cut(age, breaks = c(0,18,30,40,50,60,70,80,90,120),
#                   labels = c('<18','18-29','30-39','40-49','50-59','60-69','70-79','80-89','90+'),
#                   include.lowest = T))

refactored2 <- Final |>
  dplyr::select(!1:5) |>
  dplyr::select(-dod, -FirstAFtime, -timetoaf.days) |>
  mutate(BMI = cut(
    BMI,
    breaks = c(0, 18.5, 25, 30, 35, 40, 50, 80),
    labels = c(
      '<18.5',
      '18.5-24.9',
      '25-29.9',
      '30-34.9',
      '35-39.9',
      '40-49.9',
      '>50'
    ),
    include.lowest = T
  )) |>
  mutate(across(where(is.logical), as.factor))

refactored2$BMI <- relevel(factor(refactored2$BMI), ref = '18.5-24.9')
refactored2$race <- as.factor(refactored2$race) |> relevel(ref = 'WHITE')
refactored2$insurance <- as.factor(refactored2$insurance) |> relevel(ref = 'Private')
refactored2$admission_type <- as.factor(refactored2$admission_type) |> relevel(ref = 'ELECTIVE')



#Univariate modelling ----

tbl_uvregression(
  refactored,
  y = 'Developed_AF',
  method = glm,
  label = labellist,
  show_single_row = all_dichotomous()
) |>
  bold_p() |>
  modify_caption('*Univariate Modelling*')

s_init <- glm(Developed_AF ~ Initial_iCa,
              data = refactored,
              family = binomial())
summary(s_init)

s_min <- glm(Developed_AF ~ min.iCa.24,
             data = refactored,
             family = binomial())
summary(s_min)

#Logistic Modelling ----

glm_model_init <- glm (
  Developed_AF ~
    Initial_iCa +
    recievedcafirstday +
    male +
    age +
    BMI +
    Phenylephrine.max24 +
    Norepinephrine.max24 +
    Vasopressin.max24 +
    Milrinone.max24 +
    Dobutamine.max24 +
    Dopamine.max24 +
    Epinephrine.max24 +
    Isuprel.max24 +
    PRBC_72 +
    FFP_72 +
    Plt_72 +
    Cryo_72 +
    valvular +
    coronary_bypass +
    atrial_exclusion +
    other +
    insurance +
    race +
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
    AIDS_HIV +
    admission_type,
  family = binomial(),
  data = refactored
)
summary(glm_model_init)

glm_model_supp <- glm (
  Developed_AF ~
    min.iCa.24 +
    recievedcafirstday +
    male +
    age +
    BMI +
    Phenylephrine.max24 +
    Norepinephrine.max24 +
    Vasopressin.max24 +
    Milrinone.max24 +
    Dobutamine.max24 +
    Dopamine.max24 +
    Epinephrine.max24 +
    Isuprel.max24 +
    PRBC_72 +
    FFP_72 +
    Plt_72 +
    Cryo_72 +
    valvular +
    coronary_bypass +
    atrial_exclusion +
    other +
    insurance +
    race +
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
    AIDS_HIV +
    admission_type,
  family = binomial(),
  data = refactored
)

glm_model_stepped <- glm (
  Developed_AF ~
    min.iCa.24 +
    recievedcafirstday +
    male +
    age +
    BMI +
    Phenylephrine.max24 +
    Norepinephrine.max24 +
    Vasopressin.max24 +
    Milrinone.max24 +
    Dobutamine.max24 +
    Dopamine.max24 +
    Epinephrine.max24 +
    Isuprel.max24 +
    PRBC_72 +
    FFP_72 +
    Plt_72 +
    Cryo_72 +
    valvular +
    coronary_bypass +
    atrial_exclusion +
    other +
    insurance +
    race +
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
    AIDS_HIV +
    admission_type,
  family = binomial(),
  data = na.omit(refactored)
)
glm_model_stepped <- step(glm_model_stepped, direction = 'backward')

glm_model_supp_b <- glm (
  Developed_AF ~
    any_hypocalcaemia +
    recievedcafirstday +
    male +
    age +
    BMI +
    Phenylephrine.max24 +
    Norepinephrine.max24 +
    Vasopressin.max24 +
    Milrinone.max24 +
    Dobutamine.max24 +
    Dopamine.max24 +
    Epinephrine.max24 +
    Isuprel.max24 +
    PRBC_72 +
    FFP_72 +
    Plt_72 +
    Cryo_72 +
    valvular +
    coronary_bypass +
    atrial_exclusion +
    other +
    insurance +
    race +
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
    AIDS_HIV +
    admission_type,
  family = binomial(),
  data = refactored
)

summary(glm_model_supp)
summary(glm_model_supp_b)
summary(glm_model_stepped)

glm_model_4plot <- glm (
  Developed_AF ~
    min.iCa.24 +
    recievedcafirstday +
    male +
    age +
    BMI +
    Phenylephrine.max24 +
    Norepinephrine.max24 +
    Vasopressin.max24 +
    Milrinone.max24 +
    Dobutamine.max24 +
    Dopamine.max24 +
    Epinephrine.max24 +
    Isuprel.max24 +
    PRBC_72 +
    FFP_72 +
    Plt_72 +
    Cryo_72 +
    valvular +
    coronary_bypass +
    atrial_exclusion +
    other +
    insurance +
    race +
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
    AIDS_HIV +
    admission_type,
  family = binomial(),
  data = na.omit(refactored2)
)
glm_model_stepped2 <- step(glm_model_4plot, direction = 'backward')

#change analysis for retrospective cohort
glm_model_rc <- glm (
  any_hypocalcaemia ~
    Developed_AF +
    recievedcafirstday +
    male +
    age +
    BMI +
    Phenylephrine.max24 +
    Norepinephrine.max24 +
    Vasopressin.max24 +
    Milrinone.max24 +
    Dobutamine.max24 +
    Dopamine.max24 +
    Epinephrine.max24 +
    Isuprel.max24 +
    PRBC_72 +
    FFP_72 +
    Plt_72 +
    Cryo_72 +
    valvular +
    coronary_bypass +
    atrial_exclusion +
    other +
    insurance +
    race +
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
    AIDS_HIV +
    admission_type,
  family = binomial(),
  data = refactored
)

glm_model_death <- glm (
  hospital_expire_flag ~
    Developed_AF +
    any_hypocalcaemia +
    recievedcafirstday +
    male +
    age +
    BMI +
    Phenylephrine.max24 +
    Norepinephrine.max24 +
    Vasopressin.max24 +
    Milrinone.max24 +
    Dobutamine.max24 +
    Dopamine.max24 +
    Epinephrine.max24 +
    Isuprel.max24 +
    PRBC_72 +
    FFP_72 +
    Plt_72 +
    Cryo_72 +
    valvular +
    coronary_bypass +
    atrial_exclusion +
    other +
    insurance +
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
    AIDS_HIV +
    admission_type,
  family = binomial(),
  data = refactored
)
summary(glm_model_death)

#Multivariate Tables ----

mainstatsmin <- tbl_regression(
  glm_model_supp,
  exponentiate = T,
  show_single_row = all_dichotomous(),
  label = labellist
) |>
  add_global_p() |>
  bold_p() |>
  add_vif() |>
  modify_caption('Appendix 3. Complete Logistic Regression Model for minimum iCa for First Day ICU')

print(mainstatsmin)

mainstatsmin.b <- tbl_regression(
  glm_model_supp_b,
  exponentiate = T,
  show_single_row = all_dichotomous(),
  label = labellist
) |>
  add_global_p() |>
  bold_p() |>
  add_vif() |>
  modify_caption(
    'Appendix 4. Complete Logistic Regression Model for any episode of hypocalcaemia of First Day ICU'
  )

print(mainstatsmin.b)

shortstatsmin <- tbl_regression(
  glm_model_stepped,
  exponentiate = T,
  show_single_row = all_dichotomous(),
  label = labellist
) |>
  bold_p() |>
  modify_caption(
    '**Table 3. Multivariate logistic regression for lowest first day iCa and occurrence of AF**'
  ) |>
  modify_abbreviation ('iCa = Ionized Calcium') |>
  modify_abbreviation ('AF = Atrial Fibrillation') |>
  modify_abbreviation ('BMI = Body Mass Index') |>
  modify_abbreviation ('PRBC = Packed Red Blood Cells') |>
  modify_abbreviation ('FFP = Fresh Frozen Plasma') |>
  modify_abbreviation ('LAAE = Left Atrial Appendage Exclusion') |>
  modify_abbreviation ('CCF = Congestive Cardiac Failure') |>
  modify_footnote_header('Odds Ratios are per 0.01mmol/L decrease in iCa, or per 100mL of blood product transfused. See methods for details.',
    columns = c('estimate','conf.low'), replace = F
  ); print(shortstatsmin)

mainstatsinit <- tbl_regression(
  glm_model_init,
  exponentiate = T,
  show_single_row = all_dichotomous(),
  label = labellist
) |>
  add_global_p() |>
  bold_p() |>
  add_vif() |>
  modify_caption('Appendix 5. Complete Multivariate Logistic Regression Model for first iCa in ICU')

print(mainstatsinit)

mainstatsdeath <- tbl_regression(
  glm_model_death,
  exponentiate = T,
  show_single_row = all_dichotomous(),
  label = labellist
) |>
  bold_p() |>
  add_vif() |>
  modify_caption('Appendix 6. Complete Multivariate Logistic Regression Model for in-hospital mortality')

print(mainstatsdeath)

#Fisher exact ----


fish.repaf <- fisher.test(refactored$Developed_AF, refactored$recievedcafirstday)
fish.replow <-fisher.test(refactored$any_hypocalcaemia, refactored$recievedcafirstday)
fish.samples <- fisher.test(samples$Cohort, samples$count, simulate.p.value = T)

print(list(fish.repaf, fish.replow, fish.samples))

#Descriptive Graphics ----

sevendaymeanplot <- ggplot(data = filter(All_iCa,time<10), mapping = aes(x = time, y = value, color = Cohort)) +
  geom_smooth(
    method = 'loess',
    span = 0.15,
    se = T,
    show.legend = T
  ) +  
  scale_color_discrete(palette = 'Set1') +
  geom_hline(yintercept = 1.12,
             linetype = 4,
             color = 'navy') +
  annotate(
    "text",
    x = 0.5,
    y = 1.12,
    color = 'navy',
    label = 'Lower limit normal',
    vjust = 1.2
  ) +
  coord_cartesian(xlim = c(0, 7), ylim = c(1.1, 1.205)) +
  scale_x_continuous(expand = expansion (0), breaks = 1:7) +
  scale_y_continuous(
    expand = expansion (0),
    breaks = c(1.1, 1.15, 1.2),
    minor_breaks = c(1.11, 1.12, 1.13, 1.14, 1.15, 1.16, 1.17, 1.18, 1.19)
  ) +
  theme_minimal() +
  labs(
    x = "Time in ICU (days)",
    y = "Ionized Calcium (mmol/L)",
    title = "Figure 3. Mean ionized calcium levels for first 7 days",
    subtitle = 'Measured via blood gas in ICU',
    caption = 'Trends in mean ionized calcium levels in each cohort with 95% confidence intervals\n
       ICU: Intensive Care Unit'
  )+
  theme(plot.caption = element_text(lineheight = 0.5)); print(sevendaymeanplot)

ggplot(data = Final, aes(x = los, fill = Developed_AF)) +
  geom_histogram(binwidth = 1, position = 'dodge') +
  coord_cartesian(xlim = c(0, 7)) +
  labs(x = 'Length of stay in ICU (days)', y = 'Number of patients', title = 'Duration of stay in ICU')

boxmin <- ggplot(data = Final, aes(x = Developed_AF, y = min.iCa.24, fill = Developed_AF)) +
  geom_boxplot() +
  labs(x = 'Subject Developed POAF', y = 'Ionized Calcium (mmol/L)', title = 'Minimum calcium level during first 24 hours by cohort.') +
  geom_hline(yintercept = c(1.12,1.32),
             linetype = 4,
             color = 'navy') +
  annotate(
    "text",
    x = 0.8,
    y = c(1.12, 1.32),
    color = 'navy',
    label = paste(c('Lower','Upper'), 'limit normal'),
    vjust = -1
  ) 

boxinit <- ggplot(data = Final, aes(x = Developed_AF, y = Initial_iCa)) +
  geom_boxplot() +
  labs(x = 'Subject Developed AF', y = 'Ionized Calcium (mmol/L)', title = 'Initial calcium level by cohort.') +
  geom_hline(yintercept = c(1.12, 1.32),
             linetype = 4,
             color = 'navy') +
  annotate(
    "text",
    x = 0.8,
    y = c(1.12, 1.32),
    color = 'navy',
    label = paste(c('Lower','Upper'), 'limit normal'),
    vjust = -1
  ) 

levelsplot <- ggplot(data = All_iCa[All_iCa$time < 1, ], aes(value)) +
  geom_area(
    stat = 'bin',
    binwidth = 0.01,
    colour = 'red',
    fill = 'pink'
  ) +
  coord_cartesian(xlim = c(0.92, 1.48)) +
  labs(
    x = 'iCa (mmol/L)',
    y = 'Number of observations',
    title = 'Figure 1. Occurrence of iCa values in first 24 hours',
    caption = 'Upper and lower limit of normal represented by dashed lines\n
       iCa: Ionized Calcium'
  ) +
  geom_vline(xintercept = c(1.12, 1.32),
             linetype = 4,
             color = 'navy') +
  scale_x_continuous(breaks = 9:15 / 10) +
  theme_minimal()+
  theme(plot.caption = element_text(lineheight = 0.5)); print(levelsplot)


violinmin <- ggplot(refactored2,
       aes(x = Developed_AF, y = min.iCa.24, fill = Developed_AF)) +
  geom_violin(
    position = 'identity',
    quantile.linetype = 3,
    quantile.linewidth = 1
  ) +
  scale_fill_discrete(palette = 'Set1') +
  scale_x_discrete(name = "Developed AF",
                   labels = c("Not Developed", 'Developed')) +
  scale_y_continuous(breaks = c(0.8,0.9,1.0,1.1,1.2,1.3,1.4),
                     minor_breaks = 70:150/100) +
  theme_minimal() +
  theme(legend.position = 'none')  +
  geom_hline(yintercept = 1.12,
             linetype = 4,
             color = 'navy') +
  geom_hline(yintercept = 1.32,
             linetype = 4,
             color = 'navy') +
  labs(title = "Nadir iCa values by Cohort", y = "Lowest first-day iCa (mmol/L") +
  annotate(
    "text",
    x = 1.5,
    y = c(1.12, 1.32),
    color = 'navy',
    label = paste(c('Lower', 'Upper'),'limit normal'),
    vjust = -1
  );  print(violinmin)

#Prediction Plots ----

pred_data <- ggeffect(glm_model_stepped2, terms = "min.iCa.24 [all]")

predictedplot <- ggplot(pred_data, aes(x = x, y = predicted)) +
  geom_line(color = "slateblue1", linewidth = 1) +
  geom_ribbon(aes(ymin = conf.low, ymax = conf.high), alpha = 0.2) +
  labs(
    x = 'Nadir iCa (mmol/L) in first ICU day',
    y = 'Risk of POAF',
    title = 'Figure 2. ICU POAF risk vs first day Nadir iCa value',
    subtitle = 'As predicted by multivariable model for "average" study patient.',
    caption = '95% confidence intervals shown.\n
    Upper and lower limit of normal represented by dashed lines.\n
    Continuous covariates set at mean and categorical covariates set at mode.\n
    iCa: ionized calcium, ICU: Intensive Care Unit, POAF: Postoperative Atrial Fibrillation'
  )  +
  geom_vline(xintercept = c(1.12,1.32),
             linetype = 4,
             color = 'navy') +
  scale_x_continuous(breaks = 16:30 / 20, minor_breaks = NULL) +
  scale_y_continuous(labels = scales::percent, limits = c(0, 0.35)) +
  theme_minimal() +
  theme(plot.caption = element_text(lineheight = 0.5)); print(predictedplot)

suppplot <- ggplot(ggeffect(glm_model_stepped2, terms = 'recievedcafirstday [all]')) +
  geom_errorbar(aes(x = x, ymin = conf.low, ymax = conf.high),
                width = 0.5,
                alpha = 0.3) +
  geom_point(
    aes(x = x, y = predicted, ),
    shape = 22,
    fill = 'mediumpurple4',
    colour = 'darkgrey',
    size = 2
  ) +
  labs(
    x = "Recieved Calcium First Day",
    y = 'Risk of POAF',
    title = "POAF in ICU vs calcium supplementation",
    subtitle = 'As predicted by multivariable model\nfor "average" study patient.',
    caption = '95% confidence intervals shown.\n
    Continuous covariates set at mean and categorical covariates set at mode.\n
    POAF: Post operative atrial fibrillation, ICU: Intensive Care Unit.'
  ) +
  scale_y_continuous(labels = scales::percent, limits = c(0, 0.35)) +
  scale_x_discrete(labels = c('TRUE' = "Given", 'FALSE' = "Not Given")) +
  theme_minimal()+
  theme(plot.caption = element_text(lineheight = 0.5)); print(suppplot)
