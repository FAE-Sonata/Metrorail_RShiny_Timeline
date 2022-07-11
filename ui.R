#
# This is the user-interface definition of a Shiny web application. You can
# run the application by clicking 'Run App' above.
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
SYS_OPEN<-min(dfConcise$Opened)
LAST_EXP<-max(dfConcise$Opened)

DOC_TEXT<-paste("Move the slider to the desired date; ",
                "the map will update with the stations that were opened ",
                "after the date specified by the slider. ",
                "Note the map does not account for the initial alignment ",
                "of the Orange Line to National Airport before the opening ",
                "of Ballston station.",
                sep="")

shinyUI(fluidPage(
  sliderInput("histDate", "Date",
              as.Date(paste(format(SYS_OPEN,"%Y"),"-01-01",sep="")),
              as.Date(paste(format(LAST_EXP,"%Y"),"-12-31",sep="")),
              value = as.Date("1976-09-09"), step = 1),
  tabsetPanel(type="tabs",
              tabPanel("Map", br(), leafletOutput("mymap")),
              tabPanel("Documentation", br(), DOC_TEXT)),
  p()
))
