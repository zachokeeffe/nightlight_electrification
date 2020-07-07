# rsync -rltgoDuvhh --progress /victor/Work/Brian/current/R_code/FBHRSL/ zokeeffe@flux-xfer.arc-ts.umich.edu:/nfs/brianmin/work/zokeeffe/current/R_code/FBHRSL/

sapply(c("data.table","bit64","raster"),require,character.only=T)

(ctry<-Sys.getenv("ctry"))
(wd<-Sys.getenv("wd"))
# ctry<-'Nepal'
# wd<-'/victor/Work/Brian/current/'
setwd(wd)

(rast<-raster(paste0('data/',ctry,'/GeoTIFFs/',ctry,'_sets_15as.tif'),band=1))

(xyDT<-readRDS(paste0('data/',ctry,'/',ctry,'_resamp_country_cell_xy_id.rds')))

## settlement stuff to match on later
(setmatchDT<-readRDS(paste0('data/',ctry,'/',ctry,'_orig_v_resamp_set_cell_match.rds')))
(popDT<-readRDS(paste0('data/',ctry,'/',ctry,'_cell_orig_pop.rds')))
(prpset<-readRDS(paste0('data/',ctry,'/',ctry,'_resamp_country_cell_id_prp_sets.rds')))
(prpset<-prpset[,list(set_id_match=id,N_1as_sets=as.integer(round(prp_sets*225)))])
(finsetdatmatch<-merge(xyDT[grepl('s',id),list(set_id_match=id,cell_resamp)],setmatchDT,by='cell_resamp'))
(finsetdatmatch<-merge(finsetdatmatch,popDT,by='cell_orig',all.x=T))
(finsetdatmatch<-merge(finsetdatmatch,prpset,by='set_id_match',all.x=T))
set(finsetdatmatch,NULL,'cell_orig',NULL)
set(finsetdatmatch,NULL,'cell_resamp',NULL)
(finsetdatmatch<-finsetdatmatch[,list(pop=sum(pop,na.rm=T),N_1as_sets=N_1as_sets[1L]),by='set_id_match'])
rm(setmatchDT,popDT,prpset);gc()
##

cellDTf<-xyDT[,list(id,cell_resamp)]
set(cellDTf,NULL,'row',rowFromCell(rast,cellDTf[['cell_resamp']]))
set(cellDTf,NULL,'col',colFromCell(rast,cellDTf[['cell_resamp']]))
(rastNrow<-nrow(rast))
(rastNcol<-ncol(rast))
(rastNcell<-ncell(rast))
rm(rast,xyDT);gc()
set(cellDTf,NULL,'set',as.integer(grepl('s',cellDTf[['id']])))

set(cellDTf,NULL,'edge',FALSE)
set(cellDTf,cellDTf[,.I[row==1L|row==rastNrow|col==1L|col==rastNcol]],'edge',TRUE)
cellDTf

(cellmatchfix<-cellDTf[,list(id,edge)])

(cellDT1<-cellDTf[set==1L,list(set_id_match=id,col=col-1,row=row-1)])
(cellDT2<-cellDTf[set==1L,list(set_id_match=id,col=col,row=row-1)])
(cellDT3<-cellDTf[set==1L,list(set_id_match=id,col=col+1,row=row-1)])
(cellDT4<-cellDTf[set==1L,list(set_id_match=id,col=col-1,row=row)])
(cellDT5<-cellDTf[set==1L,list(set_id_match=id,col=col+1,row=row)])
(cellDT6<-cellDTf[set==1L,list(set_id_match=id,col=col-1,row=row+1)])
(cellDT7<-cellDTf[set==1L,list(set_id_match=id,col=col,row=row+1)])
(cellDT8<-cellDTf[set==1L,list(set_id_match=id,col=col+1,row=row+1)])
(cellDTMatch<-rbindlist(list(cellDT1,cellDT2,cellDT3,cellDT4,cellDT5,cellDT6,cellDT7,cellDT8),fill=T))
rm(cellDT1,cellDT2,cellDT3,cellDT4,cellDT5,cellDT6,cellDT7,cellDT8);gc()

(fincellmatch<-merge(cellDTf[,list(id,row,col)],cellDTMatch,by=c('row','col')))
set(fincellmatch,NULL,'row',NULL)
set(fincellmatch,NULL,'col',NULL)
rm(cellDTf);gc()

(finDT<-merge(fincellmatch[,list(id,set_id_match)],finsetdatmatch,by='set_id_match'))
(finDT<-finDT[,list(N_15as_set_dist1=.N,N_1as_set_dist1=sum(N_1as_sets),pop_dist1=sum(pop,na.rm=T)),by='id'])
(finDT<-merge(cellmatchfix,finDT,by='id',all.x=T))
set(finDT,finDT[,.I[is.na(N_15as_set_dist1)]],'N_15as_set_dist1',0L)
set(finDT,finDT[,.I[is.na(N_1as_set_dist1)]],'N_1as_set_dist1',0L)
set(finDT,finDT[,.I[is.na(pop_dist1)]],'pop_dist1',0L)
finDT

saveRDS(finDT,paste0('data/',ctry,'/',ctry,'_id_set_stats_15as_cell_dist1.rds'))

rm(finDT,fincellmatch,finsetdatmatch,cellmatchfix);gc()
