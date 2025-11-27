[ Antigravity prompt settings: ^Planning ^Gemini 3 Pro (High) ]

Write an R script which reproduces the following analysis, including generation of all plots, as well as the web scraping steps needed to download and import real data from respected sources. Use pacman::p_load() for loading R packages. Produce an implementation plan in Markdown, write the code, then test and debug. Plots should show the data year range in the title and data source in the caption. The full path to Rscript.exe is: "/usr/local/bin/Rscript". Save data as CSV files in "data" folder and plots as PNG files in "plots" folder. Make sure to line-wrap the R code so that lines are <= 80 characters long. Indent and space the code according to common best practice style for R.

- Science question:
  - How do El Niño & La Niña climate patterns relate to snowfall in WA Cascades?
- Create a line plot comparing snowfall during El Niño and La Niña years for WA Cascade sites (mountain passes, resorts, or other notable locations), by site and month.
  - For the measure of snowfall, use Snow Water Equivalent (SWE).
  - And for monthly comparisons, use the average of new snowfall for each month, not cumulative snowfall, total snowfall, or snow depth.
  - Also, consider a snow season as starting in Nov. and ending in     April of the next year.
  - When plotting by month, order the months as: Nov, Dec, Jan, Feb, Mar, Apr.
  - In ggplot(), in geom_line() and geom_point(), use linewidth for the line plot instead of size to avoid the warning about deprecated syntax.
- Compare snowfall in strong vs weak intensities for both La Niña and El Niño years and show percentage snowfall difference from neutral years by site in a new bar plot.
- When plotting, capitalize the site names to match nomral capitalization for place name (not all caps).
- When plotting, use these climate patterns (and colors), in order
  - Strong La Nina (blue), Weak La Nina (light blue), Neutral (light purple),
    Weak El Nino (light red), Strong El Nino (red)
- Save the Walkthough.md as README.md in Markdown format.
