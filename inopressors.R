require(extremevalues)
require(dplyr)
source('functions.R')

timeframe <- 24 #hours

vi <- c(
  221653,
  221662,
  221749,
  221289,
  221906,
  221986,
  222315,
  227692,
  229617,
  229630,
  229631,
  229632,
  229709,
  229764
)
d_items <- csvpull('d_items')
vi <- d_items[d_items$itemid %in% vi , 1:2]
print(vi)

#1 221289 Epinephrine
#2 221653 Dobutamine
#3 221662 Dopamine
#4 221749 Phenylephrine
#5 221906 Norepinephrine
#6 221986 Milrinone
#7 222315 Vasopressin
#8 227692 Isuprel
#9 229617 Epinephrine.
#10 229630 Phenylephrine (50/250)
#11 229631 Phenylephrine (200/250)_OLD_1
#12 229632 Phenylephrine (200/250)
#13 229709 Angiotensin II (Giapreza)
#14 229764 Angiotensin II (Giapreza)

vievents <- inner_join(inputevents, vi, by = 'itemid')
vievents <- dplyr::select(vievents,
                          hadm_id,
                          stay_id,
                          itemid,
                          label,
                          rate,
                          rateuom,
                          starttime,
                          endtime)
vievents <- vievents[complete.cases(vievents), ]

#simplify labels
vievents$label[startsWith(vievents$label, 'Ph')] <- 'Phenylephrine'
vievents$label[startsWith(vievents$label, 'An')] <- 'Angiotensin'
vievents$label[startsWith(vievents$label, 'Ep')] <- 'Epinephrine'

#angiotensin has two item id's, one measured in mcg/kg/min, the other in ng/kg/min
#convert the mcg to ng
vievents <- mutate(
  vievents,
  rate = if_else(itemid == 229709, rate * 1000, rate),
  rateuom = if_else(itemid == 229709, 'ng/kg/min', rateuom)
)

#vasopressin has similar issue with u/min or u/h but only one itemid
#convert u/h to u/min
vievents <- vievents |> mutate(
  rate = if_else(rateuom == 'units/hour', rate / 60, rate),
  rateuom = if_else(rateuom == 'units/hour', 'units/min', rateuom)
)

#Some values in the rate are bizarre, removed by excluding large outliers, negative values, and short run times
#Large outliers are identifed by splitting by infusion type, and a weibull distribution is used
#as a small number of infuisons must be high dose
vievents <- vievents |>
  filter(rate >= 0) |>
  filter(endtime > starttime + as.difftime(20, units = 'mins'))

visplit <- split (vievents, vievents$label)
outliers <- lapply (visplit, function(.x)
  getOutliers(
    .x$rate,
    rho = c(1, 50),
    FLim = c(0.1, 0.8),
    distribution = 'weibull'
  ))
l = length(visplit)
for (i in 1:l) {
  visplit[[i]] <- filter(visplit[[i]], rate < outliers[[i]]$limit[[2]])
}
vievents <- do.call(rbind, visplit)

#Select only study subjects and within the timeframe set above
vievents <- left_join(vievents, FinalData[c('stay_id', 'intime')], by = 'stay_id') |>
  filter(starttime <= intime + as.difftime(timeframe, units = 'hours'))

#largest dose of each vasopressor/inotrope in first 'timeframe' hours
vievents <- select(vievents, stay_id, label, rate, rateuom) |>
  group_by(stay_id, `label`) |>
  filter(row_number(-rate) == 1) |>
  mutate(rate = signif(rate, digits = 2)) |>
  ungroup()

#new dataframe with maximums
vimax <-  as.data.frame(FinalData$stay_id) |>
  rename(stay_id = `FinalData$stay_id`)

newcols <- paste0(unique(vievents$label) , '.max', timeframe)
vimax[, newcols] <- 0

print(unique(vievents[c('label', 'rateuom')]))
write_csv(unique(vievents[c('label', 'rateuom')]), 'Working Data/inopressor_units.csv')

#step through vievents table and insert values into vimax table
l <- nrow(vievents)
for (i in 1:l) {
  y <- which(vimax$stay_id == vievents[[i, 1]])
  x <- grep(vievents[[i, 2]], names(vimax))
  vimax[[y, x]] <- vievents[[i, 3]]
}

#Exclude any stayid with improper weight or bmi due to weight-based dosing
vimax[vimax$stay_id %in% badweight, newcols] <- NA

rm(timeframe, vi, d_items, vievents, newcols, l, i, x, y, visplit)