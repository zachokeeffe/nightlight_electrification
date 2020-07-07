# load the following required packages
sapply(c("data.table","bit64","raster"),require,character.only=T)
# get the following variables from the environment
(ctry<-Sys.getenv("ctry")) # country
(wd<-Sys.getenv("wd")) # working directory
# set working directory
setwd(wd)

# specify years to work on
YYYYs<-2012:2017
# specify number of cells to split raster by
splitrastby<-500000

# read in country cell, id, and xy info
(xyDT<-readRDS(paste0("data/",ctry,"/",ctry,"_resamp_country_cell_xy_id.rds")))
# read in the 15 to 1as cell match data
(setmatchDT<-readRDS(paste0('data/',ctry,'/',ctry,'_orig_v_resamp_set_cell_match.rds')))
# merge two data.tables together
(matchDT<-merge(xyDT[,list(id,cell_resamp)],setmatchDT,by='cell_resamp'))
# remove unnecessary
rm(xyDT,setmatchDT);gc()

# read in 1as raster
(rast<-raster(paste0('data/',ctry,'/GeoTIFFs/',ctry,'_sets_1as.tif'),band=1))
# fill raster with missing
rast[]<-NA;gc()
# for each year
for(YYYY in YYYYs){
  # announce the year being worked on
  message(paste("working on year",YYYY))
  # create name for raster to be created
  (fin_file<-paste0(wd,'data/',ctry,'/GeoTIFFs/',ctry,'_wbnaterate_sets_lit_',YYYY,'.tif'))
  # specify name of World Bank electrification data to read in
  (in_file<-paste0('data/',ctry,'/VIIRS/thresh_lit/',ctry,'_set_id_lit_wb_erate_pop_',YYYY,'.rds'))
  # read in WB erate data
  (r9lmdtr<-readRDS(in_file))
  # merge with cell information
  (r9lmdtr<-merge(r9lmdtr,matchDT,by='id'))
  # get settlement cells that are not considered lit
  cnl<-r9lmdtr[lit==0L][['cell_orig']]
  # get settlement cells that are considered lit
  cl<-r9lmdtr[lit==1L][['cell_orig']]
  rm(r9lmdtr);gc()
  # copy empty raster
  trast<-copy(rast);gc()
  # if not all settlement cells are unlit,
  if(length(cnl)!=0L){
    # split the vector of unlit cell values into groups
    cnl<-split(cnl,ceiling(seq_along(cnl)/splitrastby))
    # for each group, set those cells to 0 in the raster
    for(part in cnl){trast[part]<-0;gc()}
    rm(cnl);gc()
  }
  # if not all settlement cells are lit,
  if(length(cl)!=0L){
    # split the vector of lit cell values into groups
    cl<-split(cl,ceiling(seq_along(cl)/splitrastby))
    # for each group, set those cells to 1 in the raster
    for(part in cl){trast[part]<-1;gc()}
    rm(cl);gc()
  }
  # save the raster as a GeoTIFF
  writeRaster(trast,fin_file,format="GTiff",overwrite=T,options=c("COMPRESS=LZW"),datatype='INT2S')
  # remove unnecessary
  rm(trast,fin_file,file_5as,call1);gc()
  # announce finish
  message(paste("finished",YYYY))
}
rm(rast);gc()
