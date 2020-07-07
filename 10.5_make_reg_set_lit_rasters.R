# rsync -rltgoDuvhh --progress /victor/Work/Brian/current/R_code/FBHRSL/ zokeeffe@flux-xfer.arc-ts.umich.edu:/nfs/brianmin/work/zokeeffe/current/R_code/FBHRSL/

sapply(c("data.table","bit64","raster","rgdal"),require,character.only=T)

(YYYY<-as.integer(Sys.getenv("YYYY")))
(ctry<-Sys.getenv("ctry"))
(wd<-Sys.getenv("wd"))
# ctry<-'Nepal'
# wd<-'/victor/Work/Brian/current/'
setwd(wd)

fstem<-'_RE_reg_my_sets_predvals_'
conflevs<-c(.85,.9,.95)
(lscorevars<-c('zscore','lightscore',paste0('prplit_conf',conflevs*100)))
(fintifstems<-paste0('_set_',lscorevars,'_'))

(xyDT<-readRDS(paste0("data/",ctry,"/",ctry,"_resamp_country_cell_xy_id.rds")))
(xyDT<-xyDT[grep('s',id),list(id,cell_resamp)])
(cellDT<-readRDS(paste0('data/',ctry,'/',ctry,'_orig_v_resamp_set_cell_match.rds')))
(cellDT<-merge(xyDT,cellDT,by='cell_resamp'))
set(cellDT,NULL,'cell_resamp',NULL)
rm(xyDT);gc()

(rast<-raster(paste0('data/',ctry,'/GeoTIFFs/',ctry,'_sets_1as.tif')))
dataType(rast)<-'FLT4S'
rast[]<-NA;gc()

# read in light score data
(nvaldt<-readRDS(paste0("data/",ctry,"/VIIRS/daily/",ctry,fstem,YYYY,".rds")))
# merge with cell numbers
(nvaldt<-merge(nvaldt[,c('id',lscorevars),with=F],cellDT,by='id'))
# remove ID variable
set(nvaldt,NULL,'id',NULL)
# create index vector
trowvec<-1:nrow(nvaldt)
# split index vector
splits<-split(trowvec,ceiling(seq_along(trowvec)/500000))
rm(trowvec);gc()
for(rnum in 1:length(lscorevars)){
  # rnum<-2L
  (lscorevar<-lscorevars[rnum])
  message(paste("working on var",lscorevar))
  (fin_file<-paste0(wd,'data/',ctry,'/GeoTIFFs/',ctry,fintifstems[rnum],YYYY,'.tif'))
  trast<-copy(rast)
  for(part in splits){
    nvaldttmp<-nvaldt[part,c('cell_orig',lscorevar),with=F]
    trast[nvaldttmp[['cell_orig']]]<-nvaldttmp[[lscorevar]]
    rm(nvaldttmp);gc()
  }
  writeRaster(trast,fin_file,format="GTiff",overwrite=T,options=c("COMPRESS=LZW"),datatype='FLT4S')
  rm(trast);gc()
  ## resample to 5 as
  # (file_5as<-sub(paste0('_',YYYY,'\\.tif$'),paste0('_5as_',YYYY,'.tif'),fin_file))
  # (call1<-paste('gdalwarp -tr 0.00138888888 -0.00138888888 -r average -overwrite -co "COMPRESS=LZW" -multi',fin_file,file_5as))
  # system(call1)
  # rm(fin_file,file_5as,call1);gc()
}
