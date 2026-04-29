source('functions.R')
library(dplyr)

timeframe <- 72 #hours

d_items <- csvpull('d_items')
bloodprods <- c(220970,225168,225170,225171,225173,226367:226372,226070:226072)
print(d_items[d_items$itemid %in% bloodprods,],n=11)

bloodevents <- inputevents[inputevents$itemid %in% bloodprods,]
bloodevents <- semi_join(bloodevents, FinalData, by = 'hadm_id')

#Confine to theatre or first `timeframe` hours ICU
bloodevents <- left_join(bloodevents, FinalData[c('hadm_id','intime')], by = 'hadm_id') |>
  filter(starttime <= intime + as.difftime(timeframe, units = 'hours'))

#Isolate PRBC
PRBCevents <- bloodevents %>% filter(itemid %in% c(226368, 225168))
#Sum-up total volume PRBC given
PRBCvol <- aggregate.data.frame(PRBCevents$amount, 
                                by = list(hadm_id = PRBCevents$hadm_id), 
                                FUN = sum)
colnames(PRBCvol)[2] <- paste0('PRBC_', timeframe)

#Isolate FFP
FFPevents <- bloodevents %>% filter(itemid %in% c(220970, 226367))
#Sum-up total volume PRBC given
FFPvol <- aggregate.data.frame(FFPevents$amount, 
                                by = list(hadm_id = FFPevents$hadm_id), 
                                FUN = sum)
colnames(FFPvol)[2] <- paste0('FFP_', timeframe)

#Isolate Platelets
Pltevents <- bloodevents %>% filter(itemid %in% c(225170, 226369))
#Sum-up total volume PRBC given
Pltvol <- aggregate.data.frame(Pltevents$amount, 
                               by = list(hadm_id = Pltevents$hadm_id), 
                               FUN = sum)
colnames(Pltvol)[2] <- paste0('Plt_', timeframe)

#Isolate Cryo
Cryoevents <- bloodevents %>% filter(itemid %in% c(225171, 226371))
#Sum-up total volume PRBC given
Cryovol <- aggregate.data.frame(Cryoevents$amount, 
                               by = list(hadm_id = Cryoevents$hadm_id), 
                               FUN = sum)
colnames(Cryovol)[2] <- paste0('Cryo_', timeframe)

#Unify
Bloodvols <- full_join(PRBCvol, FFPvol, by = 'hadm_id') |>
              full_join(Pltvol, by = 'hadm_id') |>
              full_join(Cryovol, by = 'hadm_id')

rm( d_items, bloodprods, bloodevents, PRBCevents, PRBCvol, FFPevents, 
   FFPvol, Pltevents, Pltvol, Cryoevents, Cryovol)