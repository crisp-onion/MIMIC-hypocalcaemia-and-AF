require(readr)
require(dplyr)

#Chart Events ----  
#Chunked .csv read of large file to isolate rhythm record, metric height, metric weight
  f <- function (x, pos){
    subset (x,
            itemid %in% c(220048, 226512, 226730) & #Rhythms, weight, height respectively
              stay_id %in% CTS.patients$stay_id)} 
  chartevents <- read_csv_chunked (
    "mimiciv/3.1/icu/chartevents.csv.gz",
    callback = DataFrameCallback$new(f),
    chunk_size = 10000,
    col_names = T,
    cols_only (
      stay_id = "i",
      charttime = "T",
      itemid = "i",
      value = "c"),
    progress = T
  ) 
  
  Rhythms <- chartevents |> filter(itemid == 220048) |> #item id for rhythm
    arrange (stay_id, charttime)
  splitrhythms <- split.data.frame (Rhythms, Rhythms$stay_id)
  
  weight <- chartevents |> filter(itemid == 226512) |> select(stay_id, value) |>
    mutate(value = as.numeric(value))
  colnames(weight)[colnames(weight) == 'value'] <- 'weight(kg)'
  
  height <- chartevents |> filter(itemid == 226730) |> select(stay_id, value) |>
    mutate(value = as.numeric(value))
  colnames(height)[colnames(height) == 'value'] <- 'height(cm)'
  
  #Lab events ----
  #Chunked .csv read for ABG calcium values
  f <- function(x, pos){
    subset(x,
           itemid == as.integer(50808) #itemid for blood gas calcium
           & hadm_id %in% CTS.patients$hadm_id)}
  Ci <- read_csv_chunked(
    'mimiciv/3.1/hosp/labevents.csv.gz',
    callback = DataFrameCallback$new(f),
    chunk_size = 10000,
    col_names = T,
    cols_only (
      subject_id = 'i',
      hadm_id = 'i',
      itemid = 'f',
      ref_range_lower = 'd',
      ref_range_upper = 'd',
      value = 'd',
      flag = '?',
      charttime = 'T'),
    progress = T
  ) |>
    filter(!is.na(value))
  
  #input events----
  inputevents <- read_csv('mimiciv/3.1/icu/inputevents.csv.gz', show_col_types = F)
  
  #Save completed ----
  save(splitrhythms, Ci, weight, height, inputevents, file = 'Working Data/large reads.rda')
  
  rm(Rhythms, f, chartevents)