# load the following required packages
sapply(c('raster','parallel'),require,character.only=T)
# get the following variables from the environment
(ctry<-Sys.getenv("ctry")) # country
(wd<-Sys.getenv("wd")) # working directory
(ncores<-as.integer(Sys.getenv("ncores"))) # number of cores
# set working directory
setwd(wd)
# set number of cores for parallelization
options(mc.cores=ncores)

# specify and create new directory for rasters
(outdir<-paste0('data/',ctry,'/GeoTIFFs/'))
dir.create(outdir,F,T)

# find Facebook population settlement raster corresponding to the country
(fbHRSL<-list.files(paste0('data/',ctry,'/FB'),'population_[a-z][a-z][a-z]_20[0-9][0-9]-[0-9][0-9]-[0-9][0-9]\\.tif$',full.names=T))
# fail if not found
stopifnot(length(fbHRSL)==1)

# load the raster
(setrast<-raster(fbHRSL))

# get the number of cells from the raster
(Ncells<-ncell(setrast))

# if the raster is too large
if(Ncells>.Machine$integer.max){
  # get the values by row using mclapply
  rastvals<-mclapply(1:nrow(setrast),function(X) getValues(setrast,X,1),mc.preschedule=F)
  rastvals<-unlist(rastvals)
} else {
  # otherwise just extract them directly
  rastvals<-setrast[]
}
# find settlement cells (non-empty ones)
setcells<-which(!is.na(rastvals))
# get long-lat information from settlement cells
setXYs<-xyFromCell(setrast,setcells)

# read in disaggregated shapefile
(shp<-shapefile(paste0("data/",ctry,"/shapefiles/",ctry,"_noproj_disag_simp")))
# create empty raster with same resolution based on the extent of the country
(rast1<-raster(x=extent(shp),resolution=c(0.0002777778,0.0002777778),crs='+proj=longlat +datum=WGS84 +no_defs +ellps=WGS84 +towgs84=0,0,0'))
# set datatype
dataType(rast1)<-'INT2S'
# populate with NAs
rast1[]<-NA
# find cells corresponding to settlement coordinates
setCells1<-cellFromXY(rast1,setXYs)
# set these to 1
rast1[setCells1]<-1L
# write new 1 arcsecond raster
writeRaster(rast1,paste0(outdir,ctry,'_sets_1as.tif'),overwrite=TRUE,options=c("COMPRESS=LZW"))

# create a 15 arcsecond raster in a similar fashion
(rast15<-raster(x=extent(shp),resolution=c(0.0041666667,0.0041666667),crs='+proj=longlat +datum=WGS84 +no_defs +ellps=WGS84 +towgs84=0,0,0'))
dataType(rast15)<-'INT2S'
rast15[]<-NA
setCells15<-cellFromXY(rast15,setXYs)
# get unique cells because multiple 1as coordinates should fit in cell
setCells15<-unique(setCells15)
# set cells to 1
rast15[setCells15]<-1L
# write new 15 arcsecond settlement raster
writeRaster(rast15,paste0(outdir,ctry,'_sets_15as.tif'),overwrite=TRUE,options=c("COMPRESS=LZW"))
