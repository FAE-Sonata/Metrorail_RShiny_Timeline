libraries_needed<-c("data.table", "dplyr", "lubridate", "stringr")
lapply(libraries_needed,require,character.only=T); rm(libraries_needed)

setwd("C:/HY/Projects/Coursera/Metrorail_Timeline")
#' File preparation
#'
#' Remove "duplicate" stations (i.e. transfer stations listed more than once)
#' Set additional column to indicate -1 for stations that are NOT multi-level
#' 0 for the lower-level set of lines in multi-level stations
#' 1 for the upper-level line(s) in multi-level stations
#' @param fn filename of CSV output from query_wmata_stations.py
#'
#' @return Data Table with the above characteristics
prep<-function(fn)  {
  stopifnot(grepl("\\.csv$", fn))
  full_station<-fread(fn, header=T, stringsAsFactors = F)
  ## from https://stackoverflow.com/a/31517384 ##
  ch_idx<-which(sapply(full_station, is.character))
  for (j in ch_idx) set(full_station,
                        i = grep("^$|^ $", full_station[[j]]),
                        j = j,
                        value = NA_character_)
  setkey(full_station, "Code")
  res<-unique(full_station, by="Code")
  res[,isUpperLevel:=ifelse(is.na(StationTogether1),
                            -1,
                            ifelse(LineCode1=="RD",
                                   T,
                                   grepl("Enfant", Name) & LineCode1 %in% c(
                                     "GR", "YL")) %>% as.integer
  )]
  return(res)
}
rm_dups<-prep("api_stations.csv")

lookup_code<-function(dt, st_name, level_code=-1)  {
  stopifnot(level_code %in% seq(-1,1))
  dt_possible<-dt[grepl(st_name, Name),]
  is_mismatch<-(level_code < 0 & any(dt_possible$isUpperLevel >= 0)) |
    (level_code >= 0 & any(dt_possible$isUpperLevel < 0))
  stopifnot(!is_mismatch)
  res<-dt[isUpperLevel == level_code & grepl(st_name, Name),.(Code)] %>%
    unlist
  stopifnot(length(res)==1)
  return(res)
}
CODE_NOMA<-lookup_code(rm_dups, "NoMa")
INFILL_STATIONS<-c(CODE_NOMA,
                   "C11") # Potomac Yard (BL & YL--future);
TERMINUS<-"TERMINUS"

lines_travel_order<-fread("api_lines_in_travel_order.csv", header=T)

clean_name<-function(s)  {
  s<-s %>%
    str_replace("\\s*\\((upp|low)er\\)", replacement="") %>%
    str_replace("Mount", "Mt")
  return(s)
}
e_first<-function(s) {
  words<-s %>%
    str_replace_all("[^(\\sA-z')]", " ") %>%
    str_split(" ") %>%
    unlist
  return(ifelse(length(words) == 1,
                trimws(words[1]),
                str_c(sapply(seq(2), function(k) trimws(words[k])),
                      collapse=" ")))
}
extract_first<-Vectorize(e_first, vectorize.args = "s")

process_openings<-function(fn) {
  stopifnot(grepl("\\.csv$", fn))
  dt_openings<-fread(fn, header=T, stringsAsFactors=F)
  
  dt_openings<-dt_openings[
    ,`:=`(station_cleaned=clean_name(station),
          opening_ymd=mdy(opening),
          boolUpperLevel=ifelse(grepl("\\((upp|low)er\\)", station),
                                grepl("[Uu]p", station),
                                as.logical(NA)))
  ]
  iad_name<-Filter(function(x) grepl("Dulles",x), dt_openings$station_cleaned)
  stopifnot(length(iad_name)==1)
  if(grepl("^Dulles", iad_name))
    dt_openings[station_cleaned==iad_name, station_cleaned:=paste(
      "Washington", iad_name)]
  setorder(dt_openings, station_cleaned, boolUpperLevel)
  res<-dt_openings[,.(station_cleaned, lines, opening_ymd, boolUpperLevel)]
  names(res)<-c("station", "lines", "opening", "boolUpperLevel")
  return(res)
}

compare_unequal<-function(longer, shorter) {
  return(str_sub(longer, end=nchar(shorter)) == shorter)
}

join_station_versions<-function(dt_openings, dt_stations)  {
  setorder(dt_stations, Name, isUpperLevel)
  RE_RD<-"\\s+Rd"
  names_api<-extract_first(dt_stations$Name) %>% trimws
  names_scrape<-extract_first(dt_openings$station) %>% trimws
  names(names_api)<-NULL; names(names_scrape)<-NULL
  stopifnot(sum(grepl("\\s+Rd", names_api, ignore.case = T)) +
              sum(grepl("\\s+Rd", names_scrape, ignore.case = T)) == 0)
  is_equal<-sapply(seq(length(names_api)), function(k) {
    if(names_api[k] == names_scrape[k]) return(T)
    api_len<-str_split(names_api[k], " ") %>% unlist %>% length
    scrape_len<-str_split(names_scrape[k], " ") %>% unlist %>% length
    return(ifelse(api_len > scrape_len,
                  compare_unequal(names_api[k], names_scrape[k]),
                  compare_unequal(names_scrape[k], names_api[k])
    )
    )
  })
  stopifnot(all(is_equal))
  
  res<-cbind(dt_stations, dt_openings)
  keep_cols<-Filter(function(x) !(x %in% c("station", "boolUpperLevel")),
                    names(res))
  res<-res[,.SD,.SDcols=keep_cols]
  idx_non_na<-apply(res, MARGIN=2, FUN = function(x) any(!is.na(x)))
  non_na_cols<-names(res)[which(idx_non_na)]
  res<-res[,.SD,.SDcols=non_na_cols]
  setorder(res, Code)
  return(res)
}

trim_stations<-function(stations_with_openings)  {
  original_names<-names(stations_with_openings)
  single_level<-stations_with_openings[isUpperLevel < 0,]
  multi_level<-stations_with_openings[isUpperLevel >= 0,]
  setorder(multi_level, Name, isUpperLevel)
  retained_names<-c("Lat", "Lon", "Name", "isUpperLevel", "lines", "opening")
  na_cols<-setdiff(original_names, retained_names)
  # set un-needed columns in this version to NA
  multi_level[,(na_cols):=lapply(.SD, function(x) NA),.SDcols=na_cols]
  multi_level<-multi_level[,`:=`(isUpperLevel=-1,
                                 lines=paste0("Upper level: ", lines[2],
                                              " (opened ", opening[2],")",
                                              "<br/>",
                                              "Lower level: ", lines[1],
                                              " (opened ", opening[1],")"))
                           ,by=Name][
                             ,opening:=min(opening)
                             ,by=Name
                           ]
  multi_level<-unique(multi_level, by="Name")
  res<-rbindlist(list(single_level, multi_level))
  return(res)
}

augment_lines<-function(stations_with_openings, dt_lines) {
  setkey(dt_lines, "StationCode"); setkey(stations_with_openings, "Code")
  res<-left_join(dt_lines, stations_with_openings, by=c("StationCode"="Code"))
  setorder(res, LineCode, SeqNum)
  return(res)
}

openings<-process_openings("station_opening_dates_scraped.csv")
joined_stations<-join_station_versions(openings, rm_dups)

trimmed_stations<-trim_stations(joined_stations)
joined_lines<-augment_lines(joined_stations, lines_travel_order)

# alter Silver Line (Largo to Wiehle) to 2014 opening
dt_wiehle<-openings[grepl("Wiehle", station),.(opening)]
WIEHLE_OPENING<-dt_wiehle$opening[1]

joined_lines<-joined_lines[LineCode == "SV" & year(opening) <= year(WIEHLE_OPENING),
                           opening:=WIEHLE_OPENING]
setorder(joined_lines, LineCode, SeqNum)

fwrite(trimmed_stations, "concise_stations.csv", row.names = F)
fwrite(joined_lines, "stations_line_travel_order.csv", row.names = F)