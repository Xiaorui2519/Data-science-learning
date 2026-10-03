aicc <- function(fit, n) {
  k <- length(stats::coef(fit)) + 1L
  value <- stats::AIC(fit)
  if (n <= k + 1L) return(Inf)
  value + (2 * k * (k + 1)) / (n - k - 1)
}

fit_best_arima <- function(log_y, max_p = 2L, max_q = 2L, d_values = 1:2) {
  candidates <- list()
  scores <- numeric()
  labels <- character()

  for (d in d_values) {
    for (p in 0:max_p) {
      for (q in 0:max_q) {
        fit <- tryCatch(
          suppressWarnings(stats::arima(log_y, order = c(p, d, q), method = "ML")),
          error = function(e) NULL
        )
        if (is.null(fit)) next
        score <- aicc(fit, length(log_y))
        if (!is.finite(score)) next
        candidates[[length(candidates) + 1L]] <- fit
        scores <- c(scores, score)
        labels <- c(labels, sprintf("ARIMA(%d,%d,%d)", p, d, q))
      }
    }
  }

  if (length(candidates) == 0L) stop("No ARIMA candidate converged.")
  best <- which.min(scores)
  list(fit = candidates[[best]], label = labels[best], aicc = scores[best])
}

forecast_drift <- function(log_y, h) {
  increments <- diff(log_y)
  drift <- mean(increments)
  horizon <- seq_len(h)
  mean_log <- tail(log_y, 1L) + horizon * drift
  sigma <- stats::sd(increments - drift)
  se <- sigma * sqrt(horizon)
  data.frame(
    mean = exp(mean_log),
    lower95 = exp(mean_log - 1.96 * se),
    upper95 = exp(mean_log + 1.96 * se)
  )
}

forecast_ets <- function(log_y, h) {
  fit <- stats::HoltWinters(log_y, gamma = FALSE)
  pred <- stats::predict(fit, n.ahead = h, prediction.interval = TRUE, level = 0.95)
  data.frame(
    mean = exp(pred[, "fit"]),
    lower95 = exp(pred[, "lwr"]),
    upper95 = exp(pred[, "upr"]),
    row.names = NULL
  )
}

forecast_arima <- function(log_y, h) {
  selected <- fit_best_arima(log_y)
  pred <- stats::predict(selected$fit, n.ahead = h)
  data.frame(
    mean = exp(as.numeric(pred$pred)),
    lower95 = exp(as.numeric(pred$pred) - 1.96 * as.numeric(pred$se)),
    upper95 = exp(as.numeric(pred$pred) + 1.96 * as.numeric(pred$se)),
    row.names = NULL
  )
}

forecast_one <- function(model, log_y, h = 1L) {
  switch(
    model,
    drift = forecast_drift(log_y, h),
    ets = forecast_ets(log_y, h),
    arima = forecast_arima(log_y, h),
    stop("Unknown model: ", model)
  )
}

rolling_origin <- function(data, min_train = 25L, models = c("drift", "ets", "arima")) {
  results <- list()
  index <- 1L

  for (end in min_train:(nrow(data) - 1L)) {
    train <- data[seq_len(end), ]
    actual <- data$gdp[end + 1L]
    forecast_year <- data$year[end + 1L]

    for (model in models) {
      prediction <- tryCatch(
        forecast_one(model, train$log_gdp, h = 1L),
        error = function(e) NULL
      )
      if (is.null(prediction)) next
      results[[index]] <- data.frame(
        model = model,
        year = forecast_year,
        actual = actual,
        predicted = prediction$mean[1L],
        lower95 = prediction$lower95[1L],
        upper95 = prediction$upper95[1L]
      )
      index <- index + 1L
    }
  }

  do.call(rbind, results)
}

summarise_accuracy <- function(rolling) {
  naive_scale <- mean(abs(diff(rolling$actual[rolling$model == "drift"])))
  split_rows <- split(rolling, rolling$model)
  summaries <- lapply(split_rows, function(x) {
    error <- x$predicted - x$actual
    data.frame(
      model = x$model[1L],
      forecasts = nrow(x),
      MAE = mean(abs(error)),
      RMSE = sqrt(mean(error^2)),
      MASE = mean(abs(error)) / naive_scale,
      coverage95 = mean(x$actual >= x$lower95 & x$actual <= x$upper95)
    )
  })
  result <- do.call(rbind, summaries)
  result[order(result$RMSE), ]
}

fit_final_model <- function(model, log_y) {
  switch(
    model,
    drift = list(
      label = "Random walk with drift",
      residuals = diff(log_y) - mean(diff(log_y))
    ),
    ets = {
      fit <- stats::HoltWinters(log_y, gamma = FALSE)
      list(label = "Holt exponential smoothing", fit = fit, residuals = stats::residuals(fit))
    },
    arima = {
      selected <- fit_best_arima(log_y)
      list(label = selected$label, fit = selected$fit, residuals = stats::residuals(selected$fit))
    }
  )
}
