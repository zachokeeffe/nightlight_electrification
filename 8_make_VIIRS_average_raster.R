# load the following required packages
sapply(c("data.table","bit64","raster"),require,character.only=T)
# get the following variables from environment
(YYYY<-as.integer(Sys.getenv('YYYY'))) # year
(ctry<-Sys.getenv("ctry")) # country
(wd<-Sys.getenv("wd")) # working directory
# set working directory
setwd(wd)

# open 15as country cell raster (to be filled later)
(rast<-raster(paste0('data/',ctry,'/GeoTIFFs/',ctry,'_sets_15as.tif'),band=1))
# set all cells to empty
rast[]<-NA_real_;gc()
# read the 15as id, coordinate, and cell data for the country
(xyDT<-readRDS(paste0("data/",ctry,"/",ctry,"_resamp_country_cell_xy_id.rds")))
# read in the file with mean logged rade9
r9dt<-readRDS(paste0("data/",ctry,"/VIIRS/daily/",ctry,"_good_r9_musd_",YYYY,".rds"))
# merge the mean logged rade9 data with the 15as cell position data by id
(r9dt<-merge(r9dt[,list(id,r9lm)],xyDT[,list(id,cell_resamp)],by='id'));gc()
# fill cell positions with mean logged rade9 data in raster
rast[r9dt[['cell_resamp']]]<-r9dt[['r9lm']]
# remove data.table
rm(r9dt);gc()
# save raster as GeoTIFF
writeRaster(rast,paste0('data/',ctry,'/GeoTIFFs/',ctry,'_rade9lnmu_',YYYY,'.tif'),format="GTiff",overwrite=T,options=c("COMPRESS=LZW"))