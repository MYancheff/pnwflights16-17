# From https://mesonet.agron.iastate.edu/request/download.phtml?network=NY_ASOS

library(httr)
library(dplyr)
library(lubridate)
library(readr)

# Download ---------------------------------------------------------------------

get_asos <- function(station) {
  url <- "https://mesonet.agron.iastate.edu/cgi-bin/request/asos.py?"
  query <- list(
    station = station, data = "all",
    year1 = "2016", month1 = "8", day1 = "1",
    year2 = "2017", month2 = "7", day2 = "31", tz = "UTC",
    format = "comma", latlon = "no", direct = "yes")

  dir.create("data-raw/weather", showWarnings = FALSE, recursive = TRUE)
  r <- GET(url, query = query, write_disk(paste0("./data-raw/weather/", station, ".csv")))
  stop_for_status(r)

}


stations <- c("PDX", "SEA")
paths <- paste0(stations, ".csv")
missing <- stations[!(paths %in% dir("data-raw/weather/"))]
lapply(missing, get_asos)


# Load ------------------------------------------------------------------------

paths <- dir("data-raw/weather/", full.names = TRUE)
all <- lapply(paths, read.csv, skip = 6, row.names = NULL, check.names = FALSE,
  header = FALSE, stringsAsFactors = FALSE, na.strings = "M")

raw <- bind_rows(all)
names(raw) <- c("station", "time", "tmpf", "dwpf", "relh", "drct", "sknt",
  "p01i", "alti", "mslp", "vsby", "gust", "skyc1", "skyc2", "skyc3", "skyc4",
  "skyl1", "skyl2", "skyl3", "skyl4", "presentweathercode", "metar")

weather <- raw %>%
  select(
    station, time, temp = tmpf, dewp = dwpf, humid = relh,
    wind_dir = drct, wind_speed = sknt, wind_gust = gust,
    precip = p01i, pressure = mslp, visib = vsby
  ) %>%
  mutate(
    time = as.POSIXct(strptime(time, "%Y-%m-%d %H:%M")),
    wind_speed = as.numeric(wind_speed) * 1.15078, # convert to mpg
    wind_gust = as.numeric(wind_speed) * 1.15078
  ) %>%
  mutate(year = year(time), month = month(time), day = mday(time), hour = hour(time)) %>%
  group_by(station, month, day, hour) %>%
  filter(row_number() == 1) %>%
  select(origin = station, year:hour, temp:visib) %>%
  ungroup() %>%
  filter(!is.na(month)) %>%
  mutate(
    date = ISOdatetime(year, month, day, hour, 0, 0)
  )

save(weather, file = "data/weather.rda")

# Save to RDS file
saveRDS(weather, "data/weather.RDS")

# Export to CSV
write.csv(weather, "data/weather.csv", row.names = FALSE)
