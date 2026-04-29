library(readr)
d_icd <- read_csv('mimiciv/3.1/hosp/d_icd_diagnoses.csv.gz')

codes <- c('42731',
           '42732',
           d_icd[startsWith(d_icd$icd_code,'I48'),]$icd_code
)
af <- d_icd[d_icd$icd_code %in% codes,]
print(af, n = Inf)