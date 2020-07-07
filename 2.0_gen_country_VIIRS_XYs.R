# load the following required packages
sapply(c("data.table","bit64","parallel","foreach","doMC","raster",'sf',"rgdal","rgeos"),require,character.only=T)
# get the following variables from the environment
(ncores<-as.integer(Sys.getenv("ncores"))) # number of cores for parallel operations
(ctry<-Sys.getenv("ctry")) # country
(wd<-Sys.getenv("wd")) # working directory
# set working directory
setwd(wd)

# register cores for parallel operations
registerDoMC(ncores)

# path to edited country shapefile
(country_shp<-paste0("data/",ctry,"/shapefiles/",ctry,"_noproj_disag_simp.shp"))
# path to 1 arc second settlement raster
(set_path_1as<-paste0('data/',ctry,'/GeoTIFFs/',ctry,'_sets_1as.tif'))
# path to 15 arc second settlement raster
(set_path_15as<-paste0('data/',ctry,'/GeoTIFFs/',ctry,'_sets_15as.tif'))

# load country shapefile
(countryShp<-st_read(country_shp))
# load resampled settlement raster
(setrast_15as<-raster(set_path_15as,band=1))
# load original settlement raster
(setrast_1as<-raster(set_path_1as,band=1))

# get number of rows from each raster
(nrowSRr<-nrow(setrast_15as))
(nrowSRo<-nrow(setrast_1as))
# get number of columns from each raster
(ncolSRr<-ncol(setrast_15as))
(ncolSRo<-ncol(setrast_1as))

# vector from one to number of rows of 1as raster
rowso<-1:nrowSRo
# specify number of rows per group
rowspergrp<-400L
# split rows into groups
rowso_split<-split(rowso,ceiling(seq_along(rowso)/rowspergrp))

# create data.table of cells matching 1as to 15as raster in parallel, working on each row group
cell_lookup_dt<-rbindlist(foreach(rg=1:length(rowso_split),.inorder=T)%dopar%{
  # get temporary rows to work with
  trows<-rowso_split[[rg]]
  # get cells from 1as raster
  cells_o<-cellFromRow(setrast_1as,trows)
  # get values corresponding to those cells
  values_o<-values(setrast_1as,row=trows[1L],nrows=length(trows))
  # remove missing
  valuesNoNA_o<-which(!is.na(values_o))
  # if not all missing,
  if(length(valuesNoNA_o)!=0L){
    # get cells corresponding to nonmissing values (settlement cells)
    cells_o2<-cells_o[valuesNoNA_o]
    # get xy values from cells
    xys_o<-xyFromCell(setrast_1as,cells_o2)
    # get cell from 15as raster corresponding to those xy values
    cells_r<-cellFromXY(setrast_15as,xys_o)
    # return data.table of cells from 1as (cell_orig) and 15as (cell_resamp)
    return(data.table(cell_orig=cells_o2,cell_resamp=cells_r))
  } else {
    return(NULL)
  }
},fill=T)
# remove missing
(cell_lookup_dt<-na.omit(cell_lookup_dt))
# save data.table as RDS file
saveRDS(cell_lookup_dt,paste0('data/',ctry,'/',ctry,'_orig_v_resamp_set_cell_match.rds'))

# get cells in 15as raster that have settlements
agg_set_cells<-sort(unique(cell_lookup_dt[['cell_resamp']]))
# get xy values from those cells
agg_set_xys<-xyFromCell(setrast_15as,agg_set_cells)
# create data.table of cells and xy values
(agg_set_cxy<-data.table(cell_resamp=agg_set_cells,agg_set_xys))
# save as RDS file
saveRDS(agg_set_cxy,paste0('data/',ctry,'/',ctry,'_resamp_set_cell_xy.rds'))

# create vector from one to number of rows in 15as raster
rowsr<-1:nrowSRr

# set rows per group
rowspergrp<-50L
# split vector into groups of rows
rowsr_split<-split(rowsr,ceiling(seq_along(rowsr)/rowspergrp))

# get cells in 15as raster intersecting with country boundary that do not contain settlements by working on row groups in parallel
nonset_cells<-rbindlist(foreach(rg=1:length(rowsr_split),.inorder=T)%dopar%{
  # get temporary row set
  trows<-rowsr_split[[rg]]
  # get cells in those rows
  cells_o<-cellFromRow(setrast_15as,trows)
  # return cells that do not have settlements
  cells_o<-setdiff(cells_o,agg_set_cells)
  # if not empty,
  if(length(cells_o)!=0L){
    # get xy values from those cells
    xys_o<-xyFromCell(setrast_15as,cells_o)
    # make data.table of cell and xy values
    (cxy_dt<-data.table(cell_resamp=cells_o,xys_o))
    # convert data.table to spatial object
    points<-st_as_sf(cxy_dt,coords=c('x','y'),crs=st_crs(countryShp))
    # intersect with county shapefile
    point_ctry_int<-st_intersects(points,countryShp)
    # determine which points lie within the country boundary
    nonempty<-unlist(lapply(point_ctry_int,function(xx) length(xx)!=0))
    nonempty_cells<-which(nonempty)
    # return the non-settlement cells that are inside the country boundary
    return(cxy_dt[nonempty_cells])
  } else {
    return(NULL)
  }
},fill=T)
# remove missing
(nonset_cells<-na.omit(nonset_cells))
# save as RDS
saveRDS(nonset_cells,paste0('data/',ctry,'/',ctry,'_resamp_nonset_cell_xy.rds'))

# reorder 15as cell data.table of settlement cells
setorder(agg_set_cxy,cell_resamp)
# assign new settlement identifier
set(agg_set_cxy,NULL,'id',paste0('s',1:nrow(agg_set_cxy)))
# reorder 15as cell data.table of non-settlement cells
setorder(nonset_cells,cell_resamp)
# assign new non-settlement identifier
set(nonset_cells,NULL,'id',paste0('n',1:nrow(nonset_cells)))

# bind settlement and non-settlement cell information
(ctry_cxys<-rbindlist(list(agg_set_cxy,nonset_cells),fill=T))
# save as RDS
saveRDS(ctry_cxys,paste0('data/',ctry,'/',ctry,'_resamp_country_cell_xy_id.rds'))