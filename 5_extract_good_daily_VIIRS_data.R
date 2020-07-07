# load following required packages
sapply(c("data.table","bit64","parallel","foreach","doMC","raster","rgeos","rgdal"),require,character.only=T)
# set working directory
setwd("/nfs/brianmin/work/zokeeffe/current/")
# get following variables from environment
(ncores<-as.integer(Sys.getenv("ncores"))) # number of cores
(YYYY<-as.integer(Sys.getenv("YYYY"))) # year
(MM<-Sys.getenv("MM")) # month
(ctry<-Sys.getenv("ctry")) # country
# register cores
registerDoMC(ncores)
# specify directory where extracted VIIRS GeoTIFFs are
TIFFTopDir<-'/scratch/polisci_dept_root/polisci_dept/zokeeffe/VIIRS/'

# read in file of "good" vflag integers
good_ints<-fread("data/VIIRS/vflag_info/new_good_vflag_ints_no_li.txt",header=F)[[1L]]
# read in country 15as cell coordinates and IDs
(xyDT<-readRDS(paste0('data/',ctry,'/',ctry,'_resamp_country_cell_xy_id.rds')))
# store IDs as vector
xyIDs<-xyDT[["id"]]
# convert xy coordinates to matrix
xyMat<-as.matrix(xyDT[,list(x,y)])
# convert matrix to spatial points object
xyPts<-SpatialPoints(coords=xyMat,proj4string=CRS("+init=epsg:4326"))
# get extent of country, adding a buffer
(xyExt<-extent((min(xyDT[['x']])-.1),(max(xyDT[['x']])+.1),(min(xyDT[['y']])-.1),(max(xyDT[['y']])+.1)))
rm(xyPts,xyDT)

# read in file that states which TIFFs overlap with country
(tifdirs<-fread(paste0("data/",ctry,"/VIIRS/daily/",ctry,"_daily_VIIRS_overlapping_imgs.txt"),header=F,sep="/"))
# if year is not missing, subset the TIFFs to those that correspond to that year
if(!is.na(YYYY)) tifdirs<-tifdirs[grep(paste0("^",YYYY),tifdirs[[1L]])]

# assign names to data.table
setnames(tifdirs,c("month","tiff"))
# get the unique set of months
(tifmonths<-sort(unique(tifdirs[[1L]])))
# specify a directory to store the extracted data in
(csv_dir<-paste0("data/",ctry,"/VIIRS/daily/CSVs/"))
# create the directory
dir.create(csv_dir,showWarnings=F,recursive=T)

# specify the VIIRS GeoTIFF file "types"
FileTypes<-c("li","vflag","rade9","rad","samples")
# create a regex string for searching for all of these
(FileRegex<-paste0("(",paste(FileTypes,collapse="|"),")\\.tif$"))
# get number of file types
NFTs<-length(FileTypes)

# set DT threads to 1
setDTthreads(1L)
# if MM has been specified, create set of months by combining year and month
if(MM%in%formatC(1:12,format='d',width=2L,flag='0')) (tifmonths<-paste0(YYYY,MM))
# numbers of things to work on per group
nprgrp<-10L

# final columns to keep for results
fincols2write<-c("id","day","stime","rade9","rad","li","samples")

# for each month
for(m in tifmonths){
  message(paste("working on",m));flush(stdout())
  # get the TIFF names for the month
  (tmptiffs<-tifdirs[month==m][["tiff"]])
  # get number of TIFFs
  (ntmptiffs<-length(tmptiffs))
  # create vector of 1 to the number of TIFFs
  (otntmptiffs<-1:ntmptiffs)
  # split TIFFs into groups
  (tifgrps<-floor(otntmptiffs/(nprgrp+1))+1)
  # number of groups
  (ntifgrps<-tail(tifgrps,1))
  # empty list for results to be stored in
  FinDT<-vector('list',ntifgrps)
  # for each group of TIFFs,
  for(tifgrp in 1:ntifgrps){
    # subset to group of TIFFs
    (tmptiffs2<-tmptiffs[tifgrps==tifgrp])
    # for each TIFF, extract results from TIFFs in a data.table
    res<-foreach(tiff_name=tmptiffs2,.inorder=T,.errorhandling="remove",.options.multicore=list(preschedule=F))%dopar%{
      # directory where group of TIFFs is stored
      (dir<-paste0(TIFFTopDir,m,"/",tiff_name))
      # get the names of the TIFFs in the directory
      (files<-sort(list.files(dir,FileRegex,all.files=F,full.names=F,recursive=F,include.dirs=F,no..=T)))
      # skip the operation if directory doesn't contain all types of TIFFs
      stopifnot(length(files)==NFTs)
      # getermine which is the vflag file
      vfn<-grep("vflag",files,value=T,fixed=T)
      # extract data from each type of TIFF into a data.table
      (val_dt<-foreach(ft=FileTypes,.inorder=T,.combine=cbind)%do%{
        # open raster of the particular file type
        rast<-raster(paste0(dir,"/",grep(paste0(ft,"\\.tif$"),files,value=T)))
        # crop the raster to the extent of the country
        crop_country<-crop(rast,xyExt)
        # if empty, stop
        stopifnot(!is.null(crop_country))
        # extract values from TIFF using coordinates
        dt<-data.table(val=extract(crop_country,xyMat,method="simple",cellnumbers=F))
        # name the column based on the type of TIFF
        setnames(dt,ft)
        return(dt)
      })
      gc()
      # add ID column to data.table
      set(val_dt,NULL,"id",xyIDs)
      # if the vflag is not in the list of "good" integers, drop the row
      val_dt<-val_dt[vflag%in%good_ints,!"vflag",with=F];gc()
      # drop if missing rade9 (visible light) info
      val_dt<-val_dt[!is.na(rade9)];gc()
      # drop if missing lunar illumination info
      val_dt<-val_dt[!is.na(li)];gc()
      # only keep so long as the rade9 is above -1.5
      val_dt<-val_dt[rade9>(-1.5)];gc()
      # only keep if LI is below .025
      val_dt<-val_dt[li<.025];gc()
      # assign the day value pulled from the vflag TIFF name
      set(val_dt,NULL,"day",as.integer(substr(vfn,12,13)))
      # assign the time of the overpass by extracting it from the vflag TIFF name
      set(val_dt,NULL,"stime",substr(vfn,16L,22L))
      # return the data.table
      return(val_dt)
    }
    # bind results into a list
    res<-rbindlist(res,fill=T)
    # store the results in the empty slot of the list created above
    FinDT[[tifgrp]]<-res
    rm(res,tmptiffs2);gc()
  }
  # rowbind data.tables together
  FinDT<-rbindlist(FinDT,fill=T)
  # remove unnecessary
  rm(tmptiffs,ntmptiffs,otntmptiffs,tifgrps,ntifgrps);gc()
  # if the data.table is empty
  if(nrow(FinDT)==0L){
    # report no data
    message(paste("no data extracted for",m));flush(stdout())
  # otherwise
  } else {
    # for each column in the data.table
    for(col in fincols2write){
      # save the column as a separate vector
      saveRDS(FinDT[[col]],paste0("data/",ctry,"/VIIRS/daily/CSVs/",ctry,"_daily_VIIRS_values_good_resamp_",m,"_",col,".rds"))
      # remove the column
      set(FinDT,NULL,which(names(FinDT)==col),NULL)
    }
  }
  # cleanup
  rm(FinDT);gc()
  message(paste("finished",m))
}
