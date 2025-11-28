# WA Snowfall & ENSO Analysis
# Date: 2025-11-26

# 1. Setup & Libraries -------------------------------------------------------
if (!require("pacman")) install.packages("pacman")
pacman::p_load(tidyverse, lubridate, snotelr, janitor, ggthemes, rvest)

# Set global options
options(scipen = 999)
theme_set(theme_minimal())

# 2. Data Acquisition --------------------------------------------------------

# 2.1 Fetch ENSO Data (NOAA ONI)
# Source: https://www.cpc.ncep.noaa.gov/data/indices/oni.ascii.txt
oni_url <- "https://www.cpc.ncep.noaa.gov/data/indices/oni.ascii.txt"
message("Downloading ENSO data from NOAA...")

oni_raw <- read_table(oni_url, col_types = cols())

# Process ONI data
# Format: Year, SEAS, DJF, JFM, ... (Rolling 3-month averages)
# We need to map these to months. The file structure is usually:
#  SEAS YEAR DJF JFM FMA MAM AMJ MJJ JJA JAS ASO SON OND NDJ
oni_data <- oni_raw %>%
    clean_names()

message("ONI Data Columns: ", paste(colnames(oni_data), collapse = ", "))
print(head(oni_data))

oni_data <- oni_data %>%
    rename(year_val = yr) %>% # Rename 'yr' to 'year_val'
    mutate(
        month_num = case_when(
            seas == "DJF" ~ 1, seas == "JFM" ~ 2, seas == "FMA" ~ 3,
            seas == "MAM" ~ 4, seas == "AMJ" ~ 5, seas == "MJJ" ~ 6,
            seas == "JJA" ~ 7, seas == "JAS" ~ 8, seas == "ASO" ~ 9,
            seas == "SON" ~ 10, seas == "OND" ~ 11, seas == "NDJ" ~ 12
        ),
        # Adjust year: DJF is usually assigned to the year of January.
        # In the file, "DJF 1950" usually means Dec 1949 - Feb 1950.
        # We want the date to represent the center month or the start.
        # Let's use the first month of the season for simplicity, or just
        # use month_num. If SEAS=DJF, month_num=1 (Jan).
        # Year is 1950. So Jan 1950.
        date = make_date(year_val, month_num, 1)
    )

# Define Season Year (Year of the January in the season)
# e.g. Nov 1999 is Season 2000.
oni_data <- oni_data %>%
    mutate(
        season_year = if_else(month_num >= 11, year_val + 1, year_val)
    )

# Calculate Seasonal ENSO Strength
# CORRECTED METHODOLOGY: Use DJF (Dec-Jan-Feb) for ENSO classification
enso_seasonal <- oni_data %>%
    filter(month_num %in% c(12, 1, 2)) %>%
    group_by(season_year) %>%
    summarise(mean_anom = mean(anom, na.rm = TRUE)) %>%
    mutate(
        enso_phase = case_when(
            mean_anom >= 1.0 ~ "Strong El Nino",
            mean_anom >= 0.5 ~ "Weak El Nino",
            mean_anom <= -1.0 ~ "Strong La Nina",
            mean_anom <= -0.5 ~ "Weak La Nina",
            TRUE ~ "Neutral"
        )
    )

# 2.2 Fetch SNOTEL Data
# Selected WA Cascade Sites
# 791: Stevens Pass
# 672: Olallie Meadows (Snoqualmie Pass area)
# 679: Paradise (Mt Rainier)
# 909: Wells Creek (Mt Baker area)
site_ids <- c(791, 672, 679, 909)
message(
    "Downloading SNOTEL data for sites: ",
    paste(site_ids, collapse = ", ")
)

snotel_raw <- snotel_download(site_id = site_ids, internal = TRUE)

# 3. Data Processing ---------------------------------------------------------

# Clean and Prepare Snow Data
snow_data <- snotel_raw %>%
    as_tibble() %>%
    select(site_name, date, snow_water_equivalent) %>%
    mutate(
        site_name = str_to_title(site_name), # Capitalize site names
        date = as.Date(date),
        # Convert SWE from mm to inches (snotelr returns mm by default)
        snow_water_equivalent = snow_water_equivalent / 25.4,
        month = month(date),
        year = year(date),
        day = day(date),
        # Define Season Year (Nov 2023 -> 2024)
        season_year = if_else(month >= 11, year + 1, year)
    ) %>%
    # Filter out bad data (negative SWE)
    filter(snow_water_equivalent >= 0)

# Calculate Monthly Means per Season per Site
# CORRECTED METHODOLOGY: Calculate daily diffs BEFORE filtering months
# to avoid treating existing snow on Nov 1 as "new snow".
snow_data_daily_diff <- snow_data %>%
    group_by(site_name) %>% # Group by site only to ensure continuous lag
    arrange(date) %>%
    mutate(
        prev_swe = lag(snow_water_equivalent, default = 0),
        new_swe = pmax(0, snow_water_equivalent - prev_swe)
    ) %>%
    ungroup() %>%
    # Now filter for Snow Season (Nov-Apr)
    filter(month %in% c(11, 12, 1, 2, 3, 4))

# Monthly Totals of New SWE
monthly_snow <- snow_data_daily_diff %>%
    group_by(site_name, season_year, month) %>%
    summarise(
        total_new_swe = sum(new_swe, na.rm = TRUE),
        .groups = "drop"
    )

# Merge with ENSO Data
analysis_data <- monthly_snow %>%
    left_join(enso_seasonal, by = "season_year") %>%
    filter(!is.na(enso_phase))

# Save Data
write_csv(analysis_data, "data/wa_snow_enso_analysis_data.csv")
write_csv(enso_seasonal, "data/enso_classification.csv")

# 4. Visualization -----------------------------------------------------------

# Factor ordering for plots
month_levels <- c(11, 12, 1, 2, 3, 4)
month_labels <- c("Nov", "Dec", "Jan", "Feb", "Mar", "Apr")
enso_levels <- c(
    "Strong La Nina", "Weak La Nina", "Neutral",
    "Weak El Nino", "Strong El Nino"
)
enso_colors <- c(
    "Strong La Nina" = "blue",
    "Weak La Nina" = "lightblue",
    "Neutral" = "thistle", # light purple
    "Weak El Nino" = "lightcoral", # light red
    "Strong El Nino" = "red"
)

analysis_data <- analysis_data %>%
    mutate(
        month_fac = factor(
            month,
            levels = month_levels,
            labels = month_labels
        ),
        enso_fac = factor(enso_phase, levels = enso_levels)
    )

# 4.1 Line Plot: Monthly Comparison
# Average of monthly totals by ENSO phase
monthly_avg_by_phase <- analysis_data %>%
    group_by(site_name, enso_fac, month_fac) %>%
    summarise(
        avg_swe = mean(total_new_swe, na.rm = TRUE),
        .groups = "drop"
    )

p1 <- ggplot(
    monthly_avg_by_phase,
    aes(
        x = month_fac,
        y = avg_swe,
        color = enso_fac,
        group = enso_fac
    )
) +
    geom_line(linewidth = 1.2) +
    geom_point(size = 2) +
    facet_wrap(~site_name, scales = "free_y") +
    scale_color_manual(values = enso_colors) +
    labs(
        title = paste0(
            "Average Monthly New SWE by ENSO Phase (",
            min(analysis_data$season_year),
            "-",
            max(analysis_data$season_year),
            ")"
        ),
        subtitle = "WA Cascades SNOTEL Sites",
        x = "Month",
        y = "Average New SWE (inches)",
        color = "ENSO Phase",
        caption = "Data Sources: NRCS SNOTEL, NOAA CPC"
    ) +
    theme(legend.position = "bottom")

ggsave("plots/monthly_snowfall_enso.png", p1, width = 10, height = 6)

# 4.2 Bar Plot: Percentage Difference from Neutral
# Calculate Neutral Average per Site per Season (Total Season Snow)
seasonal_totals <- analysis_data %>%
    group_by(site_name, season_year, enso_fac) %>%
    summarise(
        season_total_swe = sum(total_new_swe, na.rm = TRUE),
        .groups = "drop"
    )

neutral_avgs <- seasonal_totals %>%
    filter(enso_fac == "Neutral") %>%
    group_by(site_name) %>%
    summarise(
        neutral_mean = mean(season_total_swe, na.rm = TRUE),
        .groups = "drop"
    )

diff_analysis <- seasonal_totals %>%
    group_by(site_name, enso_fac) %>%
    summarise(
        phase_mean = mean(season_total_swe, na.rm = TRUE),
        .groups = "drop"
    ) %>%
    left_join(neutral_avgs, by = "site_name") %>%
    mutate(
        pct_diff = (phase_mean - neutral_mean) / neutral_mean * 100
    ) %>%
    filter(enso_fac != "Neutral") # Remove Neutral (0% diff)

p2 <- ggplot(
    diff_analysis,
    aes(x = site_name, y = pct_diff, fill = enso_fac)
) +
    geom_col(position = "dodge") +
    scale_fill_manual(values = enso_colors) +
    labs(
        title = paste0(
            "Snowfall % Difference from Neutral Years (",
            min(analysis_data$season_year),
            "-",
            max(analysis_data$season_year),
            ")"
        ),
        y = "% Difference in Seasonal SWE",
        x = "Site",
        fill = "ENSO Phase",
        caption = "Data Sources: NRCS SNOTEL, NOAA CPC"
    ) +
    geom_hline(yintercept = 0, linetype = "dashed", color = "gray") +
    theme(legend.position = "bottom")

ggsave("plots/enso_impact_bar_plot.png", p2, width = 10, height = 6)

message("Analysis complete. Plots saved to plots/ folder.")
