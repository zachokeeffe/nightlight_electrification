# load following required packages
sapply(c("data.table","bit64","parallel","foreach","doMC","raster"),require,character.only=T)

# get following variables from environment
(ncores<-as.integer(Sys.getenv("ncores"))) # number of cores
(ctry<-Sys.getenv("ctry")) # country
(wd<-Sys.getenv("wd")) # working directory
# set working directory
setwd(wd)
# register cores for parallel operations
registerDoMC(ncores)

# specify year of landcover type data
LCyr<-2012L
# make path to landcover file directory
(LCdir<-paste0('data/LandCover/LandCoverTiles',LCyr,'/'))

# read intersecting landcover tyle information
(inttiles<-readRDS(paste0('data/',ctry,'/',ctry,'_intersecting_landcover_tiles_',LCyr,'.rds')))

# read long-lat information for 15as cells in country
(xys<-readRDS(paste0('data/',ctry,'/',ctry,'_resamp_country_cell_xy_id.rds')))
# convert x-y coords to matrix
xyMat<-as.matrix(xys[,list(x,y)])
# store IDs as vector
ids<-xys[['id']]
rm(xys);gc()

# for each of the intersecting tiles, to the following, collecting results in a data.table
lc_dt<-rbindlist(foreach(it=inttiles,.options.multicore=list(preschedule=F))%dopar%{
  # open tile raster
  (rast<-raster(paste0(LCdir,it),band=1))
  # create data.table of IDs and their corresponding landcover type extracted from raster
  (dt<-data.table(id=ids,lc_type=extract(rast,xyMat,method="simple",cellnumbers=F)))
  # remove missing
  return(na.omit(dt))
},fill=T)
# get unique values
(lc_dt<-unique(lc_dt))

# save result
saveRDS(lc_dt,paste0('data/',ctry,'/',ctry,'_resamp_country_cell_xy_landcover_values_',LCyr,'.rds'))