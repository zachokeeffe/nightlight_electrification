# rsync -rltgoDuvhh --progress /victor/Work/Brian/current/R_code/FBHRSL/ zokeeffe@flux-xfer.arc-ts.umich.edu:/nfs/brianmin/work/zokeeffe/current/R_code/FBHRSL/

# export wd=/nfs/brianmin/work/zokeeffe/current/; export ctry=Brunei; R

sapply(c("data.table","bit64","foreach","doMC","stackoverflow"),require,character.only=T)

options(datatable.optimize=1)

(ctry<-Sys.getenv("ctry"))
(ncores<-as.integer(Sys.getenv("ncores")))
(wd<-Sys.getenv("wd"))
# ctry<-'Nepal'
# ncores<-12L
# wd<-'/nfs/brianmin/work/zokeeffe/current/'
setwd(wd)

registerDoMC(ncores)

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
(matchDT<-merge(matchDT,setdatDT[edge==F&N_15as_set_dist1==0,list(id)],by='id'))
ids2keep<-matchDT[['id']]
rm(setdatDT,LCDT,xyDT);gc()

(rdsfs<-list.files(paste0("data/",ctry,rdsDir),paste0(ctry,"_daily_VIIRS_values_good_resamp_201[2-7][0-1][0-9]_id\\.rds"),full.names=F))
(tifmonths<-sub("(.*?)(201[0-9][0-1][0-9]?)_id\\.rds$","\\2",rdsfs))
(ntifmonths<-length(tifmonths))
stopifnot(ntifmonths==69L)

nsmsDT<-vector('list',69L)
for(i in 1:ntifmonths){
  m<-tifmonths[i]
  dt<-data.table(id=readRDS(paste0("data/",ctry,rdsDir,ctry,rdsStem,m,"_id.rds")))
  set(dt,NULL,'r9',readRDS(paste0("data/",ctry,rdsDir,ctry,rdsStem,m,"_rade9.rds")))
  set(dt,NULL,'li',readRDS(paste0("data/",ctry,rdsDir,ctry,rdsStem,m,"_li.rds")))
  dt<-dt[li<=lithresh,list(id,r9)]
  dt<-dt[id%chin%ids2keep]
  nsmsDT[[i]]<-dt
}
# nsmsDT<-foreach(m=tifmonths,.inorder=F,.options.multicore=list(preschedule=F))%dopar%{
  # dt<-data.table(id=readRDS(paste0("data/",ctry,rdsDir,ctry,rdsStem,m,"_id.rds")))
  # set(dt,NULL,'r9',readRDS(paste0("data/",ctry,rdsDir,ctry,rdsStem,m,"_rade9.rds")))
  # set(dt,NULL,'li',readRDS(paste0("data/",ctry,rdsDir,ctry,rdsStem,m,"_li.rds")))
  # dt<-dt[li<=lithresh,list(id,r9)]
  # dt<-dt[id%chin%ids2keep]
  # return(dt)
# }
gc()
# get total number of rows in case too large
(Nrows<-sum(as.numeric(unlist(lapply(nsmsDT,nrow)))))
if(Nrows>.Machine$integer.max){
  (Nsplits<-ceiling(Nrows/.Machine$integer.max))
  idchunks<-chunk2(ids2keep,Nsplits)
  nsmsDT2<-vector('list',Nsplits)
  for(chun in 1:Nsplits){
    message(paste('working on',chun))
    tmpDT<-rbindlist(lapply(nsmsDT,function(xx) xx[id%chin%idchunks[[chun]]]),fill=T)
    tmpDT<-tmpDT[,list(r9m=mean(r9),r9s=sd(r9),N=.N),by='id']
    nsmsDT2[[chun]]<-tmpDT
    rm(tmpDT);gc()
  }
  nsmsDT<-rbindlist(nsmsDT2,fill=T)
  rm(ids2keep,idchunks,Nsplits,nsmsDT2);gc()
} else {
  (nsmsDT<-rbindlist(nsmsDT,fill=T))
  rm(ids2keep);gc()
  (nsmsDT<-nsmsDT[,list(r9m=mean(r9),r9s=sd(r9),N=.N),by='id'])
}
saveRDS(nsmsDT,paste0("data/",ctry,"/VIIRS/daily/",ctry,'_regdat_iso_nsets_musd.rds'))

(nsmsDT<-na.omit(nsmsDT[N>=(totNmonths*avgNpmonththresh)]))
gc()

set.seed(48105)
tmplist<-foreach(i=1:length(lcs2keep),.inorder=F,.options.multicore=list(preschedule=F,mc.set.seed=F))%dopar%{
  # i<-8L
  (lctt<-lcs2keep[i])
  tids<-matchDT[lc_type==lctt][['id']]
  (tnsmsdt<-nsmsDT[id%chin%tids])
  (tmquants<-quantile(tnsmsdt[['r9m']],c(.01,.5),na.rm=T))
  (tmquantdif<-tmquants[[2]]-tmquants[[1]])
  (tmthreshes<-c(tmquants[1L],tmquants[2L]+tmquantdif))
  (tsquants<-quantile(tnsmsdt[['r9s']],c(.01,.5),na.rm=T))
  (tsquantdif<-tsquants[[2]]-tsquants[[1]])
  (tsthreshes<-c(tsquants[1L],tsquants[2L]+tsquantdif))
  threshdt<-data.table(lc_type=lctt,r9m_lo=tmthreshes[1L],r9m_hi=tmthreshes[2L],r9m_q99=quantile(tnsmsdt[['r9m']],.99,na.rm=T),
                       r9s_lo=tsthreshes[1L],r9s_hi=tsthreshes[2L],r9s_q99=quantile(tnsmsdt[['r9s']],.99,na.rm=T))
  tids2keep<-tnsmsdt[r9m>tmthreshes[1L]&r9m<tmthreshes[2L]&r9s>tsthreshes[1]&r9s<tsthreshes[2L]][['id']]
  tids2keep<-sample(tids2keep,min(length(tids2keep),maxsampN),replace=F)
  return(list(threshdt,tids2keep))
}
# rm(nsmsDT);gc()
(threshes<-rbindlist(lapply(tmplist,`[[`,1),fill=T))
saveRDS(threshes,paste0("data/",ctry,"/VIIRS/daily/",ctry,"_iso_nset_reg_match_threshes.rds"))
# rm(threshes,lcs2keep);gc()

fids2keep<-unlist(lapply(tmplist,`[[`,2))
(fmatchDT<-matchDT[id%chin%fids2keep])
setkey(fmatchDT,id)
saveRDS(fmatchDT,paste0("data/",ctry,"/VIIRS/daily/",ctry,"_iso_nset_reg_match_data.rds"))
# rm(matchDT,fids2keep);gc()

for(m in tifmonths){
  # m<-tifmonths[21L]
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
