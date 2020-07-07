# load the following required packages
sapply(c("data.table","bit64"),require,character.only=T)

# get the following variables from environment
(ctry<-Sys.getenv("ctry")) # country
(wd<-Sys.getenv("wd")) # working directory
# set working directory
setwd(wd)

# read in electrification rate data from the World Bank
(eratedat<-fread('data/WorldBank/pct_pop_w_electricity_1990-2017.csv',header=T))
# read in list of countries
(FBctries<-fread('data/FB/FB_countries.csv'))
# get "longform" name of country
(country<-FBctries[country_short==ctry][['country_long']])

# read in 15as cell information
(xyDT<-readRDS(paste0("data/",ctry,"/",ctry,"_resamp_country_cell_xy_id.rds")))
# create data.table of settlement value ids and cell positions
(matchdt<-xyDT[grep('s',id),list(id,cell_resamp)])

# read in 15 to 1as cell match data.table
(setmatchDT<-readRDS(paste0('data/',ctry,'/',ctry,'_orig_v_resamp_set_cell_match.rds')))
# read in 1as population data
(popDT<-readRDS(paste0('data/',ctry,'/',ctry,'_cell_orig_pop.rds')))
# merge the population data with the 15as cells
(popDT2<-merge(setmatchDT,popDT,by='cell_orig'))
# for each 15as cell, sum the population; if none, return missing
(popDT2<-popDT2[,list(pop=ifelse(all(is.na(pop)),NA_real_,sum(pop,na.rm=T))),by='cell_resamp'])
# merge population data with ID information
(matchdt<-merge(matchdt,popDT2,all.x=T,by='cell_resamp'))

# remove unnecessary
rm(xyDT,setmatchDT,popDT,popDT2);gc()

# specify directory for saving data
(outdir<-paste0('data/',ctry,'/VIIRS/thresh_lit/'))
# create directory
dir.create(outdir,showWarnings=F,recursive=T)

# for each year
for(YYYY in 2012:2017){
  # state which year we're working on
  message(paste("working on",YYYY))
  # get the national electrification rate for the country from the World Bank data
  (natl_elec_rate<-eratedat[`Country Name`==country][[as.character(YYYY)]]/100)
  # read in the mean rade9 data
  (r9lmdtrf<-readRDS(paste0("data/",ctry,"/VIIRS/daily/",ctry,"_good_r9_musd_",YYYY,".rds")))
  # keep only settlement data and the means
  (r9lmdtrf<-r9lmdtrf[grep('s',id),list(id,r9m,r9lm)])
  # if the national electrification rate is less than 1
  if(natl_elec_rate<1){
    # merge population data with rade9 mean data
    (r9lmdtr<-merge(na.omit(matchdt[,list(id,pop)]),r9lmdtrf,by='id'));gc()
    # order by mean logged rade9
    setorder(r9lmdtr,r9lm)
    # generate percentage of population for each cell
    set(r9lmdtr,NULL,'prppop',r9lmdtr[['pop']]/sum(r9lmdtr[['pop']]))
    # create a running sum vector
    set(r9lmdtr,NULL,'prppopcs',cumsum(r9lmdtr[['prppop']]))
    # create index vector of whether the percentage of the population lit exceeds 1 - the national electrification rate
    set(r9lmdtr,NULL,'prppopcsgrerate',r9lmdtr[['prppopcs']]>(1-natl_elec_rate))
    # create a cumulative sum of this vector
    set(r9lmdtr,NULL,'prppopcsgreratecs',cumsum(r9lmdtr[['prppopcsgrerate']]))
    # get the minimum mean logged rade9 that corresponds to being electrified
    (lit_thresh_r9lm<-r9lmdtr[prppopcsgreratecs==1L][['r9lm']])
    # create "lit" vector of 0s
    set(r9lmdtrf,NULL,'lit',0L)
    # set "lit" to 1 if it exceeds the minimum mean loged rade9 to be considered lit
    set(r9lmdtrf,r9lmdtrf[,.I[r9lm>lit_thresh_r9lm]],which(names(r9lmdtrf)=='lit'),1L)
    # save data of id and lit status
    saveRDS(r9lmdtrf[,list(id,lit)],paste0(outdir,ctry,'_set_id_lit_wb_erate_pop_',YYYY,'.rds'))
    # create a data.table of various statistics
    (erdt_natl<-data.table(natl_e_rate=natl_elec_rate,prp_15as_set_lit=sum(r9lmdtrf[['lit']])/nrow(r9lmdtrf),r9m_lit_thresh=r9lmdtr[prppopcsgreratecs==1L][['r9m']],r9lm_lit_thresh=lit_thresh_r9lm))
    rm(r9lmdtr)
  # otherwise
  } else {
    # define all settlement cells as lit
    set(r9lmdtrf,NULL,'lit',1L)
    # save this information
    saveRDS(r9lmdtrf[,list(id,lit)],paste0(outdir,ctry,'_set_id_lit_wb_erate_pop_',YYYY,'.rds'))
    # create the statistics data.table
    (erdt_natl<-data.table(natl_e_rate=1,prp_15as_set_lit=1,r9m_lit_thresh=min(r9lmdtrf[['r9m']]),r9lm_lit_thresh=min(r9lmdtrf[['r9lm']])))
  }
  # save the statistics data.table
  saveRDS(erdt_natl,paste0(outdir,ctry,'_natl_e_rate_',YYYY,'.rds'))
  # remove unnecessary and announce that year is done
  rm(erdt_natl,r9lmdtrf);gc()
  message(paste('finished',YYYY))
}
