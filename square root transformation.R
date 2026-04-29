par(mfrow=c(2,2))

# Original count data
hist(Final$min.iCa.24,
     main="Original Count Data",
     xlab="Value",
     col="lightblue",
     breaks=30)

# Square root transformation
sqrt_data <- sqrt(Final$min.iCa.24)
hist(sqrt_data,
     main="Square Root Transformed",
     xlab="sqrt(x)",
     col="lightgreen",
     breaks=30)

# Compare distributions
boxplot(Final$min.iCa.24, sqrt_data,
        names=c("Original", "Square Root"),
        main="Distribution Comparison")

# QQ plot of sqrt-transformed data
qqnorm(sqrt_data)
qqline(sqrt_data, col="red")

library(nortest)
ad.test(sqrt_data)