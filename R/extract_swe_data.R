# Exctract data from Open APC DE for Sweden

library(tidyverse)
library(readxl)
library(openxlsx)

year_to_analyse = 2022

# read data from Open APC DE
de_data <- read_csv("https://raw.githubusercontent.com/OpenAPC/openapc-de/master/data/apc_de.csv")

# read organisations from Forskningssamverkansstatistik/help_files
org_help_table <- read_xlsx("/Volumes/Org-kataloger/Arbetsgrupper/Forskningssamverkanstatistik/help_files/orgs_tables.xlsx")

# filter SWE data
swe_data <- filter(de_data, institution %in% org_help_table$open_apc_name)
# create test table compare institutions
summary_swe_data <- filter(swe_data, period == year_to_analyse) %>% 
    count(institution) 

# write csv to repo
write_csv(swe_data, "result_files/apc_swe.csv")

# write Excel-fil for Bibsam on Forskningssamverkansstatistik
write.xlsx(swe_data, "/Volumes/Org-kataloger/Arbetsgrupper/Forskningssamverkanstatistik/for_bibsam/apc_swe.xlsx")
