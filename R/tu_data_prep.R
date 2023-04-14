# prepare data for Totala utgifter

library(tidyverse)
library(readxl)
library(openxlsx)
library(yaml)

tu_year = 2022
conversion_rate = 0.094 # rate sek to euro, use average between conversion rates KI and others

# select TU year from apc_swe-data
swe_data <- read_csv("result_files/apc_swe.csv") %>% 
    filter(period == tu_year)

# read data from oa-tskr/Bibsam_artikeldata
bibsam_data <- read_csv("https://raw.githubusercontent.com/Kungbib/oa-tskr/master/Bibsam_artikeldata/19_21_bibsam_data.csv")

# clean for overlap
tu_data <- anti_join(swe_data, bibsam_data, by = c("doi"), na_matches = "never")

# tu_bibsam_overlap <- semi_join(swe_data, bibsam_data, by = c("doi"))

# convert euro to sek
tu_data <- mutate(tu_data,
                  sek  = round(euro/conversion_rate, 2)
                  ) %>% 
    relocate(sek, .after = `period`) %>% 
    select(-c(euro))

# eventuell normalisering av filer för data.kb.se
