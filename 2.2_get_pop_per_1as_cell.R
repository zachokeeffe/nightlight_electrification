# load the following required packages
sapply(c("data.table","bit64","raster"),require,character.only=T)
# get the following variables from environment
(ctry<-Sys.getenv("ctry")) # country
(wd<-Sys.getenv("wd")) # working directory
# set working directory
setwd(wd)

# find high resolution settlement layer file
(fbHRSL<-list.files(paste0('data/',ctry,'/FB'),'population_[a-z][a-z][a-z]_20[0-9][0-9]-[0-9][0-9]-[0-9][0-9]\\.tif$',full.names=T))
# if file not found, stop
stopifnot(length(fbHRSL)==1)

# load data.table of 1as to 15as cell matches
(setmatchDT<-readRDS(paste0('data/',ctry,'/',ctry,'_orig_v_resamp_set_cell_match.rds')))
# open 1as raster
(rast_1as<-raster(paste0('data/',ctry,'/GeoTIFFs/',ctry,'_sets_1as.tif'),band=1))
# open original FB raster
(rast_pop<-raster(fbHRSL,band=1))

# get 1as cells with settlements
rast_1as_cell<-setmatchDT[['cell_orig']]
# get xy coordinates
rast_1as_XY<-xyFromCell(rast_1as,rast_1as_cell)
# get cells from FB raster using xy values
rast_pop_cell<-cellFromXY(rast_pop,rast_1as_XY)
# get values of cells (which are population estimates)
rast_pop_vals<-rast_pop[rast_pop_cell]

# create data.table of 1as cells and their corresponding population estimates
(popDT<-data.table(cell_orig=rast_1as_cell,pop=rast_pop_vals))

# save as RDS
saveRDS(popDT,paste0('data/',ctry,'/',ctry,'_cell_orig_pop.rds'))