#Charlson Comorbidity Index
#Derived from https://github.com/MIT-LCP/mimic-code/blob/main/mimic-iv/concepts/comorbidity/charlson.sql
#Re-written to run natively in R as a set of functions

#Note: has been written to produce a list containing the components of the score; 
#but does not add them, this is completed in the main script

#install.packages("readr")
require(readr)
require(dplyr)
diag_icd <<- read_csv('mimiciv/3.1/hosp/diagnoses_icd.csv.gz', show_col_types = F)
diag_icd9 <<- subset.data.frame(diag_icd, diag_icd$icd_version == 9)
diag_icd10 <<- subset.data.frame(diag_icd, diag_icd$icd_version == 10)


CCI <- function(hid , age) {
  d9 <<- subset(diag_icd9, diag_icd9$hadm_id == hid)
  d10 <<- subset(diag_icd10, diag_icd10$hadm_id == hid)
  
  if (age <= 50){
    age_score <- 0
  } else if (age > 50 & age <= 60) {
    age_score <- 1
  } else if (age > 60 & age <= 70) {
    age_score <- 2
  } else if (age > 70 & age <= 80) {
    age_score <- 3
  } else {age_score <- 4}
  
  
  
  charlson_comorbidity_index <- list (
    age_score, 
    MI(),
    CCF(), 
    PVD(), 
    CVD(), 
    Dementia(), 
    CPD(), 
    RD(), 
    PUD(), 
    max(MLD(),3*SLD()),
    max(2*DMcc(),DM()),
    max(2*cancer(),6*mets()),
    2 * HP(),
    2 * CKD(),
    6 * HIV())
}

#Myocardial infarction
MI <- function() {
  y <- sum (startsWith (d9$icd_code,'410'), 
            startsWith (d9$icd_code,'412'),
            startsWith (d10$icd_code,'I21'),
            startsWith (d10$icd_code,'I22'),
            startsWith (d10$icd_code,'I252'))
  
  as.integer (y > 0)
}

#Congestive heart failure
CCF <- function() {
  y <- sum (startsWith (d9$icd_code,'428'),
            startsWith (d9$icd_code,'412'),
            substring (d9$icd_code,1,5) %in% c('39891', '40201', '40211', 
                                               '40291', '40401', '40403', 
                                               '40411', '40413', '40491', 
                                               '40493'),
            substring (d9$icd_code,1,4) %in% c(4254:4259),
            startsWith (d10$icd_code,'I43'),
            startsWith (d10$icd_code,'I50'),
            substring (d10$icd_code,1,4) %in% c('I099', 'I110', 'I130', 'I132', 
                                                'I255', 'I420', 'I425', 'I426', 
                                                'I427', 'I428', 'I429', 'P290'))
  
  as.integer (y > 0)
}

#Peripheral Vascular Disease
PVD <- function(){
  y <- sum (substring (d9$icd_code,1,3) %in% c('440', '441'),
            substring (d9$icd_code,1,4) %in% c('0930', '4373', '4471', '5571', 
                                               '5579', 'V434', 4431:4439),
            substring (d10$icd_code,1,3) %in% c('I70', 'I71'),
            substring (d10$icd_code,1,4) %in% c('I731', 'I738', 'I739', 'I771', 
                                                'I790', 'I792', 'K551', 'K558', 
                                                'K559', 'Z958' , 'Z959'))
  
  as.integer (y > 0)
}

#Cerebrovascular Disease
CVD <- function(){
  y <- sum (substring (d9$icd_code,1,3) %in% c(430:438),
            startsWith (d9$icd_code,'36234'),
            substring (d10$icd_code,1,3) %in% c('G45','G46'),
            startsWith (d10$icd_code,'H340'),
            between(substring(d10$icd_code,1,3),'I60','I69'))
  
  as.integer (y > 0)
}

#Dementia
Dementia <- function(){
  y <- sum (substring (d9$icd_code,1,4) %in% c('2941', '3312'),
            startsWith (d9$icd_code,'290'),
            substring (d10$icd_code,1,3) %in% c('F00', 'F01', 'F02', 'F03', 
                                                'G30'),
            substring (d10$icd_code,1,4) %in% c('F051', 'G311'))
  
  as.integer (y > 0)
}  

#Chronic pulmonary disease
CPD <- function(){
  y <- sum (between (substring (d9$icd_code,1,3),'490','505'),
            substring (d9$icd_code,1,4) %in% c('4168', '4169', '5064', '5081', 
                                               '5088'),
            between (substring (d10$icd_code,1,3),'J40','J47'),
            between (substring (d10$icd_code,1,3),'J60','J67'),
            substring (d10$icd_code,1,4) %in% c('I278', 'I279', 'J684', 'J701', 
                                                'J703'))
  
  as.integer (y > 0)
}

#Rheumatic disease
RD <- function (){
  y <- sum (substring (d9$icd_code,1,4) %in% c('4465', '7100', '7101', '7102', 
                                               '7103', '7104', '7140', '7141', 
                                               '7142', '7148'),
            startsWith (d9$icd_code, '725'),
            substring (d10$icd_code,1,3) %in% c('M05', 'M06', 'M32', 'M33', 
                                                'M34'),
            substring (d10$icd_code,1,4) %in% c('M315', 'M351', 'M353', 'M360'))
  
  as.integer (y > 0)
}

#Peptic Ulcer Disease
PUD <- function(){
  y<- sum(substring(d9$icd_code, 1, 3) %in% c("531", "532", "533", "534") ,
          substring(d10$icd_code, 1, 3) %in% c("K25", "K26", "K27", "K28"))
  
  as.integer (y > 0)
}

#Mild Liver Disease
MLD <- function() {
  y <- sum( substring(d9$icd_code, 1, 3) %in% c("570", "571") ,
    substring(d9$icd_code, 1, 4) %in% c("0706", "0709", "5733", "5734", 
                                    "5738", "5739", "V427") ,
    substring(d9$icd_code, 1, 5) %in% c("07022", "07023", "07032", "07033", 
                                    "07044", "07054") ,
    substring(d10$icd_code, 1, 3) %in% c("B18", "K73", "K74") ,
    substring(d10$icd_code, 1, 4) %in% c("K700", "K701", "K702", "K703", 
                                     "K709", "K713", "K714", "K715", 
                                     "K717", "K760", "K762", "K763", 
                                     "K764", "K768", "K769", "Z944"))
  as.integer (y > 0)
}

# Diabetes with chronic complication
DMcc <- function() {
  y<- sum (substring(d9$icd_code, 1, 4) %in% c("2504", "2505", "2506", "2507") ,
    substring(d10$icd_code, 1, 4) %in% c("E102", "E103", "E104", "E105", 
                                     "E107", "E112", "E113", "E114", 
                                     "E115", "E117", "E122", "E123", 
                                     "E124", "E125", "E127", "E132", 
                                     "E133", "E134", "E135", "E137", 
                                     "E142", "E143", "E144", "E145", "E147"))
  as.integer (y > 0)
}

#Diabetes without chronic complication
DM <- function() {
  y<- sum (substring(d9$icd_code, 1, 4) %in% c("2500", "2501", "2502", "2503", 
                                  "2508", "2509") ,
    substring(d10$icd_code, 1, 4) %in% c("E100", "E101", "E106", "E108", 
                                     "E109", "E110", "E111", "E116", 
                                     "E118", "E119", "E120", "E121", 
                                     "E126", "E128", "E129", "E130", 
                                     "E131", "E136", "E138", "E139", 
                                     "E140", "E141", "E146", "E148", "E149"))
  as.integer (y > 0)
}

# Hemiplegia or paraplegia
HP <- function(){
  y<- sum (substring(d9$icd_code, 1, 3) %in% c("342", "343") ,
    substring(d9$icd_code, 1, 4) %in% c("3341", "3440", "3441", "3442", 
                                    "3443", "3444", "3445", "3446", "3449") ,
    substring(d10$icd_code, 1, 3) %in% c("G81", "G82") ,
    substring(d10$icd_code, 1, 4) %in% c("G041", "G114", "G801", "G802", 
                                     "G830", "G831", "G832", "G833", 
                                     "G834", "G839"))
  as.integer (y > 0)
} 

#Renal Disease
CKD <- function(){
  y<- sum (substring(d9$icd_code, 1, 3) %in% c("582", "585", "586", "V56") ,
  substring(d9$icd_code, 1, 4) %in% c("5880", "V420", "V451") ,
  between (substring (d9$icd_code,1,4),'5830','5837'),
  substring(d9$icd_code, 1, 5) %in% c("40301", "40311", "40391", "40402", 
                                    "40403", "40412", "40413", "40492", "40493"),
  substring(d10$icd_code, 1, 3) %in% c("N18", "N19") ,
  substring(d10$icd_code, 1, 4) %in% c("I120", "I131", "N032", "N033", 
                                     "N034", "N035", "N036", "N037", 
                                     "N052", "N053", "N054", "N055", 
                                     "N056", "N057", "N250", "Z490", 
                                     "Z491", "Z492", "Z940", "Z992"))
  as.integer (y > 0)
}
# Any malignancy, including lymphoma and leukemia, 
# except malignant neoplasm of skin
cancer <- function(){
  y <- sum (substring (d9$icd_code,1,3) %in% c(140:172),
           substring (d9$icd_code,1,4) %in% c(1740:1958),
           substring (d9$icd_code,1,3) %in% c(200:208),
           substring (d9$icd_code,1,4) == '2386',
           substring (d10$icd_code,1,3) %in% c('C43','C88'),
           between (substring (d10$icd_code,1,3),'C00','C26'),
           between (substring (d10$icd_code,1,3),'C30','C34'),
           between (substring (d10$icd_code,1,3),'C37','C41'),
           between (substring (d10$icd_code,1,3),'C45','C58'),
           between (substring (d10$icd_code,1,3),'C60','C76'),
           between (substring (d10$icd_code,1,3),'C81','C85'),
           between (substring (d10$icd_code,1,3),'C90','C97'))
           
  as.integer (y > 0)
}

#Moderate or severe liver disease
SLD <- function(){
  y<- sum (substring (d9$icd_code,1,4) %in% c('4560', '4561', '4562', 5722:5728),
           substring (d10$icd_code,1,4) %in% c('I850', 'I859', 'I864', 'I982', 
                                               'K704', 'K711', 'K721', 'K729', 
                                               'K765', 'K766', 'K767'))
  as.integer (y > 0)
}

#Metastatic solid tumour
mets <- function(){
  y <- sum (
    substring (d9$icd_code,1,3) %in% c(196:199),
    substring (d10$icd_code,1,3) %in% c('C77', 'C78', 'C79', 'C80')
  )
  as.integer (y > 0)
}

#AIDS/HIV
HIV <- function(){
  y <- sum(
    substring (d9$icd_code,1,3) %in% c('042', '043', '044'),
    substring (d10$icd_code,1,3) %in% c('B20', 'B21', 'B22', 'B24')
  )
  as.integer (y > 0)
}