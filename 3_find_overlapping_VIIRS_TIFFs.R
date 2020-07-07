# load the following required packages
sapply(c("data.table","bit64","parallel","foreach","doMC","raster","rgeos"),require,character.only=T)
# set working directory
setwd("/nfs/brianmin/work/zokeeffe/current/")
# specify path where VIIRS GeoTIFF metadata are stored
viirs_dat_path<-"/nfs/brianmin/VIIRS/"
# get number of cores for parallel operations from environment
(ncores<-as.integer(Sys.getenv("ncores")))
# get country from environment
(ctry<-Sys.getenv("ctry"))
# specify a single thread for DT operations, then set cores for parallel operations
setDTthreads(1L);registerDoMC(ncores)

# specify directory with GDAL information extracted from vflag files
(gdaldir<-paste0(viirs_dat_path,"gdalinfo/vflag/"))
# get list of directories with metadata
(YYYYMMs<-list.dirs(gdaldir,recursive=F,full.names=F))

# specify six monthly file tiles
MVTypes<-c("00N060E","75N060E","00N060W","75N060W","00N180W","75N180W")
MVexl<-list()
# for each type, open an example TIFF and get the extent
for(mvt in MVTypes){
  tmp<-raster(paste0(viirs_dat_path,'monthly/201204/vcmcfg/SVDNB_npp_20120401-20120430_',mvt,'_vcmcfg_v10_c201605121456.cf_cvg.tif'))
  MVexl[[mvt]]<-extent(tmp)
  rm(tmp);gc()
}

# specify country shapefile path
(country_shp<-paste0("data/",ctry,"/shapefiles/",ctry,"_noproj_disag_simp.shp"))
# open the shapefile
(CountryShp<-shapefile(country_shp))
# get the extent
(CountryExtent<-extent(CountryShp))
# specify new directory for where to store data
(tiff_list_outdir<-paste0("data/",ctry,"/VIIRS/daily/"))
# create directory
dir.create(tiff_list_outdir,recursive=T,showWarnings=F)

# create an empty list the length of the number of months of data
FinDT<-vector('list',length(YYYYMMs))
# for each month of data,
for(i in 1:length(YYYYMMs)){
  YYYYMM<-YYYYMMs[i]
  message(paste('working on',YYYYMM))
  # get the files of metadata
  FileList<-list.files(path=paste0(gdaldir,YYYYMM),pattern="*.info$")
  # try to read textfiles that list rasters with "bad data" so these can be ignored; if they don't exist, ignore
  try({
    (BadFileList<-fread(paste0(viirs_dat_path,"bad_rasters/",YYYYMM,"_bad_rasters.txt"),sep="/",header=F))
    if(ncol(BadFileList)==3L){
      badfiles<-paste0(BadFileList[[2L]],".info")
      FileList<-setdiff(FileList,badfiles)
    }
  })
  # start the overlap checking process for each file
  OverlapCheck<-foreach(f=FileList,.inorder=T,.options.multicore=list(preschedule=F))%dopar%{
    tiff_name<-sub(".info","",f,fixed=T)
    # read in metadata from file
    info<-readLines(paste0(viirs_dat_path,"gdalinfo/vflag/",YYYYMM,"/",f))
    # get upper left coordinates and remove surrounding text
    (ULCoords<-grep("^Upper Left  \\(",info,value=T))
    (ULCoords<-sub("(^Upper Left  )(\\(.*?\\))(.*)$","\\2",ULCoords))
    (ULCoords<-trimws(gsub("[[:space:]]+","",gsub("\\(|\\)","",ULCoords))))
    # convert to numeric
    (ULXY<-as.numeric(unlist(strsplit(ULCoords,","))))
    # get lower right coordinates and remove surrounding text
    (LRCoords<-grep("^Lower Right \\(",info,value=T))
    (LRCoords<-sub("(^Lower Right )(\\(.*?\\))(.*)$","\\2",LRCoords))
    (LRCoords<-trimws(gsub("[[:space:]]+","",gsub("\\(|\\)","",LRCoords))))
    # convert to numeric
    (LRXY<-as.numeric(unlist(strsplit(LRCoords,","))))
    # create an extent using the extracted coordinates
    tiff_extent<-extent(ULXY[1L],LRXY[1L],LRXY[2L],ULXY[2L])
    # determine whether TIFF overlaps with country extent
    ext_overlap<-as.integer(!is.null(intersect(CountryExtent,tiff_extent)))
    # create data.table that states whether the TIFF in question overlaps with the country extent
    data.table(ext_overlap=ext_overlap,tiff_name=tiff_name)
  }
  # row bind all the results together
  OverlapCheck<-rbindlist(OverlapCheck,fill=T)
  # only keep overlapping TIFFs
  (OverlapCheck<-OverlapCheck[ext_overlap==1L,list(tiff_name)])
  set(OverlapCheck,NULL,1L,paste(YYYYMM,OverlapCheck[[1L]],sep="/"))
  # assign results to empty list slot
  FinDT[[i]]<-OverlapCheck
}
# row bind the results
(FinDT<-rbindlist(FinDT,fill=T))

# specify the file name to save under
fname<-paste0(tiff_list_outdir,ctry,"_daily_VIIRS_overlapping_imgs.txt")
# write the file out
fwrite(FinDT,fname,col.names=F,quote=F,sep=",",na="",nThread=ncores)
rm(FinDT);gc()

# now see which of the six month tiles overlaps with the country extent
MVOv<-rbindlist(foreach(mvt=MVTypes,.inorder=T)%dopar%{
  ext_overlap<-as.integer(!is.null(intersect(CountryExtent,MVexl[[mvt]])))
  data.table(ext_overlap=ext_overlap,mvt=mvt)
},fill=T)
(MVOv<-MVOv[ext_overlap==1L][["mvt"]])
# save the results as a text file
writeLines(MVOv,paste0("data/",ctry,"/VIIRS/",ctry,"_monthly_VIIRS_overlapping_tiles.txt"),sep="\n")