# prepare data for Totala utgifter

library(tidyverse)
library(readxl)
library(openxlsx)
library(yaml)

tu_year = 2022
tu_result_file = paste("data/tu_", tu_year, ".csv", sep = "")
conversion_rate = 0.094 # rate sek to euro, use average between conversion rates KI and others

# select TU year from apc_swe-data (to prepare swe_data see script extract_swe_data.R)
swe_data <- read_csv("data/apc_swe.csv") %>% 
    filter(period == tu_year)

# read data from oa-tskr/Bibsam_artikeldata
# glöm inte att uppdatera raw-länk om Github uppdaterats (annars http fel 404)
bibsam_data <- read_csv("https://raw.githubusercontent.com/Kungbib/oa-tskr/master/Bibsam_artikeldata/19_22_bibsam_data.csv")

# clean for overlap
tu_data <- anti_join(swe_data, bibsam_data, by = c("doi"), na_matches = "never")

# tu_bibsam_overlap <- semi_join(swe_data, bibsam_data, by = c("doi"))

# convert euro to sek
tu_data <- mutate(tu_data,
                  sek  = round(euro/conversion_rate, 2)
                  ) %>% 
    relocate(sek, .after = `period`) %>% 
    select(-c(euro))

write_csv(tu_data, tu_result_file)
