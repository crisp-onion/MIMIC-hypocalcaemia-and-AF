require(readr)
require(dplyr)
ops <- read_csv('Working Data/study operations.csv')
ops <- filter(ops, bypass | valve | exclusion | other | transplant | maze)
colnames(ops)[c(4:9)] <- c('CABG','Valvular','LAAE','Other','Transplant','Cox-Maze') 
for (i in 1:(nrow(ops))) {
  ops[i,'Operation'] <- paste(colnames(ops[which(ops[i,] == T)]))
}
ops <- ops[c(1,2,3,10)]
colnames(ops) <- c('ICD Version','ICD Code','Title','Classification')
ops <- arrange(ops, `ICD Version`,`ICD Code`)
write_csv(ops, 'Working Data/Appendix 1.csv')
