# load following required packages
sapply(c("data.table","bit64","parallel","foreach","doMC","raster",'sf'),require,character.only=T)

# get following variables from environment
(ncores<-as.integer(Sys.getenv("ncores"))) # number of cores for parallel operations
(ctry<-Sys.getenv("ctry")) # country
(wd<-Sys.getenv("wd")) # working directory
# set working directory
setwd(wd)
# register number of cores for parallel operations
registerDoMC(ncores)

# year of land classification data
LCyr<-2012L
# directory of land cover tiles
(LCdir<-paste0('data/LandCover/LandCoverTiles',LCyr,'/'))
# list of land cover TIFFs
(LCfiles<-list.files(LCdir,'\\.tif$',full.names=F))

# for each file
LCrelist<-foreach(f=LCfiles,.inorder=T)%dopar%{
  # open raster
  rast<-raster(paste0(LCdir,f),band=1)
  # get and return extent
  rect<-st_as_sfc(st_bbox(rast))
  return(rect)
}

# specify country shapefile path
(country_shp<-paste0("data/",ctry,"/shapefiles/",ctry,"_noproj_disag_simp.shp"))
# open shapefile
(countryShp<-st_read(country_shp))
# project shapefile using CRS from landcover extent
(countryShpTrans<-st_transform(countryShp,st_crs(LCrelist[[1]])))

# for each tile
inttiles<-foreach(i=1:length(LCrelist),.combine=c,.inorder=T,.options.multicore=list(preschedule=F))%dopar%{
  # test whether extent of landcover tile overlaps with country shapefile
  reint<-st_intersects(countryShpTrans,LCrelist[[i]])
  reint<-ifelse(any(lengths(reint)!=0L),LCfiles[i],NA_character_)
  return(reint)
}
# remove missing
(inttiles<-c(na.omit(inttiles)))

# save result as RDS
saveRDS(inttiles,paste0('data/',ctry,'/',ctry,'_intersecting_landcover_tiles_',LCyr,'.rds'))