# Data Science Learning Portfolio

This repository collects my end-to-end projects in statistics, data science, machine learning, and data engineering. Each project has its own data, reproducible code, results, and documentation.

## Projects

### [Shanghai GDP forecasting with rolling validation](projects/shanghai-gdp-forecast/)

An R time-series project comparing Drift, Holt exponential smoothing, and ARIMA using expanding-window out-of-sample validation.

- **Language:** R
- **Methods:** time-series exploration, rolling-origin validation, ARIMA, exponential smoothing, residual diagnostics
- **Result:** ARIMA achieved the lowest rolling RMSE and was refitted as ARIMA(1,2,2)
- **Reproducibility:** the complete analysis can be rebuilt with `run_project.R`

[![Rolling-origin model comparison](projects/shanghai-gdp-forecast/outputs/figures/04_rolling_predictions.png)](projects/shanghai-gdp-forecast/)

## Repository structure

```text
projects/
  shanghai-gdp-forecast/   Complete R forecasting project
```

More projects will be added as separate folders using the same reproducible structure.
