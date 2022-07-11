Timeline of Washington Metrorail stations
========================================================
author: Kevin H(Y) Shu
autosize: true

Obtaining the data
========================================================
- Registration with the WMATA developer API is required here: <https://developer.wmata.com>. Select the default tier. Once the account is confirmed, visit your profile at <https://developer.wmata.com/developer> and obtain the API key from `Primary key`.
- For a list of stations containing the coordinates of and lines served at each station, read the JSON documentation entitled <a href="https://developer.wmata.com/docs/services/5476364f031f590f38092507/operations/5476364f031f5909e4fe3311?">JSON - Station List</a>. I wrote `query_wmata_stations.py` to query the API and assemble the results into `api_stations.csv`.
- For a list of lines with stations in traversal order, read the JSON documentation entitled <a href="https://developer.wmata.com/docs/services/5476364f031f590f38092507/operations/5476364f031f5909e4fe330e?">JSON - Path between Stations</a>. I wrote `query_wmata_lines.py` to query the API and assemble the results into `api_lines_in_travel_order.csv`.
- As the opening dates for each station was not available from the API, I downloaded the table present at <a href="https://en.wikipedia.org/wiki/List_of_Washington_Metro_stations#Stations">Wikipedia's list of stations</a> to `Station opening time list.csv`.

Data preparation
========================================================
- `compile_wmata_stations.R` assumes `query_wmata_stations.py` and `query_wmata_lines.py` have successfully output `api_stations.csv` and `api_lines_in_travel_order.csv`, respectively.
- Broadly, the rest of that script first removes duplicate instances of single-level stations shared by multiple lines that are repeated in `api_stations.csv`. This trimming prevents multliplicity in pinpoint labels.
- It then merges the information contained within `Station opening time list.csv` with the two data frames respectively containing two differing lists of stations; the first not allowing for duplicate instances as mentioned before, the second, extracted from `api_lines_in_travel_order.csv`, listing the stations by the traversal order within each of the 6 lines.
- For the four stations with two levels, the label for `Lines` combines the two levels, listing the line(s) on the upper level on the first line, and the lower level's lines on the second line.

Shiny app design overview
========================================================
- The `ui.R` consists of a slider input that spans the opening of the first stations (the Red Line from Farragut North thru Rhode Island Ave) thru the latest stations (the Silver Line from McLean to Wiehle-Reston East) as well as the leaflet map output. The only "server" calculation involved is the reading of the intermediate `Concise list of stations.csv` to obtain the station opening date range.
- After filtering the stations to those opened on or after the date specified from `sliderInput`, the `server.R`, using the `addMarkers` function, adds markers for each station with an information pop-up that also contains the edited list of lines served at the station, treating the four two-level stations as a single station. Then, `addPolylines` adds line segments between each point in the supplied vector _in the order that the points are specified_. This was why the "Path between Stations" API was both necessary and convenient.

The interactive expression used
========================================================
- The application is located <a href="https://fae-sonata.shinyapps.io/metrorail_stations_timeline-updated/">here</a>
- The source code is located  <a href ="https://github.com/FAE-Sonata/Metrorail_RShiny_Timeline">here</a>
- `concise` is the data frame of stations that were opened on or after the date specified by the slider, and does not contain "duplicates". It provides coordinates and other information for the markers that will be plotted for each station.
- `lines` is the data frame of stations, repeated across lines and listed in traversal order. It is the input to `polyLines` that will draw segments between the station markers.

```r
filteredData <- reactive({
  list(concise=dfConcise %>% filter(Opened <= input$histDate),
       lines=dfLines %>% filter(Opened <= input$histDate)
  )
})

dataSubset<-filteredData()
dfSubset<-dataSubset$concise
dfPartialLines<-dataSubset$lines
```
