library(data.table)
library(dplyr)

setwd("C:/HY/Projects/Washington_Metro_leaflet")
# Assumes query_wmata_stations.py has been run, outputting a .CSV file
prep<-function(fn)  {
  stopifnot(grepl("\\.csv$", fn))
  dfFullStation<-read.csv(fn, header=TRUE, stringsAsFactors = FALSE)
  colTypes<-sapply(seq(ncol(dfFullStation)),
                   function(k) typeof(dfFullStation[,k]))
  idxList<-which(colTypes=="list")
  dfFullStation[,idxList]<-gsub("NULL",as.character(NA),
                                sapply(idxList, function(k)
                                  unlist(as.character(dfFullStation[,k]))))
  blankToNA<-function(s)  {
    ifelse(s=="", as.character(NA), s)
  }
  dfFullStation<-dfFullStation %>%
    mutate(LineCode2=blankToNA(LineCode2),
           LineCode3=blankToNA(LineCode3),
           StationTogether1=blankToNA(StationTogether1),
           StationTogether2=blankToNA(StationTogether2))
  
  dfRmDups<-dfFullStation %>%
    as.data.table() %>%
    setkey(Code) %>%
    unique(by="Code") %>%
    as.data.frame()
  dfRmDups<-dfRmDups %>%
    mutate(isUpperLevel=ifelse(is.na(StationTogether1),
                               -1,
                               ifelse(LineCode1=="RD",
                                      TRUE,
                                      ifelse(grepl("Enfant", Name) &
                                               LineCode1 %in% c("GR", "YL"),
                                             TRUE,
                                             FALSE)
                               ) %>% as.integer()
    ))
  return(dfRmDups)
}
dfRmDups<-prep("api_stations.csv")

lookupCode<-function(df, stName, levelCode=-1)  {
  stopifnot(levelCode %in% seq(-1,1))
  dfPossible<-df %>%
    filter(grepl(stName, Name))
  bIncorrect<-(levelCode < 0 & any(dfPossible$isUpperLevel >= 0)) |
    (levelCode >= 0 & any(dfPossible$isUpperLevel < 0))
  stopifnot(!bIncorrect)
  res<-df %>%
    filter(isUpperLevel == levelCode & grepl(stName, Name)) %>%
    select(Code) %>%
    unlist()
  stopifnot(length(res)==1)
  return(res)
}
CODE_NOMA<-dfRmDups %>%
  lookupCode("NoMa")
INFILL_STATIONS<-c(CODE_NOMA,
                   "C11") # Potomac Yard (BL & YL--future);
TERMINUS<-"TERMINUS"
# referenced from https://docs.google.com/spreadsheets/d/13Kz-v3Yjn6ork9vXyl8KLSgzf7KYuGNP9d7HPMd-Kzc/pub?hl=en&single=true&gid=0&output=html

linesByTravelOrder<-read.csv("api_lines_in_travel_order.csv", header=TRUE)

cName<-function(s)  {
  s<-Filter(function(x) !is.na(x), s)
  s<-gsub("(\\*|\\[[a-z]\\])", "", s)
  s<-gsub("\\s*\\(.+\\)", "", s)
  s<-gsub("[^A-z\\s\\']", " ", s)
  s<-gsub("Mount", "Mt", s)
  return(s)
}
cleanName<-Vectorize(cName, vectorize.args = "s")
eFirst<-function(s) {
  words<-s %>%
    cName() %>%
    strsplit(" ") %>%
    unlist()
  return(words[1] %>% trimws())
}
extractFirst<-Vectorize(eFirst, vectorize.args = "s")

processOpenings<-function(fn) {
  stopifnot(grepl("\\.csv$", fn))
  openings<-read.csv(fn, header=T, stringsAsFactors=F)
  
  openings<-openings %>%
    mutate(Station = as.character(Station)) %>%
    mutate(nameCleaned = cleanName(Station),
           Opened=as.Date(Opened, format="%B %d, %Y"),
           boolUpperLevel=ifelse(grepl("level\\s*\\)", Station),
                                 grepl("[Uu]p", Station),
                                 as.logical(NA)))
  openings<-openings[order(openings$nameCleaned,
                           openings$boolUpperLevel),]
  return(openings)
}

augmentStation<-function(dfOpenings, dfStations)  {
  dfStations<-dfStations[order(dfStations$Name,
                               dfStations$isUpperLevel),]
  namesApi<-extractFirst(dfStations$Name)
  namesDL<-extractFirst(dfOpenings$Station)
  sum(namesApi != namesDL)
  
  res<-cbind(dfStations, dfOpenings)
  cleanCols<-function(df) {
    df<-df %>%
      select(-c(Station, boolUpperLevel, nameCleaned))
    idxNonNA<-apply(df, MARGIN=2, FUN = function(x) any(!is.na(x)))
    df<-df %>%
      select(names(df)[idxNonNA]) 
    return(df)
  }
  res<-cleanCols(res)
  res<-res[order(res$Code),]
  res<-res %>%
    select(-c(LineCode1, LineCode2, LineCode3, queriedLine))
  return(res)
}

trimStations<-function(stationsWithOpenings)  {
  dfMultiLevel<-stationsWithOpenings %>%
    filter(isUpperLevel >= 0) %>%
    arrange(Name, isUpperLevel)
  splitMulti<-split(dfMultiLevel, dfMultiLevel$Name)
  consolidateDF<-function(elt)  {
    helper<-function(k) {
      colName<-names(dfMultiLevel)[k]
      if(colName %in% c("Lat", "Lon", "Name", "isUpperLevel",
                        "Lines", "Opened")) {
        if(colName %in% c("Lat", "Lon"))
          return(unique(elt[,k]))
        else if(colName == "Name")  {
          return(unique(elt$Name))
        }
        else if(colName == "isUpperLevel")
          return(-1)
        else if(colName == "Lines") {
          res<-paste("Upper level: ", elt$Lines[2], "<br/>",
                     "Lower level: ", elt$Lines[1],
                     sep="")
          return(res)
        }
        else
          return(min(elt$Opened))
      }
      else
        return(NA)
    }
    partialResults<-lapply(seq(ncol(dfMultiLevel)),
                           helper)
    names(partialResults)<-names(dfMultiLevel)
    return(partialResults %>% as.data.frame)
  }
  dfMultiLevel<-do.call(rbind,
                        lapply(splitMulti, consolidateDF))
  dfSingleLevel<-stationsWithOpenings %>%
    filter(isUpperLevel < 0)
  
  res<-rbind(dfSingleLevel,
                    dfMultiLevel)
  row.names(res)<-NULL
  return(res)
}

augmentLines<-function(stationsWithOpenings, dfLines) {
  res<-left_join(dfLines, stationsWithOpenings, by=c("StationCode"="Code"))
  res<-res[order(res$LineCode,res$SeqNum),]
  return(res)
}

openings<-processOpenings("Station opening time list.csv")
dfStations1<-augmentStation(openings, dfRmDups)

trimmedStations<-trimStations(dfStations1)
joinedLines<-augmentLines(dfStations1, linesByTravelOrder)

# alter Silver Line to 2014 opening
WIEHLE_OPENING<-as.data.frame(openings %>%
  filter(grepl("Wiehle", nameCleaned)))$Opened

silver<-joinedLines %>%
  filter(LineCode == "SV") %>%
  mutate(Opened=WIEHLE_OPENING)
nonSilver<-joinedLines %>% filter(LineCode != "SV")
joinedLines<-rbind(nonSilver, silver)
joinedLines<-joinedLines[order(joinedLines$LineCode, joinedLines$SeqNum),]

write.csv(trimmedStations, "concise_stations.csv", row.names = FALSE)
write.csv(joinedLines, "stations_line_travel_order.csv", row.names = FALSE)