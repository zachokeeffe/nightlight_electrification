# rsync -rltgoDuvhh --progress /victor/Work/Brian/current/R_code/FBHRSL/ zokeeffe@flux-xfer.arc-ts.umich.edu:/nfs/brianmin/work/zokeeffe/current/R_code/FBHRSL/

# export wd=/nfs/brianmin/work/zokeeffe/current/; export ctry=Brunei; export ncores=6; R

sapply(c("data.table","lme4"),require,character.only=T)

(YYYY<-as.integer(Sys.getenv("YYYY")))
(ctry<-Sys.getenv("ctry"))
(wd<-Sys.getenv("wd"))
# ctry<-'Nepal'
# ncores<-12L
# wd<-'/nfs/brianmin/work/zokeeffe/current/'
setwd(wd)

conflevs<-c(.85,.9,.95)
(confthreshes<-qnorm(conflevs,mean=0,sd=1))
(conflevnamestmp<-paste0('lit_conf',conflevs*100))
(conflevnamesfin<-paste0('prplit_conf',conflevs*100))

(rdsDir<-paste0("data/",ctry,"/VIIRS/daily/"))

(LCt2<-readRDS(paste0("data/",ctry,"/VIIRS/daily/",ctry,"_RE_reg_multiyear_dropoutfull_LCdt.rds")))
(dateDT<-readRDS(paste0("data/",ctry,"/VIIRS/daily/",ctry,"_RE_reg_multiyear_monthfac_dateDT.rds")))

mod<-readRDS(paste0("data/",ctry,"/VIIRS/daily/",ctry,"_RE_reg_multiyear_mod_final.rds"))
mod_sig<-sigma(mod)

(setfiles<-list.files(rdsDir,paste0(ctry,'_regdat_sets_',YYYY,'[0-1][0-9]\\.rds'),full.names=F))
(nsetfiles<-length(setfiles))

setrmuDT<-vector('list',nsetfiles)
for(i in 1:nsetfiles){
  f<-setfiles[i]
  (setDT<-readRDS(paste0(rdsDir,f)))
  (setDT<-merge(setDT,dateDT,by='locdatechar'))
  (setDT<-merge(setDT,LCt2,by='lc_type'))
  r9preds<-predict(mod,newdata=setDT)
  set(setDT,NULL,'r9rs',(setDT[['r9']]-r9preds)/mod_sig)
  setDT<-setDT[,list(id,r9rs)]
  setrmuDT[[i]]<-setDT
  rm(setDT,r9preds);gc()
}
(setrmuDT<-rbindlist(setrmuDT,fill=T))

for(x in 1:length(conflevs)){
  set(setrmuDT,NULL,conflevnamestmp[x],as.integer(setrmuDT[['r9rs']]>confthreshes[x]))
}
setrmuDT[,(c('zscore',conflevnamesfin)):=lapply(.SD,mean),.SDcols=c('r9rs',conflevnamestmp),by='id']
set(setrmuDT,NULL,'lightscore',(pnorm(setrmuDT[['zscore']])-.5)/.5)
set(setrmuDT,setrmuDT[,.I[lightscore<0]],which(names(setrmuDT)=='lightscore'),0)

(setrmuDTf<-unique(setrmuDT[,c('id','zscore','lightscore',conflevnamesfin),with=F]))

saveRDS(setrmuDTf,paste0("data/",ctry,"/VIIRS/daily/",ctry,"_RE_reg_my_sets_predvals_",YYYY,".rds"))
