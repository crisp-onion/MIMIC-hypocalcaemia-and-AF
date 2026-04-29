# Create a plotting window with 2 rows and 2 columns
par(mfrow=c(2,2))

# Original data
hist(Final$min.iCa.24, 
     main="Original Right-Skewed Data",
     xlab="Value",
     col="lightblue",
     breaks=30)

# Natural log transformation (adding 1 to handle zeros)
log_data <- log1p(Final$min.iCa.24)
hist(log_data,
     main="Natural Log Transformed",
     xlab="log(x+1)",
     col="lightgreen",
     breaks=30)

# Log base 10 transformation
log10_data <- log10(Final$min.iCa.24 + 1)
hist(log10_data,
     main="Log10 Transformed",
     xlab="log10(x+1)",
     col="lightpink",
     breaks=30)

# QQ plot of log-transformed data
qqnorm(log_data)
qqline(log_data, col="red")

library(nortest)
ad.test(log_data)
ad.test(log10_data)