# rsync -rltgoDuvhh --progress /victor/Work/Brian/current/R_code/FBHRSL/ zokeeffe@flux-xfer.arc-ts.umich.edu:/nfs/brianmin/work/zokeeffe/current/R_code/FBHRSL/
sapply(c("data.table","bit64"),require,character.only=T)

(ctry<-Sys.getenv("ctry"))
(wd<-Sys.getenv("wd"))
# ctry<-'Nepal'
# wd<-'/nfs/brianmin/work/zokeeffe/current/'
setwd(wd)

rdsDir<-"/VIIRS/daily/CSVs/"
rdsStem<-"_daily_VIIRS_values_good_resamp_"
lithresh<-.001
LCyr<-2012L

### CONSTANT INFO ###
# x-y information
xyDT<-readRDS(paste0("data/",ctry,"/",ctry,"_resamp_country_cell_xy_id.rds"))
if(ctry=='Rwanda'){
  cellsinctry<-readRDS('data/Rwanda/Rwanda_resamp_set_cells_in_country.rds')
  (xyDT<-xyDT[!(grepl('s',id)&!(cell_resamp%in%cellsinctry))])
}
(matchDT<-xyDT[grep('s',id),list(id)])

# land cover info
(LCDT<-readRDS(paste0('data/',ctry,'/',ctry,'_resamp_country_cell_xy_landcover_values_',LCyr,'.rds')))
(lcs2keep<-sort(intersect(unique(LCDT[grep('s',id)][['lc_type']]),unique(LCDT[grep('n',id)][['lc_type']]))))
(lcs2keep<-lcs2keep[lcs2keep<=16])
(matchDT<-merge(matchDT,LCDT[lc_type%in%lcs2keep],by='id'))
setkey(matchDT,id)
rm(xyDT,LCDT);gc()

(rdsfs<-list.files(paste0("data/",ctry,rdsDir),paste0(ctry,"_daily_VIIRS_values_good_resamp_201[2-7][0-1][0-9]_id\\.rds"),full.names=F))
(tifmonths<-sub("(.*?)(201[0-9][0-1][0-9]?)_id\\.rds$","\\2",rdsfs))
stopifnot(length(tifmonths)==69L)
for(m in tifmonths){
  # m<-tifmonths[1L]
  dt<-data.table(id=readRDS(paste0("data/",ctry,rdsDir,ctry,rdsStem,m,"_id.rds")))
  set(dt,NULL,'r9',readRDS(paste0("data/",ctry,rdsDir,ctry,rdsStem,m,"_rade9.rds")))
  set(dt,NULL,'li',readRDS(paste0("data/",ctry,rdsDir,ctry,rdsStem,m,"_li.rds")))
  set(dt,NULL,'mtimeloc',readRDS(paste0("data/",ctry,rdsDir,ctry,rdsStem,m,"_mtimeloc.rds")))
  timebad<-readRDS(paste0("data/",ctry,rdsDir,ctry,rdsStem,m,"_timebadset.rds"))
  if(length(timebad)!=0L){
    dt<-dt[-timebad]
  }
  setkey(dt,id)
  dt<-dt[matchDT]
  dt<-dt[li<=lithresh]
  set(dt,NULL,'lirescale',dt[['li']]/lithresh)
  set(dt,NULL,'li',NULL)
  set(dt,NULL,'locdatechar',strftime(dt[['mtimeloc']],'%Y-%m-%d'))
  set(dt,NULL,'timehour',hour(dt[['mtimeloc']])+minute(dt[['mtimeloc']])/60+second(dt[['mtimeloc']])/3600)
  set(dt,NULL,'mtimeloc',NULL)
  saveRDS(dt,paste0("data/",ctry,"/VIIRS/daily/",ctry,'_regdat_sets_',m,".rds"))
  rm(dt);gc()
  message(paste('finished',m))
}
rm(matchDT);gc()
