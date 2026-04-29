require(readr)
d_items <- read_csv('mimiciv/3.1/icu/d_items.csv.gz')
ca_items <- d_items %>% filter(grepl('Calcium',label))
inputevents <- read_csv('mimiciv/3.1/icu/inputevents.csv.gz')
ca_events <- inputevents %>% filter(itemid %in% ca_items$itemid & stay_id %in% Final$stay_id)
ca_events <- ca_events %>% left_join(Final, by = 'stay_id') %>% 
  select(stay_id, 
         starttime, 
         intime, 
         itemid, 
         ordercategoryname, 
         secondaryordercategoryname, 
         ordercomponenttypedescription, 
         ordercategorydescription,
         linkorderid) %>%
  mutate(time = (difftime(starttime, intime, units = 'days'))) %>%
  filter(time <= 1)

Final <- Final %>% mutate(`recievedcafirstday` = stay_id %in% ca_events$stay_id)
print(paste0((round((mean(Final$recievedcafirstday)*100), digits = 1)), '% given calcium first day.'))
