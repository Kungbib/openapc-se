# prepare data for Totala utgifter

library(tidyverse)
library(readxl)
library(openxlsx)
library(yaml)
library(janitor)

tu_year <- 2023
tu_result_file <- paste("data/tu_", tu_year, ".csv", sep = "")
tu_summary_file <- paste0("result_files/tu_summary_", tu_year, ".xlsx")
conversion_rate <- 0.0871 # 0.094 # rate sek to euro, use average between conversion rates KI and others

# institutions not delivering to Open APC
non_tu_institutions <- c("Chalmers", "Kristianstad University", "Mid Sweden University", "RISE Research Institutes of Sweden",
                         "Swedish National Road and Transport Research Institute", "Umeå University", "Swedish Defence University")
# institutions without MDPI agreement
mdpi_no_aggreement_institutions <- c("Halmstad University", "Jönköping University", "Karolinska Institutet",
                                     "Stockholm School of Economics", "Södertörns University", "University of Gothenburg", "University of Skövde", 
                                     "University West", "Uppsala University")

frontiers_no_agreement_institutions <- c("BTH Blekinge Institute of Technology", "Dalarna University", 
                                         "Jönköping University", 
                                         "Karolinska Institutet", "Linköping University", "University of Skövde", "University West",
                                         "Örebro University")

plos_no_agreement_institutions <- c("BTH Blekinge Institute of Technology", "Dalarna University", "Halmstad University", 
                                    "Jönköping University", "Karlstad University", "Luleå University of Technology",
                                    "Lund University", "Malmö University", "Södertörns University", "University of Borås",
                                    "University of Skövde", "University West")

# publishers with only gold journals
gold_publishers <- c("MDPI AG", "Frontiers Media SA", "Public Library of Science (PLoS)" )

# select TU year from apc_swe-data (to prepare swe_data see script extract_swe_data.R)
swe_data <- read_csv("data/apc_swe.csv") %>% 
    filter(period == tu_year)

# read data from oa-tskr/Bibsam_artikeldata
# glöm inte att uppdatera raw-länk om Github uppdaterats (annars http fel 404)
bibsam_data <- read_csv("https://raw.githubusercontent.com/Kungbib/oa-tskr/master/Bibsam_artikeldata/19_23_bibsam_data.csv")

# clean for overlap
tu_data <- anti_join(swe_data, bibsam_data, by = c("doi"), na_matches = "never")

# tu_data_summary <- group_by(tu_data, publisher, institution) %>% 
#     count()
# 
# tu_bibsam_overlap <- semi_join(swe_data, bibsam_data, by = c("doi"), na_matches = "never")
# 
# bibsam_overlap_summary <- group_by(tu_bibsam_overlap, publisher, institution) %>% 
#     count()

# convert euro to sek
tu_data <- mutate(tu_data, sek  = round(euro/conversion_rate, 2)
                  ) %>% 
    relocate(sek, .after = `period`) %>% 
    select(-c(euro))

write_csv(tu_data, tu_result_file)

tu_data_summary <- filter(tu_data, !(publisher %in% gold_publishers)) %>%
    group_by(institution) %>% 
    summarise(totalt = round(sum(sek), 0))

# MDPI from Open APC ------------------------------------------------------



# mdpi from open_apc - non agreement institutions
mdpi_open_apc <- tu_data %>% 
    filter(period == 2023 & publisher == "MDPI AG") %>% 
    filter(institution %in% mdpi_no_aggreement_institutions) 

mdpi_open_apc_per_org <- group_by(mdpi_open_apc, institution) %>% 
    summarise(mdpi = round(sum(sek, na.rm = TRUE), 0))


# mdpi from Bibsam - agreement institutions data from ÅRSFILER to get what they actually paid
mdpi_2023_bibsam_orig <- read_xlsx("~/r/repos/normalisera_forlagsdata/ÅRSFILER 2023/mdpi_2023.xlsx") %>% 
    clean_names() 

mdpi_2023_bibsam_org <- mdpi_2023_bibsam_orig %>% 
    mutate(currency = str_sub(actual_invoiced_amount, -3),
           actual_invoiced_amount_new = as.numeric(str_sub(actual_invoiced_amount, 1, -4))) %>%
    mutate(converter = case_when(currency == "EUR" ~ 11.4765,
                                 currency == "CHF" ~ 11.87173, 
                                 currency == "CAD" ~ 7.8637,
                                 currency == "USD" ~ 10.6128,
                                 TRUE ~ NA), 
           invoiced_amount_sek = actual_invoiced_amount_new * converter) %>% 
    select(doi, ioap_name = ioap, currency, actual_invoiced_amount_text = actual_invoiced_amount, actual_invoiced_amount = actual_invoiced_amount_new, converter, invoiced_amount_sek) 

mdpi_2023_bth_mau_orig <- read_xlsx("~/r/repos/normalisera_forlagsdata/ÅRSFILER 2023/mdpi_bth_malmo_2023.xlsx") %>% 
    clean_names()

mdpi_2023_bth_mau <- select(mdpi_2023_bth_mau_orig, doi, ioap_name, currency, actual_invoiced_amount) %>% 
    mutate(converter = if_else(currency == "EUR", 11.4765, 11.8173),
           invoiced_amount_sek = actual_invoiced_amount * converter,
           actual_invoiced_amount_text = str_c(actual_invoiced_amount, sep = " ", currency))

mdpi_2023 <- bind_rows(mdpi_2023_bibsam_org, mdpi_2023_bth_mau)

mdpi_bibsam_per_org <- filter(mdpi_2023, !is.na(invoiced_amount_sek)) %>% 
    group_by(ioap_name) %>% 
    summarise(mdpi = round(sum(invoiced_amount_sek, na.rm = TRUE), 0)) %>% 
    filter(!(ioap_name %in% non_tu_institutions)) %>% 
    rename(institution = ioap_name)

mdpi_2023_per_org <- bind_rows(mdpi_open_apc_per_org, mdpi_bibsam_per_org) %>% 
    arrange(institution) %>% 
    mutate(institution = case_when(institution == "Blekinge Institute of Technology" ~ "BTH Blekinge Institute of Technology",
                                   institution == "Swedish School of Sport and Health Sciences, GIH" ~ "Swedish School of Sport and Health Sciences",
                                   institution == "Swedish University of Agricultural Sciences (SLU)" ~ "Swedish University of Agricultural Sciences",
                                   TRUE ~ institution)) %>% 
    add_row(institution = "Södertörns University", mdpi = 0)

# Frontiers Open APC -------------------------------------------------------
frontiers_open_apc <- tu_data %>% 
    filter(period == 2023 & publisher == "Frontiers Media SA") %>% 
    filter(institution %in% frontiers_no_agreement_institutions) 

frontiers_open_apc_per_org <- group_by(frontiers_open_apc, institution) %>% 
    summarise(Frontiers = round(sum(sek, na.rm = TRUE), 0)) %>% 
    add_row(institution = "Dalarna University", Frontiers = 0) %>% 
    add_row(institution = "University West", Frontiers = 0) %>% 
    add_row(institution = "Örebro University", Frontiers = 0) %>% 
    arrange(institution)



# PLOS Open APC -----------------------------------------------------------


plos_open_apc <- tu_data %>% 
    filter(period == 2023 & publisher == "Public Library of Science (PLoS)") %>% 
    filter(institution %in% plos_no_agreement_institutions) 

plos_open_apc_per_org <- group_by(plos_open_apc, institution) %>% 
    summarise(PLoS = round(sum(sek, na.rm = TRUE), 0)) %>% 
    add_row(institution = "BTH Blekinge Institute of Technology", PLoS = 0) %>% 
    add_row(institution = "Halmstad University", PLoS = 0) %>% 
    add_row(institution = "Malmö University", PLoS = 0) %>% 
    add_row(institution = "University of Borås", PLoS = 0) %>% 
    add_row(institution = "University of Skövde", PLoS = 0) %>% 
    add_row(institution = "University West", PLoS = 0) %>% 
    arrange(institution)



# TU summary --------------------------------------------------------------


tu_summary <- left_join(tu_data_summary, mdpi_2023_per_org, by = "institution") %>% 
    mutate(mdpi_typ = if_else(institution %in% mdpi_no_aggreement_institutions, "ej avtal", "avtal")) %>% 
    add_row(institution = "Stockholm School of Economics", totalt = 0, mdpi = 0, mdpi_typ = "ej avtal") %>% 
    arrange(institution) %>% 
    rename("Lärosäte" = institution,
           "OpenAPC exkl. MDPI, Frontiers, PLoS" = totalt,
           MDPI = mdpi,
           MDPI_typ = mdpi_typ)

write.xlsx(tu_summary, tu_summary_file)
