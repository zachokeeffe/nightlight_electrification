# load following required packages
sapply(c("data.table","bit64"),require,character.only=T)

# get following variables from environment
(YYYY<-as.integer(Sys.getenv('YYYY'))) # year
(ctry<-Sys.getenv('ctry')) # country
(wd<-Sys.getenv("wd")) # working directory
# set working directory
setwd(wd)

# name of final file to create
(fin_file<-paste0("data/",ctry,"/VIIRS/daily/",ctry,"_good_r9_musd_",YYYY,".rds"))
# get id files corresponding to that year
(rdsfs<-list.files(paste0("data/",ctry,"/VIIRS/daily/CSVs/"),paste0(ctry,"_daily_VIIRS_values_good_resamp_",YYYY,"[0-1][0-9]_id\\.rds"),full.names=F))
# get months of data
(tifmonths<-sub("(.*?)(201[0-9][0-1][0-9]?)_id\\.rds$","\\2",rdsfs))
# say the months
message(paste('TIFF months are:',paste(tifmonths,collapse=", ")))
# if the year is 2012
if(YYYY==2012L){
  # stop if not 9 files
  stopifnot(length(tifmonths)==9L)
} else {
  # stop if not 12 files
  stopifnot(length(tifmonths)==12L)
}
# number of tiffs
ntms<-length(tifmonths)
# empty list for results
fulldt<-vector('list',ntms)
# for each index of tiffs
for(i in 1:ntms){
  # get the month
  m<-tifmonths[i]
  # read in id as column in data.table
  dt<-data.table(id=readRDS(paste0("data/",ctry,"/VIIRS/daily/CSVs/",ctry,"_daily_VIIRS_values_good_resamp_",m,"_id.rds")))
  # read in rade9 as column
  set(dt,NULL,'r9',readRDS(paste0("data/",ctry,"/VIIRS/daily/CSVs/",ctry,"_daily_VIIRS_values_good_resamp_",m,"_rade9.rds")))
  # read in li as column
  set(dt,NULL,'li',readRDS(paste0("data/",ctry,"/VIIRS/daily/CSVs/",ctry,"_daily_VIIRS_values_good_resamp_",m,"_li.rds")))
  # read in index of values to drop based on time
  timebad<-readRDS(paste0("data/",ctry,"/VIIRS/daily/CSVs/",ctry,"_daily_VIIRS_values_good_resamp_",m,"_timebadset.rds"))
  timebadnset<-readRDS(paste0("data/",ctry,"/VIIRS/daily/CSVs/",ctry,"_daily_VIIRS_values_good_resamp_",m,"_timebadnset.rds"))
  # combine the settlement and nonsettlement indices
  timebad<-c(timebad,timebadnset)
  # if there are any values that should be dropped
  if(length(timebad)!=0L){
    # drop them
    dt<-dt[-timebad]
  }
  # remove unnecessary
  rm(timebadnset,timebad);gc()
  # keep data if li is less than .0005
  (dt<-dt[li<.0005,!'li',with=F])
  # assign data to list slot
  fulldt[[i]]<-dt
  # remove
  rm(dt,m);gc()
}
# bind results together in data.table
(fulldt<-rbindlist(fulldt,fill=T))
rm(rdsfs,tifmonths);gc()
# create logged version of rade9 by adding 2.5 and logging
set(fulldt,NULL,'r9l',log(fulldt[['r9']]+2.5))
# this is to ensure no failure in the following
options(datatable.optimize=1)
# create new data.table that contains mean and standard deviation of rade9 and logged rade9 by cell
(fulldt<-fulldt[,list(r9m=mean(r9),r9s=sd(r9),r9lm=mean(r9l),r9ls=sd(r9l)),by='id'])
# save result
saveRDS(fulldt,fin_file)