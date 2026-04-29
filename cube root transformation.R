par(mfrow=c(2,2))

# Original data with negative values
hist(Final$min.iCa.24,
     main="Original Data (with negatives)",
     xlab="Value",
     col="lightblue",
     breaks=30)

# Cube root transformation
cbrt_data <- sign(Final$min.iCa.24) * abs(Final$min.iCa.24) ^ (1/3)
hist(cbrt_data,
     main="Cube Root Transformed",
     xlab="cbrt(x)",
     col="lightgreen",
     breaks=30)

# Density plots comparison
plot(density(Final$min.iCa.24),
     main="Density Plot Comparison",
     xlab="Value")
lines(density(cbrt_data), col="red")
legend("topright", 
       legend=c("Original", "Cube Root"),
       col=c("black", "red"),
       lty=1)

# QQ plot of cube root-transformed data
qqnorm(cbrt_data)
qqline(cbrt_data, col="red")

library(nortest)
ad.test(cbrt_data)