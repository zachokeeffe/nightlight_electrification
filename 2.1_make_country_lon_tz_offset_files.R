# load the following packages
sapply(c("data.table","bit64"),require,character.only=T)

# get the following variables from the environment
(ctry<-Sys.getenv("ctry")) # country
(wd<-Sys.getenv("wd")) # working directory
# set working directory
setwd(wd)

# read in data.table of 15as cells
xyDT<-readRDS(paste0("data/",ctry,"/",ctry,"_resamp_country_cell_xy_id.rds"))
# keep ID and x value
(xyDT<-xyDT[,list(id,x)])
# create time offset by multiplying x value by 240
set(xyDT,NULL,'secOffset',xyDT[['x']]*240)

# save as RDS
saveRDS(xyDT[,list(id,secOffset)],paste0("data/",ctry,"/",ctry,"_id_secOffset.rds"))