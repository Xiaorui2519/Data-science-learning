read_gdp_data <- function(path = "data/raw/shanghai_gdp_1969_2018.csv") {
  data <- read.csv(path, stringsAsFactors = FALSE)
  validate_gdp_data(data)

  data$log_gdp <- log(data$gdp)
  data$growth_pct <- c(NA_real_, 100 * diff(data$log_gdp))
  data
}

validate_gdp_data <- function(data) {
  required <- c("year", "gdp")
  missing_columns <- setdiff(required, names(data))
  if (length(missing_columns) > 0L) {
    stop("Missing required columns: ", paste(missing_columns, collapse = ", "))
  }
  if (nrow(data) != 50L) stop("Expected 50 annual observations.")
  if (anyNA(data[required])) stop("Year and GDP must not contain missing values.")
  if (anyDuplicated(data$year)) stop("Year contains duplicates.")
  if (!identical(data$year, 1969:2018)) stop("Years must be continuous from 1969 to 2018.")
  if (any(data$gdp <= 0)) stop("GDP must be positive.")
  invisible(TRUE)
}
