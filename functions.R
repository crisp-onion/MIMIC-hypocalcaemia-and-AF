#csvpull ----
#used for reads of small elements of database with readr guessed column types
csvpull <- function(mimic_table) {
  require(readr)
  icutables <- list.files('mimiciv/3.1/icu')
  hosptables <- list.files('mimiciv/3.1/hosp')
  tables <- c(icutables, hosptables)
  
  h <- sum (grepl (mimic_table, hosptables))
  i <- sum (grepl (mimic_table, icutables))
  
  if (h + i == 0) {
    return(errorCondition('no match - check spelling'))
  }
  
  if (h + i > 1) {
    return(errorCondition('More than one match, provide longer mimic_table name'))
  }
  
  if (h == 1) {
    x <- 'hosp/'
  }
  if (i == 1) {
    x <- 'icu/'
  }
  
  y <- tables[grepl(mimic_table, tables)]
  
  df <- read_csv(paste0('mimiciv/3.1/', x, y))
  
  return(df)
}

#simple remove outliers ----
replace_outliers_with_na_iqr <- function(x) {
  # Calculate quartiles and IQR
  q1 <- quantile(x, 0.25, na.rm = TRUE)
  q3 <- quantile(x, 0.75, na.rm = TRUE)
  iqr <- q3 - q1
  
  # Define lower and upper bounds
  lower_bound <- q1 - 1.5 * iqr
  upper_bound <- q3 + 1.5 * iqr
  
  # Replace values outside the bounds with NA
  x[x < lower_bound | x > upper_bound] <- NA
  return(x)
}

#surgcheck ---- used to apply all categories of surgery that each patient recieved
#returns simple true/false for checked elements (see 'Procedure Class.R')
surgcheck <- function(hospid,
                      surg = c('valvular',
                               'coronary_bypass',
                               'atrial_exclusion',
                               'maze',
                               'transplant',
                               'other')) {
  require(dplyr)
  if (!exists('proc')) {source('Procedure class.R')}
  x <- Hosp_proc |> filter(hadm_id == hospid)
  x <- x$icd_code
  
  if (('valvular' %in% surg) & any(x %in% Valve)) {
    return(T)
  } else if (('coronary_bypass' %in% surg) & any(x %in% CABG)) {
    return(T)
  } else if (('atrial_exclusion' %in% surg) & any(x %in% LAAE)) {
    return(T)
  } else if (('maze' %in% surg) & any(x %in% Conduc)) {
    return(T)
  } else if (('transplant' %in% surg) & any(x %in% Trans)) {
    return(T)
  } else if (('other' %in% surg) & any(x %in% Other)) {
    return(T)
  } else if (('CPB' %in% surg) & any(x %in% CPB)) {
    return(T)
  } else {
    return(F)
  }
}
