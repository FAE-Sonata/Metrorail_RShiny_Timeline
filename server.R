#
# This is the server logic of a Shiny web application. You can run the 
# application by clicking 'Run App' above.
#
# Find out more about building applications with Shiny here:
# 
#    http://shiny.rstudio.com/
#

library(dplyr)
library(shiny)
library(leaflet)

# dir<-"C:/HY/Projects/Washington_Metro_leaflet"
# dfConcise<-read.csv(paste(dir, "Concise_stations.csv", sep="/"),
#                     stringsAsFactors = FALSE)
dfConcise<-read.csv("concise_stations.csv", stringsAsFactors = FALSE)
dfConcise<-dfConcise %>% mutate(Opened = as.Date(Opened))

# dfLines<-read.csv(paste(dir, "Stations_line_travel_order.csv", sep="/"),
#                   stringsAsFactors = FALSE)
dfLines<-read.csv("stations_line_travel_order.csv", stringsAsFactors = FALSE)
superBounds<-function(x)  {
  ORDERS_MAG<-2
  stopifnot(ORDERS_MAG %% 1 == 0)
  res<-c((floor(10^ORDERS_MAG * min(x))-1)/10^ORDERS_MAG,
         (ceiling(10^ORDERS_MAG * max(x))+1)/10^ORDERS_MAG)
  return(res)
}

getLat<-function(df, lineName)  {
  stopifnot(lineName %in% unique(dfLines$LineCode))
  return(df %>%
           filter(LineCode ==lineName) %>%
           select(Lat) %>%
           unlist())
}

getLon<-function(df, lineName)  {
  stopifnot(lineName %in% unique(dfLines$LineCode))
  return(df %>%
           filter(LineCode ==lineName) %>%
           select(Lon) %>%
           unlist())
}

shinyServer(function(input, output, session) {
  output$mymap <- renderLeaflet({
    filteredData <- reactive({
      list(concise=dfConcise %>% filter(Opened <= input$histDate),
           lines=dfLines %>% filter(Opened <= input$histDate)
      )
    })
    
    nominalDim<-c(512,655)
    nominalFactor<-nominalDim[1]/nominalDim[2]
    ht<-10
    metrorailIcon <- makeIcon(
      iconUrl = "https://upload.wikimedia.org/wikipedia/commons/1/1e/WMATA_Metro_Logo.svg",
      iconWidth = ht*nominalFactor, iconHeight = ht,
      iconAnchorX = ht*nominalFactor/2, iconAnchorY = 16
    )
    
    dataSubset<-filteredData()
    dfSubset<-dataSubset$concise
    dfPartialLines<-dataSubset$lines
    
    thisMap<-leaflet(dfSubset) %>%
      addTiles() %>%
      fitBounds(superBounds(dfConcise$Lon)[1], superBounds(dfConcise$Lat)[1],
                superBounds(dfConcise$Lon)[2], superBounds(dfConcise$Lat)[2]) %>%
      clearMarkers() %>%
      clearShapes() %>%
      addMarkers(lat = dfSubset$Lat,
                 lng = dfSubset$Lon,
                 # popup=dfSubset$Name,
                 popup=paste("Name: ", dfSubset$Name, "<br/>",
                             "Opened: ", dfSubset$Opened, "<br/>",
                             "Serves: <br/>", dfSubset$Lines,
                             "<br/> Coordinates: (", dfSubset$Lat,
                             ", ", dfSubset$Lon, ")", 
                             sep=""),
                 #     "Opened date: "),
                 icon=metrorailIcon) %>%
      addPolylines(lng=getLon(dfPartialLines, "RD"),
                   lat=getLat(dfPartialLines, "RD"),
                   color = "Red") %>%
      addPolylines(lng=getLon(dfPartialLines, "OR"),
                   lat=getLat(dfPartialLines, "OR"),
                   color = "Orange") %>%
      addPolylines(lng=getLon(dfPartialLines, "SV"),
                   lat=getLat(dfPartialLines, "SV"),
                   color = "Silver", opacity=1) %>%
      addPolylines(lng=getLon(dfPartialLines, "YL"),
                   lat=getLat(dfPartialLines, "YL"),
                   color = "Yellow") %>%
      addPolylines(lng=getLon(dfPartialLines, "BL"),
                   lat=getLat(dfPartialLines, "BL"),
                   color = "Blue", opacity=0.3) %>%
      addPolylines(lng=getLon(dfPartialLines, "GR"),
                   lat=getLat(dfPartialLines, "GR"),
                   color = "Green")
  }
  )
})