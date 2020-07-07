# rsync -rltgoDuvhh --progress /victor/Work/Brian/current/R_code/FBHRSL/ zokeeffe@flux-xfer.arc-ts.umich.edu:/nfs/brianmin/work/zokeeffe/current/R_code/FBHRSL/

sapply(c("data.table","bit64","stackoverflow"),require,character.only=T)

(ctry<-Sys.getenv("ctry"))
(wd<-Sys.getenv("wd"))
setwd(wd)

rdsDir<-"/VIIRS/daily/CSVs/"
rdsStem<-"_daily_VIIRS_values_good_resamp_"
lithresh<-.001
LCyr<-2012L
maxsampN<-500L
totNmonths<-69L
avgNpmonththresh<-5

# x-y information
xyDT<-readRDS(paste0("data/",ctry,"/",ctry,"_resamp_country_cell_xy_id.rds"))
(matchDT<-xyDT[grep('n',id),list(id)])
# land cover info
(LCDT<-readRDS(paste0('data/',ctry,'/',ctry,'_resamp_country_cell_xy_landcover_values_',LCyr,'.rds')))
(lcs2keep<-sort(intersect(unique(LCDT[grep('s',id)][['lc_type']]),unique(LCDT[grep('n',id)][['lc_type']]))))
(lcs2keep<-lcs2keep[lcs2keep<=16])
(matchDT<-merge(matchDT,LCDT[lc_type%in%lcs2keep],by='id'))
# nearby settlement cells
(setdatDT<-readRDS(paste0('data/',ctry,'/',ctry,'_id_set_stats_15as_cell_dist1.rds')))
(matchDT<-merge(matchDT,setdatDT[edge==F&N_15as_set_dist1==0,list(id)]))
ids2keep<-matchDT[['id']]
rm(setdatDT,LCDT,xyDT);gc()

(rdsfs<-list.files(paste0("data/",ctry,rdsDir),paste0(ctry,"_daily_VIIRS_values_good_resamp_201[2-7][0-1][0-9]_id\\.rds"),full.names=F))
(tifmonths<-sub("(.*?)(201[0-9][0-1][0-9]?)_id\\.rds$","\\2",rdsfs))
(ntifmonths<-length(tifmonths))
stopifnot(ntifmonths==totNmonths)

for(i in 1:ntifmonths){
  # i<-1L
  m<-tifmonths[i]
  dt<-data.table(id=readRDS(paste0("data/",ctry,rdsDir,ctry,rdsStem,m,"_id.rds")))
  set(dt,NULL,'r9',readRDS(paste0("data/",ctry,rdsDir,ctry,rdsStem,m,"_rade9.rds")))
  set(dt,NULL,'li',readRDS(paste0("data/",ctry,rdsDir,ctry,rdsStem,m,"_li.rds")))
  dt<-dt[li<=lithresh,list(id,r9)]
  dt<-dt[id%chin%ids2keep]
  if(i==1L){
    aggdt<-dt[,list(r9sum=sum(r9),N=.N),by='id']
    rm(dt);gc()
  } else {
    dt<-dt[,list(r9sum=sum(r9),N=.N),by='id']
    aggdt<-rbindlist(list(aggdt,dt),fill=T)
    rm(dt);gc()
    aggdt<-aggdt[,list(r9sum=sum(r9sum),N=sum(N)),by='id']
    gc()
  }
  message(paste('finished reading',m))
}

(aggdt<-aggdt[N>1])
set(aggdt,NULL,'r9m',aggdt[['r9sum']]/aggdt[['N']])
set(aggdt,NULL,'r9sum',NULL)
aggdt

saveRDS(aggdt,paste0("data/",ctry,"/VIIRS/daily/",ctry,'_regdat_iso_nsets_muN.rds'))


tmplist<-vector('list',ntifmonths)
ids2keep<-aggdt[['id']]

for(i in 1:ntifmonths){
  # i<-1L
  m<-tifmonths[i]
  dt<-data.table(id=readRDS(paste0("data/",ctry,rdsDir,ctry,rdsStem,m,"_id.rds")))
  set(dt,NULL,'r9',readRDS(paste0("data/",ctry,rdsDir,ctry,rdsStem,m,"_rade9.rds")))
  set(dt,NULL,'li',readRDS(paste0("data/",ctry,rdsDir,ctry,rdsStem,m,"_li.rds")))
  dt<-dt[li<=lithresh,list(id,r9)]
  dt<-merge(dt,aggdt[,list(id,r9m)],by='id')
  set(dt,NULL,'r9s_tmp',(dt[['r9']]-dt[['r9m']])^2)
  dt<-dt[,list(r9s_tmp=sum(r9s_tmp)),by='id']
  tmplist[[i]]<-dt
  rm(dt);gc()
  message(paste('finished reading',m))
}
message('finished reading nonset data')

(tmplist<-rbindlist(tmplist,fill=T))
(tmplist<-tmplist[,list(r9s_tmp=sum(r9s_tmp)),by='id'])

(nsmsDT<-merge(aggdt,tmplist,by='id'))
rm(tmplist,aggdt);gc()
set(nsmsDT,NULL,'r9s',sqrt(nsmsDT[['r9s_tmp']]/(nsmsDT[['N']]-1)))
set(nsmsDT,NULL,'r9s_tmp',NULL)
setcolorder(nsmsDT,c('id','r9m','r9s','N'))
nsmsDT

saveRDS(nsmsDT,paste0("data/",ctry,"/VIIRS/daily/",ctry,'_regdat_iso_nsets_musd.rds'))

(nsmsDT<-na.omit(nsmsDT[N>=(totNmonths*avgNpmonththresh)]))
rm(Nrows);gc()

message('finished summarizing nonset data')

fids2keep<-threshes<-vector('list',length(lcs2keep))
set.seed(48105)
for(i in 1:length(lcs2keep)){
  # i<-1L
  (lctt<-lcs2keep[i])
  tids<-matchDT[lc_type==lctt][['id']]
  # remove if r9s is missing, which is done if N>1. but also in case anything weird happened?
  # also, require that there be on average at least 5 "good" observations per month
  (tnsmsdt<-nsmsDT[id%chin%tids])
  (tmquants<-quantile(tnsmsdt[['r9m']],c(.01,.5)))
  (tmquantdif<-tmquants[[2]]-tmquants[[1]])
  (tmthreshes<-c(tmquants[1L],tmquants[2L]+tmquantdif))
  (tsquants<-quantile(tnsmsdt[['r9s']],c(.01,.5)))
  (tsquantdif<-tsquants[[2]]-tsquants[[1]])
  (tsthreshes<-c(tsquants[1L],tsquants[2L]+tsquantdif))
  threshes[[i]]<-data.table(lc_type=lctt,r9m_lo=tmthreshes[1L],r9m_hi=tmthreshes[2L],r9m_q99=quantile(tnsmsdt[['r9m']],.99),
                            r9s_lo=tsthreshes[1L],r9s_hi=tsthreshes[2L],r9s_q99=quantile(tnsmsdt[['r9s']],.99))
  tids2keep<-tnsmsdt[r9m>tmthreshes[1L]&r9m<tmthreshes[2L]&r9s>tsthreshes[1]&r9s<tsthreshes[2L]][['id']]
  tids2keep<-sample(tids2keep,min(length(tids2keep),maxsampN),replace=F)
  fids2keep[[i]]<-tids2keep
  rm(tids,tnsmsdt,tmquants,tmquantdif,tmthreshes,tsquants,tsquantdif,tsthreshes);gc()
}
rm(nsmsDT);gc()
(threshes<-rbindlist(threshes,fill=T))
saveRDS(threshes,paste0("data/",ctry,"/VIIRS/daily/",ctry,"_iso_nset_reg_match_threshes.rds"))
rm(threshes,lcs2keep);gc()

fids2keep<-unlist(fids2keep)
(fmatchDT<-matchDT[id%chin%fids2keep])
rm(matchDT,fids2keep);gc()
setkey(fmatchDT,id)
saveRDS(fmatchDT,paste0("data/",ctry,"/VIIRS/daily/",ctry,"_iso_nset_reg_match_data.rds"))

message('finished sampling nonset cells')

for(m in tifmonths){
  # m<-tifmonths[1L]
  dt<-data.table(id=readRDS(paste0("data/",ctry,rdsDir,ctry,rdsStem,m,"_id.rds")))
  set(dt,NULL,'r9',readRDS(paste0("data/",ctry,rdsDir,ctry,rdsStem,m,"_rade9.rds")))
  set(dt,NULL,'li',readRDS(paste0("data/",ctry,rdsDir,ctry,rdsStem,m,"_li.rds")))
  set(dt,NULL,'mtimeloc',readRDS(paste0("data/",ctry,rdsDir,ctry,rdsStem,m,"_mtimeloc.rds")))
  setkey(dt,id)
  dt<-dt[fmatchDT]
  dt<-dt[li<=lithresh]
  set(dt,NULL,'lirescale',dt[['li']]/lithresh)
  set(dt,NULL,'li',NULL)
  set(dt,NULL,'locdatechar',strftime(dt[['mtimeloc']],'%Y-%m-%d'))
  set(dt,NULL,'timehour',hour(dt[['mtimeloc']])+minute(dt[['mtimeloc']])/60+second(dt[['mtimeloc']])/3600)
  set(dt,NULL,'mtimeloc',NULL)
  saveRDS(dt,paste0("data/",ctry,"/VIIRS/daily/",ctry,'_regdat_iso_nsets_',m,".rds"))
  rm(dt);gc()
  message(paste('finished',m))
}

