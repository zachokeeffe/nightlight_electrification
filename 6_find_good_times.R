# load the following required packages
sapply(c("data.table","bit64"),require,character.only=T)

# get the following variables from the environment
(YYYY<-as.integer(Sys.getenv('YYYY'))) # year
(ctry<-Sys.getenv("ctry")) # country
(wd<-Sys.getenv("wd")) # working directory
# set working directory
setwd(wd)

# open file with VIIRS TIFF time matches
tgzdt<-readRDS('data/VIIRS/VIIRS_tiff_time_lookup.rds')
# keep the month, day, start time, and mean time values
(tgzdt<-tgzdt[,list(YYYYMM,day,stime,meantime)])

# specify stem where extracted data are stored
csvDir<-"/VIIRS/daily/CSVs/"
# specify stem of extracted data
fstem<-"_daily_VIIRS_values_good_resamp_"

# read the country's id-second offset file
(offsetDT<-readRDS(paste0("data/",ctry,"/",ctry,"_id_secOffset.rds")))
# if year was specified
if(!is.na(YYYY)){
  # list the id files corresponding to that year
  rdsfs<-list.files(paste0("data/",ctry,"/VIIRS/daily/CSVs/"),paste0(ctry,"_daily_VIIRS_values_good_resamp_",YYYY,"[0-1][0-9]_id\\.rds"),full.names=F)
# otherwise
} else {
  # list the id files corresponding to all years
  rdsfs<-list.files(paste0("data/",ctry,"/VIIRS/daily/CSVs/"),paste0(ctry,"_daily_VIIRS_values_good_resamp_201[0-9][0-1][0-1][0-9]_id\\.rds"),full.names=F)
}
# get list of months from id files
(YYYYMMs<-sub("(.*?)(201[0-9][0-1][0-9]?)_id\\.rds$","\\2",rdsfs))
# display months
message(paste('YYYYMMs are:',paste(YYYYMMs,collapse=", ")))
# for each month
for(tYYYYMM in YYYYMMs){
  # message which month we're working on
  message(paste("working on ",tYYYYMM))
  # store the id data from that month as a column in a data.table
  dt<-data.table(id=readRDS(paste0("data/",ctry,csvDir,ctry,fstem,tYYYYMM,"_id.rds")))
  # get number of rows of data
  totN<-nrow(dt)
  # create index vector
  set(dt,NULL,'index',1:totN)
  # assign month as column
  set(dt,NULL,'YYYYMM',tYYYYMM)
  # read day in as column
  set(dt,NULL,'day',readRDS(paste0("data/",ctry,csvDir,ctry,fstem,tYYYYMM,"_day.rds")))
  # read start time in as column
  set(dt,NULL,'stime',readRDS(paste0("data/",ctry,csvDir,ctry,fstem,tYYYYMM,"_stime.rds")))
  # merge the data.table with the data containing other time information
  dt<-merge(dt,tgzdt,by=c('YYYYMM','day','stime'))
  # merge data.table with second offset information
  dt<-merge(dt,offsetDT,by='id')
  # stop if any rows were dropped
  stopifnot(nrow(dt)==totN)
  # create the mean time in "local" time by adding the second offset to the value
  set(dt,NULL,'mtimeloc',dt[['meantime']]+dt[['secOffset']])
  # reorder by original index
  setorder(dt,index)
  # save the result
  saveRDS(dt[['mtimeloc']],paste0("data/",ctry,csvDir,ctry,fstem,tYYYYMM,"_mtimeloc.rds"))
  # get the date of the "local" time
  set(dt,NULL,'mdateloc',as.Date(dt[['mtimeloc']]))
  # convert time to datetime
  set(dt,NULL,'mtimelocconst',strftime(dt[['mtimeloc']],format="%H:%M:%S",tz='UTC',usetz=F))
  # reorder by id, then local date, then local time
  setorder(dt,id,mdateloc,mtimelocconst)
  # assign index by each date
  dt[,mdatelocpos:=1:.N,by=c('id','mdateloc')]
  # keep settlement data indices corresponding to the earliest observation that day
  timebadset<-dt[grepl('s',id)&mdatelocpos!=1L][['index']]
  # save result
  saveRDS(timebadset,paste0("data/",ctry,csvDir,ctry,fstem,tYYYYMM,"_timebadset.rds"))
  # do the same but for non-settlement cells
  timebadnset<-dt[grepl('n',id)&mdatelocpos!=1L][['index']]
  saveRDS(timebadnset,paste0("data/",ctry,csvDir,ctry,fstem,tYYYYMM,"_timebadnset.rds"))
  # remove unnecessary and announce we are done for the month
  rm(dt,timebadset,timebadnset,totN);gc()
  message(paste("finished",tYYYYMM))
}
