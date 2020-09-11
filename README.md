# High Resolution Electricity Access (HREA) Indicators
**New Methods to Estimate Electricity Access Using Nightly VIIRS Satellite Imagery**

Brian Min (brianmin@umich.edu)

Zachary O’Keeffe (zokeeffe@umich.edu)

University of Michigan


Rev. September 2020

# Introduction

We introduce a new method to generate likelihood estimates of electricity access for all areas with human settlements within a country by identifying statistical anomalies in brightness values that are plausibly associated with electricity use, and unlikely to be due to exogenous factors.

On every night, the VIIRS DNB sensor collects data on the observed brightness over all locations within a country, including over electrified and unelectrified areas, and populated and unpopulated areas. Our objective is to classify populated areas as electrified or not using all the brightness data over a country. But the challenge is that light output can be due to multiple sources unrelated to electricity use. Notably, the VIIRS sensor is so sensitive that it picks up light from overglow, atmospheric interactions, moonlight, and variations in surface reflectivity across types of land cover. We refer collectively to these exogenous sources as background noise, which must be accounted for to classify whether an area is brighter than expected.

We use data on light output detected over areas with no settlements or buildings to train a statistical model of background noise. The model can be used to generate an expected brightness value on every given night for every given location. We then compare the observed brightness on each night against the expected baseline brightness value. Areas with human settlements with brighter light output than expected are assumed to have access to electricity on that night. We classify all settlements on all nights and then average the estimates and generate an "Artificial Light Score" for each calendar year for all settlement areas. Areas that are much brighter than would be expected on most nights have the highest probability of being electrified. Areas that are as dim as areas with no settlements have the lowest probability of being electrified. And areas that are a little brighter on some nights have middling scores.

The advantage of this process is that it uses all available nightly data from the VIIRS data stream while taking into account sources of known noise and variability. The process also allows for the identification of areas where the likelihood of electricity access and use is uncertain (the areas with middling scores). This is significant given that traditional binary measures of access do not account for variations in levels of use or reliability of power supply, even across areas that are all nominally electrified. These data may therefore be helpful in identifying baseline variations in access and reliability within countries, consistent with the objectives of the Multi-tier Framework for measuring energy access (ESMAP 2015).

We explain the process in more detail below:

1. **Select random sample of locations with no settlements to measure background noise.**
We select a stratified random sample of isolated non-settlement pixels, which are identified by overlaying the 1 arcsecond (as) settlement pixel grid on the 15 as VIIRS grid. Candidate 15 as pixels are those that 1) contain zero 1 as settlement pixels; and 2) are not adjacent to any 15 as cells containing settlement cells. We stratify based on the type of land, selecting up to 500 pixels per category. As there are 17 categories, the theoretical maximum is 8,500.
1. **Select observations.**
Following NOAA guidelines and their data quality flags, we drop bad quality data, including those with heavy cloud cover and excessive sensor noise. NOAA also drops many nights with high lunar illumination. We relax this threshold slightly and keep nightly observations where lunar illumination is below .001 lux. Furthermore, on nights with multiple overpasses, we use data with the earliest local timestamp for settlement points, but allow multiple observations for non-settlement points. 
1. **Remove outliers.**
To generate a reliable estimate of background noise, we need to exclude outliers. Presumably, unusually high brightness values in unsettled areas are not due to background noise. To accomplish this, we first apply a logarithmic transformation to observed brightness to make the distribution more normal. Then we calculate the median and standard deviation. Observations are removed if they are above 4 standard deviations from the median on this metric. Then we stratify by land type and date, and, using the original scale, calculate the mean and standard deviation. Observations that are above 4 standard deviations above the mean are removed.
1. **Create statistical model of background noise.** 
For each calendar year, we run a linear mixed effects model to learn the impacts of exogenous factors using all non-settlement data from all good quality nights, for all years (2012–2017). There is a single random effect: date. There are five fixed effects: lunar illumination, local time, calendar month, land type, and the interaction between land type and lunar illumination (plus an intercept). Notably, the regression diagnostics are excellent. Outliers are not present, the linear relationships specified hold well, and heteroskedasticity is not an issue. The distributions look normal, constant, and linear.
Using the statistical parameters learned from data on non-settlement areas, we then calculate the expected level of light output for all areas with settlements. These predicted values represent a counterfactual estimate of how much light would be expected on that specific day on that type of land, if the only sources of light were from background noise and other exogenous factors. Areas with consistently higher observed light output than expected are assumed to have electricity access. 
1. **Identify electrified settlement areas on each night.**
We compare observed levels of light output against the statistically estimated baseline light output level for every settlement pixel on every night. This generates residuals which we standardize by dividing by the sigma from the model (the standard deviation of residuals, with a degrees of freedom adjustment) to generate z-scores for each pixel on each night. Higher z-scores imply much higher light output than expected. We assume that higher scores are correlated with higher likelihood that a settlement is using electricity on that specific night. 
1. **Aggregate nightly estimates to generate "Artificial Light Score" values for all settlement areas for each year.**
For each year, we average all nightly z-scores for each settlement cell. We then calculate the corresponding quantile value assuming a standard normal distribution, which transforms the average z-score to be between 0 and 1. We then subtract .5 from this value, divide the result by .5, and set negative values to 0. This produces annual Artificial Light Scores for each pixel, which also lie between 0 and 1. On this scale, .95 roughly corresponds to having observed light scores that are on average above 2 standard deviations from expected. Meanwhile, 0 corresponds to having observed radiance values that are on average lower than the expected values for comparable isolated non-settlement pixels.

This GitHub repository contains several R scripts that are used to produce these high resolution settlement electrification estimates for a given country. Additional output includes annual composite GeoTIFFs of visible light. Many of the scripts pull variables from the environment (the required variables are specified at the top of the scripts). They are written in a way that allows the user to specify the time and country from the command line, and then submit the script as a job to a computer cluster (these scripts require quite a lot in the way of resources like memory and processor power, and may take a long time to run). Descriptions of required files and what each script does can be found below.

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
