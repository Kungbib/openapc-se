# Exctract data from Open APC DE for Sweden

library(tidyverse)
library(readxl)
library(openxlsx)
library(yaml)
library(janitor)

config <- yaml.load_file("open_apc_config.yml")

# read data from Open APC DE
de_apc_data <- read_csv("https://raw.githubusercontent.com/OpenAPC/openapc-de/master/data/apc_de.csv")

de_bpc_data <- read_csv("https://raw.githubusercontent.com/OpenAPC/openapc-de/master/data/bpc.csv")

# bibsam publication data
bibsam_data <- read_csv("/Users/2021m30/R/repos/normalisera_forlagsdata/result_files/19_24_bibsam_data.csv") %>% 
    mutate(doi = str_to_lower(str_remove(doi, "https://doi.org/")))

# currencies
currency_converter <- read_xlsx("~/r/repos/normalisera_forlagsdata/admin_files/currency_converter.xlsx") %>% 
    filter(currency == "EUR") %>% 
    select(-c("currency", "conversion_to"))

# read organisations from Forskningssamverkansstatistik/help_files
org_help_table <- read_xlsx(config$org_help_file[1])

# filter SWE data
swe_apc_data <- filter(de_apc_data, institution %in% org_help_table$open_apc_name) %>% 
    arrange(institution, period)

swe_bpc_data <- filter(de_bpc_data, institution %in% org_help_table$open_apc_name) %>% 
    arrange(institution, period)

# prep OpenAPC workshop ---------------------------------------------------

apc_sum_over_years <- filter(swe_apc_data, period > 2016) %>% 
    anti_join(bibsam_data, by = "doi") %>% 
    group_by(period, is_hybrid) %>% 
    summarize(n = n(),
              amount = sum(euro)) %>% 
    left_join(currency_converter, by = c("period" = "year")) %>% 
    mutate(amount_sek = amount * conversion)

write.xlsx(sum_over_years, "temp/workshop_oct_2025.xlsx")

ggplot(filter(sum_over_years), aes(x = period)) + 
    geom_line(aes(y = n))

bpc_sum_over_years <- swe_bpc_data %>% 
    group_by(period) %>% 
    summarize(n = n(),
              amount = sum(euro)) %>% 
    left_join(currency_converter, by = c("period" = "year")) %>% 
    mutate(amount_sek = amount * conversion)

sheets <- list("apc" = apc_sum_over_years, "bpc" = bpc_sum_over_years)
write.xlsx(sheets, "temp/workshop_oct_2025_all.xlsx")

mdpi_bibsam <- filter(bibsam_data, publisher == "mdpi")

mdpi_bibsam_sum_org_year <- group_by(mdpi_bibsam, year = year_paid, name_sve) %>% 
    count() %>% 
    ungroup() %>% 
    pivot_wider(names_from = year, values_from = n) %>% 
    rowwise() %>% 
    mutate(Totalt = sum(c_across(2:4), na.rm = TRUE)) %>% 
    arrange(desc(Totalt))

lu_mdpi_corr <- read.xlsx("~/r/repos/openapc-se/data/lu/corrections/mdpi_korr_2024.xlsx")

mdpi_open_apc <- filter(swe_apc_data, publisher == "MDPI AG", period >= 2020) %>% 
    anti_join(mdpi_bibsam, by = "doi") %>% 
    anti_join(lu_mdpi_corr, by = "doi") %>% 
    left_join(currency_converter, by = c("period" = "year")) %>% 
    mutate(amount_sek = euro * conversion) %>% 
    relocate(amount_sek, .after = euro) %>% 
    rename(year = period) %>% 
    select(-c(pmid, pmcid, ut, url, conversion, issn_print, issn_electronic, issn_l))

mdpi_open_apc_sum <- group_by(mdpi_open_apc, year, institution) %>% 
    count() %>% 
    ungroup() %>% 
    pivot_wider(names_from = year, values_from = n) %>% 
    rowwise() %>% 
    mutate(Totalt = sum(c_across(2:6), na.rm = TRUE)) %>% 
    arrange(desc(Totalt))

sheets <- list("mdpi_open_apc_org_year" = mdpi_open_apc_sum,
               "mdpi_open_apc_publ" = mdpi_open_apc,
               "mdpi_bibsam_org_year" = mdpi_bibsam_sum_org_year,
               "mpdi_bibsam_publ" = mdpi_bibsam)

write.xlsx(sheets, "~/Documents/bibsam/lisa/mdpi_251111.xlsx")
