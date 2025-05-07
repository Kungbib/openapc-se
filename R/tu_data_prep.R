# prepare data for Totala utgifter

library(tidyverse)
library(readxl)
library(openxlsx)
library(yaml)
library(janitor)

tu_year <- 2024
tu_result_file <- paste("data/tu_", tu_year, ".csv", sep = "")
tu_summary_file <- paste0("result_files/tu_summary_", tu_year, ".xlsx")
conversion_rate <- 0.0875 # 0.0871 # 0.094 # rate euro to sek

# institutions not delivering to Open APC "Mid Sweden University", "Kristianstad University", 
non_tu_institutions <- c("Chalmers", "RISE Research Institutes of Sweden",
                         "Swedish National Road and Transport Research Institute", "Umeå University", "Swedish Defence University")
# institutions without MDPI agreement
mdpi_no_aggreement_institutions <- c("BTH Blekinge Institute of Technology", "Jönköping University", "Karolinska Institutet",
                                     "Stockholm School of Economics", "Södertörns University", "University of Gothenburg", "University of Skövde",
                                     "University West", "Uppsala University")

mdpi_agreement_institutions <- c("Lund University", "Stockholm University", "KTH Royal Institute of Technology",
                                 "Linköping University", "Swedish University of Agricultural Sciences", "Örebro University",
                                 "Luleå University of Technology", "Linnaeus University", "Karlstad University", 
                                 "Mid Sweden University", "Dalarna University", "Mälardalen University", "University of Gävle",
                                 "University of Borås", "Kristianstad University", "Swedish School of Sport and Health Sciences",
                                 "Halmstad University")

# open_apc_institutions <- filter(org_help_table, !is.na(open_apc_name)) 
# test <- paste(open_apc_institutions$open_apc_name)

# mdpi_no_aggreement_institutions <- c("Halmstad University", "Jönköping University", "Karolinska Institutet",
#                                      "Stockholm School of Economics", "Södertörns University", "University of Gothenburg", "University of Skövde", 
#                                      "University West", "Uppsala University")

# frontiers_no_agreement_institutions <- c("BTH Blekinge Institute of Technology", "Dalarna University", 
#                                          "Jönköping University", 
#                                          "Karolinska Institutet", "Linköping University", "University of Skövde", "University West",
#                                          "Örebro University")

# plos_no_agreement_institutions <- c("BTH Blekinge Institute of Technology", "Dalarna University", "Halmstad University", 
#                                     "Jönköping University", "Karlstad University", "Luleå University of Technology",
#                                     "Lund University", "Malmö University", "Södertörns University", "University of Borås",
#                                     "University of Skövde", "University West")

# publishers with only gold journals
gold_publishers <- c("MDPI AG", "Frontiers Media SA", "Public Library of Science (PLoS)", "JMIR Publications Inc.", 
                     "MJS Publishing, Medical Journals Sweden AB", "eLife Sciences Publications, Ltd", "Copernicus GmbH")

ot_publishers <- c("Frontiers Media SA", "Public Library of Science (PLoS)", "JMIR Publications Inc.", 
                   "MJS Publishing, Medical Journals Sweden AB", "eLife Sciences Publications, Ltd", "Copernicus GmbH")

# select TU year from apc_swe-data (to prepare swe_data see script extract_swe_data.R)
swe_data <- read_csv("data/apc_swe.csv") %>% 
    filter(period == tu_year)

# read data from oa-tskr/Bibsam_artikeldata
# glöm inte att uppdatera raw-länk om Github uppdaterats (annars http fel 404)
# bibsam_data <- read_csv("https://raw.githubusercontent.com/Kungbib/oa-tskr/master/Bibsam_artikeldata/19_23_bibsam_data.csv")
bibsam_data <- read_csv("/Users/2021m30/R/repos/normalisera_forlagsdata/result_files/19_24_bibsam_data.csv") %>% 
    mutate(doi = str_to_lower(str_remove(doi, "https://doi.org/")))

# clean for overlap
tu_data <- anti_join(swe_data, bibsam_data, by = c("doi"), na_matches = "never") %>% 
    filter(publisher != "MJS Publishing, Medical Journals Sweden AB" )

# test <- semi_join(swe_data, bibsam_data, by = c("doi"), na_matches = "never") %>%
#     filter(period == tu_year)

# sheet_names <- list("Summary" = ot_publishers_data_sum, "Data" = ot_publishers_data)
# 
# write.xlsx(sheet_names, "temp/ot_forlag.xlsx")

# tu_data_summary <- group_by(tu_data, publisher, institution) %>% 
#     count()
# 
# tu_bibsam_overlap <- semi_join(swe_data, bibsam_data, by = c("doi"), na_matches = "never")
# 
# bibsam_overlap_summary <- group_by(tu_bibsam_overlap, publisher, institution) %>% 
#     count()

# convert euro to sek
tu_data_final <- mutate(tu_data, sek  = round(euro/conversion_rate, 2)) %>% 
    relocate(sek, .after = `period`) %>% 
    select(-c(euro))

write_csv(tu_data_final, tu_result_file)

tu_data_summary <- filter(tu_data_final, !(publisher %in% gold_publishers)) %>% #filter(tu_data_final, publisher != "MDPI AG") %>% 
    group_by(institution) %>% 
    summarise(totalt = round(sum(sek), 0))

ot_publishers_data <- filter(tu_data_final, period == tu_year & publisher %in% ot_publishers) 

ot_publishers_data_sum <- group_by(ot_publishers_data, institution) %>% 
    summarize(ot_forlag_outside_agreement = round(sum(sek, na.rm = TRUE), 0))

ot_publishers_in_bibsam <- filter(bibsam_data, year_paid == tu_year & publisher %in% c("frontiers", "plos","jmir", "elife", "copernicus","mjs"))

ot_publishers_total_2024 <- tribble(
    ~forlags_typ, ~ antal,
    "ÖT-förlag i Bibsam", nrow(ot_publishers_in_bibsam),
    "ÖT-förlag utanför avtal", nrow(ot_publishers_data),
    "MDPI i Bibsam", nrow(mdpi_bibsam_orig),
    "MDPI i OpenAPC", nrow(mdpi_not_in_bibsam)
) %>% 
    adorn_totals("row", name = "Totalt")

# MDPI from Open APC ------------------------------------------------------



# mdpi from open_apc - non agreement institutions
mdpi_open_apc <- tu_data_final %>% 
    filter(period == 2024 & publisher == "MDPI AG") 

mdpi_open_apc_agreement_inst <- filter(mdpi_open_apc, institution %in% mdpi_agreement_institutions)

write.xlsx(mdpi_open_apc_agreement_inst, "temp/mdpi_open_apc_inst_m_avtal.xlsx")
# %>% 
#     filter(institution %in% mdpi_no_aggreement_institutions) 

mdpi_open_apc_per_org <- group_by(mdpi_open_apc, institution) %>% 
    summarise(mdpi_open_apc = round(sum(sek, na.rm = TRUE), 0))


# mdpi from Bibsam - agreement institutions data from ÅRSFILER to get what they actueall paid
mdpi_bibsam_orig <- read_xlsx("~/r/repos/normalisera_forlagsdata/ÅRSFILER 2024/mdpi_2024.xlsx") %>% 
    clean_names()

mdpi_not_in_bibsam <- anti_join(mdpi_open_apc, mdpi_bibsam_orig, by = c("doi"))

currencies <- read.xlsx("~/r/repos/normalisera_forlagsdata/admin_files/currency_converter.xlsx") %>% 
    filter(year == 2024) %>% 
    select(currency, conversion)

mdpi_bibsam_org <- left_join(mdpi_bibsam_orig, currencies, by = c("currency") )%>% 
    mutate(invoiced_amount = invoiced_amount_without_vat) %>% 
    mutate(invoiced_amount_sek = invoiced_amount * conversion) %>% 
    select(doi, ioap_name, currency, invoiced_amount, conversion, invoiced_amount_sek)

mdpi_bibsam_per_org <- group_by(mdpi_bibsam_org, ioap_name) %>% 
    summarise(mdpi_agreement = round(sum(invoiced_amount_sek, na.rm = TRUE), 0)) %>% 
    filter(!(ioap_name %in% non_tu_institutions)) %>% 
    rename(institution = ioap_name) %>% 
    mutate(institution = case_when(institution == "Blekinge Institute of Technology" ~ "BTH Blekinge Institute of Technology",
                                   institution == "Swedish School of Sport and Health Sciences, GIH" ~ "Swedish School of Sport and Health Sciences",
                                   institution == "Swedish University of Agricultural Sciences (SLU)" ~ "Swedish University of Agricultural Sciences",
                                   TRUE ~ institution))

mdpi_all <- full_join(mdpi_open_apc_per_org, mdpi_bibsam_per_org, by = c("institution")) %>% 
    mutate(across(everything(), replace_na, 0 )) %>% 
    mutate(mdpi = mdpi_open_apc + mdpi_agreement) %>% 
    add_row(institution = "Södertörns University", mdpi_open_apc = 0, mdpi_agreement = 0, mdpi = 0) %>% 
    add_row(institution = "Stockholm School of Economics", mdpi_open_apc = 0, mdpi_agreement = 0, mdpi = 0) %>% 
    select(institution, mdpi)

tu_summary <- full_join(tu_data_summary, mdpi_all, by = c("institution")) %>% 
    full_join(ot_publishers_data_sum, by = c("institution")) %>% 
    mutate(across(everything(), replace_na, 0)) %>% 
    mutate("Totalt per lärosäte" = totalt + ot_forlag_outside_agreement + mdpi) %>% 
    relocate(ot_forlag_outside_agreement, .before = mdpi) %>% 
    mutate(mdpi_typ = if_else(institution %in% mdpi_agreement_institutions, "avtal", "ej avtal")) %>% 
    arrange(institution) %>% 
    adorn_totals("row", name = "Totalt") %>% 
    rename("Lärosäte" = institution,
           "OpenAPC" = totalt,
           "ÖT-förlag utanför avtal" = ot_forlag_outside_agreement,
           "MDPI" = mdpi,
           "MDPI typ" = mdpi_typ)

write.xlsx(tu_summary, tu_summary_file)

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

mdpi_bibsam_2023 <- bind_rows(mdpi_2023_bibsam_org, mdpi_2023_bth_mau)

mdpi_open_apc_2023 <- filter(swe_data, period == 2023 & publisher == "MDPI AG")

mdpi_2023_open_apc_only <- anti_join(mdpi_open_apc_2023, mdpi_bibsam_2023, by = "doi")

mdpi_total_2023 <- nrow(mdpi_bibsam_2023) + nrow(mdpi_2023_open_apc_only)

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


# # Frontiers Open APC -------------------------------------------------------
# frontiers_open_apc <- tu_data %>% 
#     filter(period == 2023 & publisher == "Frontiers Media SA") %>% 
#     filter(institution %in% frontiers_no_agreement_institutions) 
# 
# frontiers_open_apc_per_org <- group_by(frontiers_open_apc, institution) %>% 
#     summarise(Frontiers = round(sum(sek, na.rm = TRUE), 0)) %>% 
#     add_row(institution = "Dalarna University", Frontiers = 0) %>% 
#     add_row(institution = "University West", Frontiers = 0) %>% 
#     add_row(institution = "Örebro University", Frontiers = 0) %>% 
#     arrange(institution)
# 
# 
# 
# # PLOS Open APC -----------------------------------------------------------
# 
# 
# plos_open_apc <- tu_data %>% 
#     filter(period == 2023 & publisher == "Public Library of Science (PLoS)") %>% 
#     filter(institution %in% plos_no_agreement_institutions) 
# 
# plos_open_apc_per_org <- group_by(plos_open_apc, institution) %>% 
#     summarise(PLoS = round(sum(sek, na.rm = TRUE), 0)) %>% 
#     add_row(institution = "BTH Blekinge Institute of Technology", PLoS = 0) %>% 
#     add_row(institution = "Halmstad University", PLoS = 0) %>% 
#     add_row(institution = "Malmö University", PLoS = 0) %>% 
#     add_row(institution = "University of Borås", PLoS = 0) %>% 
#     add_row(institution = "University of Skövde", PLoS = 0) %>% 
#     add_row(institution = "University West", PLoS = 0) %>% 
#     arrange(institution)



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
