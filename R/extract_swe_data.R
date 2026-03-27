# Exctract data from Open APC DE for Sweden

library(tidyverse)
library(readxl)
library(openxlsx)
library(yaml)

config <- yaml.load_file("open_apc_config.yml")

year_to_analyse = 2024

# read data from Open APC DE
de_data <- read_csv("https://raw.githubusercontent.com/OpenAPC/openapc-de/master/data/apc_de.csv")

currency_converter <- read_xlsx("~/r/repos/normalisera_forlagsdata/admin_files/currency_converter.xlsx") %>% 
    filter(currency == "EUR") %>% 
    select(-c("currency", "conversion_to"))

# org_in_de_data <- select(de_data, institution) %>% distinct()

# read organisations from Forskningssamverkansstatistik/help_files
org_help_table <- read_xlsx(config$org_help_file[1])

# filter SWE data
swe_data <- filter(de_data, institution %in% org_help_table$open_apc_name) %>% 
    arrange(institution, period)

# create test table compare institutions
summary_swe_data <- filter(swe_data, period == year_to_analyse) %>% 
    count(institution) 

# write csv to repo
write_csv(swe_data, "data/apc_swe.csv")

# write Excel-fil for Bibsam on Forskningssamverkansstatistik
write.xlsx(swe_data, config$xlsx_file[1])


# prep OpenAPC workshop ---------------------------------------------------

sum_over_years <- filter(swe_data, period > 2016) %>% 
    anti_join(bibsam_data, by = "doi") %>% 
    group_by(period, is_hybrid) %>% 
    summarize(n = n(),
              amount = sum(euro)) %>% 
    left_join(currency_converter, by = c("period" = "year")) %>% 
    mutate(amount_sek = amount * conversion)

write.xlsx(sum_over_years, "temp/workshop_oct_2025.xlsx")

ggplot(filter(sum_over_years), aes(x = period)) + 
    geom_line(aes(y = n))
 
             