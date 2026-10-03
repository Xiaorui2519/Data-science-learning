source("R/load_data.R")
source("R/modeling.R")

dir.create("data/processed", recursive = TRUE, showWarnings = FALSE)
dir.create("outputs/figures", recursive = TRUE, showWarnings = FALSE)
dir.create("outputs/tables", recursive = TRUE, showWarnings = FALSE)

data <- read_gdp_data()
write.csv(data, "data/processed/shanghai_gdp_features.csv", row.names = FALSE)

png("outputs/figures/01_gdp_levels.png", width = 1200, height = 720, res = 120)
plot(data$year, data$gdp, type = "l", lwd = 2, col = "#1F4E79",
     xlab = "Year", ylab = "Nominal GDP (100 million yuan)",
     main = "Shanghai nominal GDP, 1969-2018")
grid(col = "grey85")
dev.off()

png("outputs/figures/02_log_gdp.png", width = 1200, height = 720, res = 120)
plot(data$year, data$log_gdp, type = "l", lwd = 2, col = "#2E7D32",
     xlab = "Year", ylab = "Log nominal GDP",
     main = "Log of Shanghai nominal GDP")
grid(col = "grey85")
dev.off()

png("outputs/figures/03_growth_rate.png", width = 1200, height = 720, res = 120)
plot(data$year, data$growth_pct, type = "h", lwd = 3, col = "#A64B2A",
     xlab = "Year", ylab = "Approximate annual growth (%)",
     main = "Annual log growth of Shanghai nominal GDP")
abline(h = 0, col = "grey40", lty = 2)
grid(col = "grey88")
dev.off()

rolling <- rolling_origin(data, min_train = 25L)
accuracy <- summarise_accuracy(rolling)
write.csv(rolling, "outputs/tables/rolling_predictions.csv", row.names = FALSE)
write.csv(accuracy, "outputs/tables/model_accuracy.csv", row.names = FALSE)

colors <- c(drift = "#6B7280", ets = "#2E7D32", arima = "#B45309")
png("outputs/figures/04_rolling_predictions.png", width = 1300, height = 760, res = 120)
plot(data$year, data$gdp, type = "l", lwd = 3, col = "black",
     xlab = "Forecast year", ylab = "Nominal GDP (100 million yuan)",
     main = "One-step rolling-origin forecasts")
for (model in names(colors)) {
  rows <- rolling[rolling$model == model, ]
  lines(rows$year, rows$predicted, col = colors[model], lwd = 2)
}
legend("topleft", legend = c("Actual", "Drift", "ETS", "ARIMA"),
       col = c("black", colors), lty = 1, lwd = c(3, 2, 2, 2), bty = "n")
grid(col = "grey88")
dev.off()

best_model <- accuracy$model[1L]
final_fit <- fit_final_model(best_model, data$log_gdp)
final_forecast <- forecast_one(best_model, data$log_gdp, h = 3L)
final_forecast$year <- 2019:2021
final_forecast <- final_forecast[c("year", "mean", "lower95", "upper95")]
write.csv(final_forecast, "outputs/tables/final_forecast.csv", row.names = FALSE)

residuals <- as.numeric(stats::na.omit(final_fit$residuals))
lag_for_test <- min(8L, max(1L, floor(length(residuals) / 5L)))
fitdf <- if (best_model == "arima") length(stats::coef(final_fit$fit)) else 0L
fitdf <- min(fitdf, lag_for_test - 1L)
ljung <- stats::Box.test(residuals, lag = lag_for_test, type = "Ljung-Box", fitdf = fitdf)

png("outputs/figures/05_residual_diagnostics.png", width = 1300, height = 680, res = 120)
par(mfrow = c(1, 2))
plot(residuals, type = "l", col = "#1F4E79", lwd = 2,
     xlab = "Residual index", ylab = "Residual", main = paste("Residuals:", final_fit$label))
abline(h = 0, lty = 2, col = "grey50")
stats::acf(residuals, main = "Residual autocorrelation")
par(mfrow = c(1, 1))
dev.off()

png("outputs/figures/06_final_forecast.png", width = 1300, height = 760, res = 120)
plot(c(data$year, final_forecast$year), c(data$gdp, final_forecast$mean),
     type = "n", xlab = "Year", ylab = "Nominal GDP (100 million yuan)",
     main = paste("Three-year forecast using", final_fit$label))
polygon(c(final_forecast$year, rev(final_forecast$year)),
        c(final_forecast$lower95, rev(final_forecast$upper95)),
        col = "#9ECAE180", border = NA)
lines(data$year, data$gdp, lwd = 3, col = "black")
lines(c(tail(data$year, 1L), final_forecast$year),
      c(tail(data$gdp, 1L), final_forecast$mean), lwd = 3, col = "#B45309")
points(final_forecast$year, final_forecast$mean, pch = 19, col = "#B45309")
legend("topleft", legend = c("Observed", "Forecast", "95% interval"),
       col = c("black", "#B45309", "#9ECAE1"), lty = c(1, 1, NA),
       pch = c(NA, 19, 15), lwd = c(3, 3, NA), bty = "n")
grid(col = "grey88")
dev.off()

accuracy_lines <- apply(accuracy, 1, function(row) {
  sprintf("| %s | %s | %.2f | %.2f | %.3f | %.1f%% |",
          row[["model"]], row[["forecasts"]], as.numeric(row[["MAE"]]),
          as.numeric(row[["RMSE"]]), as.numeric(row[["MASE"]]),
          100 * as.numeric(row[["coverage95"]]))
})

forecast_lines <- apply(final_forecast, 1, function(row) {
  sprintf("| %d | %.2f | %.2f | %.2f |", as.integer(row[["year"]]),
          as.numeric(row[["mean"]]), as.numeric(row[["lower95"]]),
          as.numeric(row[["upper95"]]))
})

report <- c(
  "# Shanghai GDP forecasting",
  "",
  "## Research question",
  "",
  "How accurately can simple time-series models forecast Shanghai nominal GDP using only its historical annual values?",
  "",
  "## Data",
  "",
  "The dataset contains 50 annual observations from 1969 through 2018. GDP is recorded in 100 million yuan. The source is the data appendix of the original course paper. The series is treated as nominal GDP, so the results describe monetary scale rather than real economic growth.",
  "",
  "![GDP levels](../outputs/figures/01_gdp_levels.png)",
  "",
  "![Log GDP](../outputs/figures/02_log_gdp.png)",
  "",
  "![Annual growth](../outputs/figures/03_growth_rate.png)",
  "",
  "## Models and validation",
  "",
  "The comparison includes a random walk with drift, Holt exponential smoothing, and an ARIMA model selected by AICc from a small candidate grid. Models are evaluated with expanding-window, one-step-ahead forecasts. The first 25 observations form the initial training window, after which each next year is predicted using only earlier data.",
  "",
  "| Model | Forecasts | MAE | RMSE | MASE | 95% coverage |",
  "|---|---:|---:|---:|---:|---:|",
  accuracy_lines,
  "",
  "![Rolling predictions](../outputs/figures/04_rolling_predictions.png)",
  "",
  paste0("The lowest rolling RMSE is produced by **", best_model, "**. It is refitted on the complete sample for the final three-year demonstration forecast."),
  "",
  "## Diagnostics",
  "",
  sprintf("The final model is %s. The Ljung-Box test uses lag %d and gives p = %.4f.", final_fit$label, lag_for_test, ljung$p.value),
  if (ljung$p.value < 0.05) "The residual white-noise null is rejected, so remaining serial dependence is a limitation." else "The test does not provide sufficient evidence of remaining residual autocorrelation.",
  "",
  "![Residual diagnostics](../outputs/figures/05_residual_diagnostics.png)",
  "",
  "## Demonstration forecast",
  "",
  "| Year | Forecast | Lower 95% | Upper 95% |",
  "|---:|---:|---:|---:|",
  forecast_lines,
  "",
  "![Final forecast](../outputs/figures/06_final_forecast.png)",
  "",
  "## Limitations",
  "",
  "- The data end in 2018 and should not be interpreted as a current forecast.",
  "- Nominal GDP combines real output growth and price changes.",
  "- Annual data provide a small sample and cannot represent short-run economic dynamics.",
  "- Exponentiating log forecasts produces median forecasts on the original scale; no log-normal bias adjustment is applied.",
  "- The models use no external economic information or structural-break variables.",
  "",
  "The forecast is therefore a reproducible model-comparison exercise rather than policy guidance."
)

writeLines(report, "analysis/report.md", useBytes = TRUE)

cat("Project run complete.\n")
cat("Best rolling model:", best_model, "\n")
cat("Final model:", final_fit$label, "\n")
cat("Ljung-Box p-value:", format(ljung$p.value, digits = 4), "\n")
