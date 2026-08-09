require(dplyr)
require(readr)
proc <- read_csv(
  file = "mimiciv/3.1/hosp/d_icd_procedures.csv.gz",
  show_col_types = F,
  col_names = T,
  trim_ws = T
) |> arrange(icd_version, icd_code)

#Valvular procedures
Valve <- c  (
  3510:3533,
  3599,
  proc$icd_code[between(proc$icd_code, '027F04Z', '027J4ZZ') &
                  grepl('Open', proc$long_title)],
  proc$icd_code[between(proc$icd_code, '02BF0ZX', '02BJ4ZZ') &
                  grepl('Open', proc$long_title)],
  proc$icd_code[between(proc$icd_code, '02Q90ZZ', '02Q94ZZ') &
                  grepl('Open', proc$long_title)],
  proc$icd_code[between(proc$icd_code, '02QD0ZZ', '02QJ4ZZ') &
                  grepl('Open', proc$long_title)],
  proc$icd_code[between(proc$icd_code, '02R907Z', '02R94KZ') &
                  grepl('Open', proc$long_title)],
  proc$icd_code[between(proc$icd_code, '02RD07Z', '02RJ4KZ') &
                  grepl('Open', proc$long_title)],
  proc$icd_code[between(proc$icd_code, '02U907Z', '02U94KZ') &
                  grepl('Open', proc$long_title)],
  proc$icd_code[between(proc$icd_code, '02UD07Z', '02UJ4KZ') &
                  grepl('Open', proc$long_title)]
)

#Coronary artery bypass grafting
CABG <- c   (3603,
             3610:3619,
             362,
             3631,
             proc$icd_code[startsWith(proc$icd_code, '021') &
                             grepl('Coronary', proc$long_title) &
                             grepl('Open', proc$long_title) &
                             proc$icd_version == 10],
             proc$icd_code[startsWith(proc$icd_code, '02Q') &
                             grepl('Coronary', proc$long_title) &
                             grepl('Open', proc$long_title) &
                             proc$icd_version == 10],
             proc$icd_code[between(proc$icd_code, '02U007Z', '02U34KZ') &
                             grepl('Open', proc$long_title)])

#Cox-Maze
Conduc <- c (3733, '02580ZZ', '02560ZZ', '02570ZZ')

#Any other cardiac surgery
Other <- c (
  3534:3551,
  3553,
  3554,
  3556:3595,
  3598,
  3710:3712,
  3731:3732,
  3735,
  3749,
  proc$icd_code[between(proc$icd_code, '021608P', '021L4ZW')],
  proc$icd_code[between(proc$icd_code, '024', '02564ZZ') &
                  proc$icd_version == 10],
  proc$icd_code[between(proc$icd_code, '02570ZZ', '025X4ZZ') &
                  grepl('Open', proc$long_title)],
  proc$icd_code[between(proc$icd_code, '02B73ZX', '02B74ZZ')],
  proc$icd_code[between(proc$icd_code, '02B80ZX', '02B84ZZ')],
  proc$icd_code[between(proc$icd_code, '02B90ZX', '02BD4ZZ')],
  proc$icd_code[between(proc$icd_code, '02BK0ZX', '02BP4ZZ') &
                  grepl('Open', proc$long_title)],
  proc$icd_code[between(proc$icd_code, '02C00Z6', '02CP0ZZ') &
                  grepl('Open', proc$long_title)],
  '02CX0ZZ',
  proc$icd_code[startsWith(proc$icd_code, '02C') &
                  grepl('Open', proc$long_title)],
  proc$icd_code[between(proc$icd_code, '02Q50ZZ', '02Q84ZZ')],
  proc$icd_code[between(proc$icd_code, '02QK0ZZ', '02QP4ZZ')& 
                  grepl('Open', proc$long_title)],
  proc$icd_code[between(proc$icd_code, '02QX0ZZ', '02QX4ZZ')],
  proc$icd_code[between(proc$icd_code, '02R507Z', '02R74KZ')],
  proc$icd_code[between(proc$icd_code, '02RK07Z', '02TN4ZZ')],
  proc$icd_code[between(proc$icd_code, '02U507Z', '02U74KZ') &
                  grepl('Open', proc$long_title)],
  proc$icd_code[between(proc$icd_code, '02UA07Z', '02UA4KZ') & 
                  grepl('Open', proc$long_title)],
  proc$icd_code[between(proc$icd_code, '02UK07Z', '02UX4KZ') &
                  grepl('Open', proc$long_title)]
)

Other <- Other[!(Other %in% Conduc)]

#Left atrial appendage exclusion
LAAE <- c(3736, '02570ZK', '02B73ZK', '02L70CK')

#Cardiac transplant
Trans <- c(3751, proc$icd_code[startsWith(proc$icd_code, '02Y')])

#Bypass codes
CPB <- c(3961, '5A1221Z', '5A1221J')

proc <- proc %>% mutate(
  valve = proc$icd_code %in% Valve,
  bypass = proc$icd_code %in% CABG,
  other = proc$icd_code %in% Other,
  exclusion = proc$icd_code %in% LAAE,
  transplant = proc$icd_code %in% Trans,
  maze = proc$icd_code %in% Conduc,
  CPB = proc$icd_code %in% CPB
) %>%
  filter (valve |
            bypass | other | exclusion | maze | transplant | CPB)