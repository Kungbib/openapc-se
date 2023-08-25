# Exctract data from Open APC DE for Sweden

library(tidyverse)
library(readxl)
library(openxlsx)
library(yaml)

config <- yaml.load_file("open_apc_config.yml")

year_to_analyse = 2022

# read data from Open APC DE
de_data <- read_csv("https://raw.githubusercontent.com/OpenAPC/openapc-de/master/data/apc_de.csv")

# read organisations from Forskningssamverkansstatistik/help_files
org_help_table <- read_xlsx(config$org_help_file[1])

# filter SWE data
swe_data <- filter(de_data, institution %in% org_help_table$open_apc_name)
# create test table compare institutions
summary_swe_data <- filter(swe_data, period == year_to_analyse) %>% 
    count(institution) 

# write csv to repo
write_csv(swe_data, "data/apc_swe.csv")

# write Excel-fil for Bibsam on Forskningssamverkansstatistik
write.xlsx(swe_data, config$xlsx_file[1])
