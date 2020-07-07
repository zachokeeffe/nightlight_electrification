sapply(c("data.table","bit64","parallel","foreach","doMC","lme4"),require,character.only=T)

(ctry<-Sys.getenv("ctry"))
(ncores<-as.integer(Sys.getenv("ncores")))
(wd<-Sys.getenv("wd"))
# ctry<-'Nepal'
# ncores<-12L
# wd<-'/nfs/brianmin/work/zokeeffe/current/'
setwd(wd)
registerDoMC(ncores)

(LCt<-fread('data/LandCover/landcover_classification_modis_composites.csv'))

(rdsDir<-paste0("data/",ctry,"/VIIRS/daily/"))

(nsetfiles<-list.files(rdsDir,paste0(ctry,'_regdat_iso_nsets_20[0-1][0-9][0-1][0-9]\\.rds'),full.names=F))
stopifnot(length(nsetfiles)==69L)

(nsetDT1<-rbindlist(foreach(f=nsetfiles,.inorder=F,.options.multicore=list(preschedule=F))%do%{
  readRDS(paste0(rdsDir,f))
},fill=T))
set(nsetDT1,NULL,'r9l',log(nsetDT1[['r9']]+2.5))
(r9med<-median(nsetDT1[['r9l']]))
(r9sd<-sd(nsetDT1[['r9l']]))
(nsetDT1<-nsetDT1[r9l<=(r9med+4*r9sd),!'r9l',with=F])

lcdates<-unique(nsetDT1[,list(lc_type,locdatechar)])
setorder(lcdates,lc_type,locdatechar)
## removing outliers ##
(nsetDT2<-rbindlist(foreach(r=1:nrow(lcdates),.inorder=F,.options.multicore=list(preschedule=F))%dopar%{
  # r<-1L
  (tdt<-nsetDT1[lc_type==lcdates[r][['lc_type']]&locdatechar==lcdates[r][['locdatechar']]])
  if(nrow(tdt)>=5L){
    r9m<-mean(tdt[['r9']])
    r9s<-sd(tdt[['r9']])
    tdt<-tdt[r9<=(r9m+4*r9s)] # remove if above 4 standard deviations from the mean
  }
  tdt
},fill=T))
rm(nsetDT1);gc()

(LCt2<-LCt[lc_type%in%lcdates[['lc_type']],list(lc_type,label)])
set(LCt2,NULL,'lc_type_fac',factor(LCt2[['lc_type']],levels=LCt2[[1L]],labels=LCt2[[2L]]))
LCt2<-LCt2[,list(lc_type,lc_type_fac)]
saveRDS(LCt2,paste0("data/",ctry,"/VIIRS/daily/",ctry,"_RE_reg_multiyear_dropoutfull_LCdt.rds"))

dateDT<-unique(nsetDT2[,list(locdatechar)])
set(dateDT,NULL,'monthfac',factor(as.integer(substr(dateDT[['locdatechar']],6L,7L)),levels=1:12,labels=month.abb))
saveRDS(dateDT,paste0("data/",ctry,"/VIIRS/daily/",ctry,"_RE_reg_multiyear_monthfac_dateDT.rds"))
##
(nsetDT2<-merge(nsetDT2,LCt2,by='lc_type'))
(nsetDT2<-merge(nsetDT2,dateDT,by='locdatechar'))

(mod<-lmer(r9~lirescale+timehour+monthfac+lc_type_fac+lc_type_fac:lirescale+(1|locdatechar),data=nsetDT2,REML=F))
saveRDS(mod,paste0("data/",ctry,"/VIIRS/daily/",ctry,"_RE_reg_multiyear_mod_final.rds"))
