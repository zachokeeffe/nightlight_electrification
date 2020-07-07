# rsync -rltgoDuvhh --progress /victor/Work/Brian/current/R_code/FBHRSL/ zokeeffe@flux-xfer.arc-ts.umich.edu:/nfs/brianmin/work/zokeeffe/current/R_code/FBHRSL/

# export wd=/nfs/brianmin/work/zokeeffe/current/; export ctry=Cambodia; export ncores=6; R

sapply(c("data.table","bit64","parallel","foreach","doMC"),require,character.only=T)

(ncores<-as.integer(Sys.getenv("ncores")))
(ctry<-Sys.getenv("ctry"))
(wd<-Sys.getenv("wd"))
# ncores<-12L
# ctry<-'Nepal'
# country<-'Nepal'
# wd<-'/victor/Work/Brian/current/'
setwd(wd)
registerDoMC(ncores)

YYYYs<-2012:2017

# WB electrification data
#eratedat<-fread('data/WorldBank/pct_pop_w_electricity_1990-2016.csv',header=T)
#(FBctries<-fread('data/FB/FB_countries.csv'))
#(country<-FBctries[country_short==ctry][['country_long']])
eratedat<-fread('data/WorldBank/pct_pop_w_electricity_1990-2017.csv',header=T)
(eratedat<-eratedat[ctry_short==ctry])
stopifnot(nrow(eratedat)==1)

conflevs<-c(.85,.9,.95)
(confthreshes<-qnorm(conflevs,mean=0,sd=1))
(plclnames<-paste0('prplit_conf',conflevs*100))
prplitthreshes<-c(.25,.5,.75)
(plclgpnames<-unlist(lapply(plclnames,function(x) paste0(x,'_gr',prplitthreshes*100,'pct'))))
(lsnames<-paste0('zscore_conf',conflevs*100))

xyDT<-readRDS(paste0('data/',ctry,'/',ctry,'_resamp_country_cell_xy_id.rds'))
xyDT<-xyDT[grep('s',id),list(id,cell_resamp)]
(setmatchDT<-readRDS(paste0('data/',ctry,'/',ctry,'_orig_v_resamp_set_cell_match.rds')))
(popDT<-readRDS(paste0('data/',ctry,'/',ctry,'_cell_orig_pop.rds')))
# (popDT2<-merge(setmatchDT,popDT,by='cell_orig'))
# could actually just cbind because they are already sorted but w/e, for robustness:
setkey(setmatchDT,cell_orig)
setkey(popDT,cell_orig)
(popDT2<-popDT[setmatchDT])
(popDT2<-popDT2[,list(totpop=ifelse(all(is.na(pop)),NA_real_,sum(pop,na.rm=T))),by='cell_resamp'])
(matchDT<-merge(xyDT,na.omit(popDT2),by='cell_resamp'))
rm(xyDT,popDT2,popDT);gc()

(erate_comp<-rbindlist(foreach(YYYY=YYYYs,.inorder=T)%dopar%{
  # YYYY<-2012L
  #if(YYYY==2017L){(natl_elec_rate<-eratedat[`Country Name`==country][['2016']])} else {(natl_elec_rate<-eratedat[`Country Name`==country][[as.character(YYYY)]])}
  (natl_elec_rate<-eratedat[[as.character(YYYY)]])
  (setrmuDT<-readRDS(paste0("data/",ctry,"/VIIRS/daily/",ctry,"_RE_reg_my_sets_predvals_",YYYY,".rds")))
  (setrmuDT<-merge(setrmuDT,matchDT,by='id'))
  ttotpop<-sum(setrmuDT[['totpop']])
  (lsvals<-round(100*foreach(a=confthreshes,.inorder=T,.combine=c)%do%{sum(setrmuDT[zscore>a][['totpop']])/ttotpop},2))
  (plclvals<-foreach(var=plclnames,.inorder=T,.combine=c)%do%{
    round(100*foreach(a=prplitthreshes,.inorder=T,.combine=c)%do%{sum(setrmuDT[get(var)>a][['totpop']])/ttotpop},2)
  })
  (dt<-data.table(country=ctry,year=YYYY,erate_wb=round(natl_elec_rate,2)))
  for(x in 1:length(lsvals)){set(dt,NULL,lsnames[x],lsvals[x])}
  for(x in 1:length(plclvals)){set(dt,NULL,plclgpnames[x],plclvals[x])}
  dt
},fill=T))

fwrite(erate_comp,paste0("data/",ctry,"/",ctry,"_RE_reg_my_res_v_WB_erate.csv"))
