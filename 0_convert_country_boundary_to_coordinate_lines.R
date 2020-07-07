# load the following required packages
sapply(c("data.table","raster","rgdal","rgeos"),require,character.only=T)

# get the following variables from the environment:
(wd<-Sys.getenv("wd")) # working directory
(ctry<-Sys.getenv("ctry")) # country
# set working directory
setwd(wd)

# directory of country shapefile
(shpDir<-dir(paste0('data/',ctry,'/shapefiles'),'gadm36_[A-Z][A-Z][A-Z]_shp',full.names=T))
# find top-level GADM shapefile
(shp<-list.files(shpDir,'gadm36_[A-Z][A-Z][A-Z]_0\\.shp',full.names=T))
# fail if not found
stopifnot(length(shp)==1)

# read in list of countries
(FBctries<-fread('data/FB/FB_countries.csv'))
# get longform name of the country
(country<-FBctries[country_short==ctry][['country_long']])

# read country shapefile
(Shp<-shapefile(shp))
# disaggregate
(Shp<-disaggregate(Shp))
# simplify
(Shp<-gSimplify(Shp,.01,T))
# assign country name to shapefile
Shp$id<-rep(country,length(Shp))
# write shapefile
writeOGR(Shp,paste0("data/",ctry,"/shapefiles"),paste0(ctry,"_noproj_disag_simp"),driver="ESRI Shapefile",overwrite_layer=T)
