# load following required packages
sapply(c("data.table","bit64"),require,character.only=T)

# get following variables from environment
(ctry<-Sys.getenv("ctry")) # country
(wd<-Sys.getenv("wd")) # working directory
# set working directory
setwd(wd)

# read data.table of 15as cells with ID and xy info
(xyDT<-readRDS(paste0('data/',ctry,'/',ctry,'_resamp_country_cell_xy_id.rds')))
# read data.table of 15as-1as cell matches
(setmatchDT<-readRDS(paste0('data/',ctry,'/',ctry,'_orig_v_resamp_set_cell_match.rds')))

# get number of 1as settlement cells within each 15as cell
(setNDT<-setmatchDT[,list(N_set_cells=.N),by='cell_resamp'])
# calculate proportion of 15as cell filled with 1as settlement cells by dividing by 225 (the max)
set(setNDT,NULL,'prp_sets',setNDT[['N_set_cells']]/225)

# merge proportion of settlement cells with 15as cell ID information
(xyDT2<-merge(xyDT[,list(id,cell_resamp)],setNDT[,list(cell_resamp,prp_sets)],all.x=T))
# if missing values, fill with 0, because that means there are no settlement cells in the cell
set(xyDT2,xyDT2[,.I[is.na(prp_sets)]],which(names(xyDT2)=='prp_sets'),0)
# remove cell_resamp column
xyDT2[,cell_resamp:=NULL]

# save as RDS
saveRDS(xyDT2,paste0('data/',ctry,'/',ctry,'_resamp_country_cell_id_prp_sets.rds'))