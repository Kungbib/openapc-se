# script for initial format check etc for incoming files with data for Open APC Initiative
# Johan Fröberg 

# required libraries ------------------------------------------------------
library(tidyverse)
library(readxl)

# clean environment when doing several consecutive runs, keep bibsam- and openapc-data
rm(doi_check, doi_dubbletter_all,
   indata_file, organisation, timeperiod_data, 
   check_org_period, indata, high_apcs, check_column_names)

# definitions of column names and types
column_names <- c("institution", "period", "sek", "doi", "is_hybrid", "publisher", "journal_full_title", "issn", "issn_print", "issn_electronic", "url")
column_types <- c("text", "numeric", "numeric", "text", "logical", "text", "text", "text", "text", "text", "text")

# settings: change before running -----------------------------------------

# what organisation, short name? ex kth
organisation <- 'hig'

# data collected from which timeperiod? ex 2010-2019, 2020_Q1
timeperiod_data <- '2024'

# what's the name of the file or files to be converted?
indata_file <- str_c('data/', organisation, '/original_data/HIG_APC_2024.xlsx')

outdata_file <- str_c('data/',organisation,'/','apc_',organisation,'_',timeperiod_data,'.csv')

# check of incoming file -------------------------------------------------
# code to represent check list in Handbok_openapcsweden

# reads indata file, gives error if number of columns are incorrect, if so add missing columns in excel
indata <- read_xlsx(indata_file, col_types = column_types)

# # if multiple indata fiels
# indata <- bind_rows(read_xlsx(indata_file, col_types = column_types), read_xlsx(indata_file2, col_types = column_types))

# # csv import
# indata <- read_csv2(indata_file)

# # add columns if only five supplied
# indata <- mutate(indata,
#                  publisher = NA,
#                  journal_full_title = NA, 
#                  issn = NA,
#                  issn_print = NA,
#                  issn_electronic = NA, 
#                  url = NA)

# check column names creates character string with wrong names
check_column_names <- setdiff(colnames(indata), column_names) 

# if wrong names, rename all column names to correct
indata <- rename_with(indata, ~ column_names)

# check organisation and period
check_org_period <- filter(indata, period != timeperiod_data | institution != organisation)

# # set correct organisation and period
# indata <- mutate(indata, 
#                  institution = organisation, 
#                  period = timeperiod_data)

# find spaces in doi
doi_check <- subset(indata, str_detect(doi, "[\\s]"))
# # remove spaces in doi and change doi to right format
# indata <- mutate(indata, 
#                  # doi = str_replace(doi, "https://", ""),
#                  doi = str_replace_all(doi, "[\\s]", ""),
#                  doi = if_else(str_starts(doi, "10."), doi, str_replace(doi, "^.*(?=10.*)", ""))
#                  )
# 
# 
# doi_check <- subset(indata, str_detect(doi, "[\\s]"))

# find doi duplicates, if != 0 resolve with organisation alter and start over 
# doi_dubbletter <- subset(indata, duplicated(doi)) # hittar doi_dubbletter
doi_dubbletter_all <- group_by(indata, doi) %>% 
    filter(n() > 1) %>% 
    ungroup() %>% 
    arrange(doi)

# find high apc:s, if any resolve with organisation
high_apcs <- filter(indata, sek > 80000)




