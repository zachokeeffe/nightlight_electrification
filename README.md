# Introduction

This GitHub repository contains several R scripts that are used to produce high resolution settlement electrification estimates for an input country. Additional output includes annual composite GeoTIFFs of visible light.

# Required Files

The scripts here assume the user has access to several files. These include:

## FB_countries.csv

This matches "short" names of countries to "long" names. The short names of countries are the names of the country folders, while the long names are the names used in the World Bank electrification estimates spreadsheet.

## pct_pop_w_electricity_1990-2017.csv

This CSV contains estimates of access to electricity as a percentage of the population per country, from 1990-2017. Data are obtained from the World Bank's Sustainable Energy for All database: https://data.worldbank.org/indicator/EG.ELC.ACCS.ZS.

## new_good_vflag_ints_no_li.txt

This is a text file with all the VIIRS flag integers corresponding to "good" values (the values that are to be kept in the extraction process).

## Country Boundary Shapefile (filename varies by country)

This is an ESRI Shapefile of the country boundary. It is used to create edited settlement GeoTIFFs, as well as determine which VIIRS images overlap with the country. Files are taken from GADM: https://gadm.org/download_country_v3.html.

## High Resolution Population Density Maps (filename varies by country)

These 1 arcsecond (as) GeoTIFFs identify where people live. These "settlement" layers also contain population estimates per cell. Data are provided by Facebook: https://data.humdata.org/organization/facebook?res_format=zipped%20geotiff&q=&ext_page_size=25.

# Description of Scripts

The following describes the files contained on this GitHub repository. The files should be executed in the order they are described; subsequent scripts require output from previous ones.

## 0_convert_country_boundary_to_coordinate_lines.R

Reformats country boundary shapefile.

## 1_make_settlement_rasters.R

Creates 1 and 15 arc second settlement rasters using the Facebook High Resolution Settlement Layer files and country boundary shapefile. Cells with settlements are populated with 1s, with the rest of the cells coded as empty.

## 2.0_gen_country_VIIRS_XYs.R

Creates data.tables of cell information. Specifically, one is created that matches 1as settlement cells to 15as cells. Two others store long-lat information associated with 15as cells, for settlement and non-settlement cells. A final data.table is created that includes both settlement and non-settlement cells, their long-lat information, and unique identifiers.

## 2.1_make_country_lon_tz_offset_files.R

Creates a data.table of "local" time offsets for each 15as cell in the country based on longitude.

## 2.2_get_pop_per_1as_cell.R

Extracts population estimates from original FB raster for each 1as settlement cell.

## 2.3_make_prp_set_per_cell.R

Calculates the proportion of each 15as cell that is populated with 1as settlement cells.

## 3_find_overlapping_VIIRS_TIFFs.R

Determines which VIIRS GeoTIFFs overlap with the country boundary.

## 4.1_find_overlapping_landcover_tiles.R

Determines which landcover tiles overlap with the country boundary.

## 4.2_extract_xy_landcover_values.R

Extracts land type values for each 15as cell in the country.

## 5_extract_good_daily_VIIRS_data.R

For a given month, extracts data from the VIIRS GeoTIFFs for all country cells and stores them as RDS files. Specifically, it extracts data from the li (lunar illumination), vflag (quality flag), rade9 (visible radiance), rad (infrared radiance), and sample position. "High-quality" data are returned by month and saved as separate files. In the end, for each month of data, a column of a data.table is saved for the: id, day, stime (start time of image), rade9, rad, li, and sample.

## 6_find_good_times.R

Converts image capture start time to "local" times. Along with storing this data by month, it also creates vectors that identify, for each date, the earliest timestamped image in case of overlap.

## 7_gen_r9_musd.R

For each year, reads in data and subsets. Data are dropped if the timestamp is "bad" (see previous script) or if the lunar illumination (LI) is above .0005. A logged version of the visible light (rade9) is created. Then, for each 15as cell, the mean and standard deviation of rade9 and its logged version are created and saved as a data.table. These values are used in the following script to generate 15as annual composite GeoTIFFs of visible light.

## 8_make_VIIRS_average_raster.R

For a year, creates a GeoTIFF of the 15as country cells with the values of the mean logged rade9 (mean logged rade9 is chosen over mean rade9 because of the highly skewed nature of observed light).

## 9.0_gen_set_elec_based_on_year_wb_val.R

Generates files that identify whether a settlement cell should be classified as "lit" or not based on World Bank classifications, combined with population and visible light data. Also creates tables with the following statistics: electrification rate according to World Bank data, proportion of 15as cells that are considered electrified, and the minimum mean logged rade9 and rade9 values that count as electrified.

## 9.1_make_set_lit_rasters_wb_erate.R

Creates 1as country settlement cell GeoTIFFs for each year, where 0 represents an unelectrified settlement cell, and 1 represents an electrified settlement cell, based on World Bank electrification estimates and interpolated population.

## 10.0_find_nearby_set_cells.R

Determines, for each cell, how many settlement cells are adjacent. The purpose is to find isolated non-settlement cells, which are presumed to be dark.

## 10.1_prep_nset_dat_for_r9_regs.R

Prepares nonsettlement cell data for the regression. Data are subsetted based on lunar illumination, and outliers are removed based on their mean and standard deviation.

## 10.1_prep_nset_dat_for_r9_regs_bigcountry.R

This is a different version of the previous script that works with large countries (the previous one will fail for certain large countries).

## 10.2_prep_set_dat_for_r9_regs.R

Prepares settlement data for the regressions. Data are subsetted based on lunar illumination and timestamp.

## 10.3_multiyear_reg.R

Further removes outliers on the nonsettlement data and fits a linear mixed-effects model predicting light output from the timestamp, date, lunar illumination, and land type.

## 10.4_reg_resids.R

Predicts the light output of settlement cells assuming they behaved like nonsettlement cells. The difference (the regression residuals) form the basis for determining whether cells are considered electrified or not.

## 10.5_make_reg_set_lit_rasters.R

Creates 1as GeoTIFFs of settlement cells with values corresponding to their electrification scores. Multiple metrics are employed.

## 10.6_comp_reg_w_wb_erate.R

Compares the population weighted electrification status of settlement cells as calculated from the regressions with the values reported by the World Bank by year for a given country.
