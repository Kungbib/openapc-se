#chl 180216
#skript för att behandla excel-fil från Copernicus.
#blad 1, urval, läses in. I fliken rådata finns all data vi har fått från Copernicus.
#Bortvalda är:
#   gulmarkerade (dessa är betalda innan 2016 och pris finns ej)
#   rödmarkerade (betalade av andra, ibland inte svenska organisationer)
#   orangemarkerade (preprints)

library(tidyverse)
library(readxl)

copernicus <- read_excel("data/copernicus/copernicus_journals.xlsx", na = "-")
adjusted_copernicus <- copernicus %>%
    mutate(institution = str_extract(Affiliation,
                                   ("[[:alpha:]]+\\sUniversity|University\\sof\\sGothenburg|Royal\\sInstitute\\sof\\sTechnology|Blekinge\\sInstitute\\sof\\sTechnology"))) %>%
    rename(period = Year) %>%
    rename(euro = "Total net price") %>%
    rename(doi = DOI) %>%
    mutate(is_hybrid = FALSE) %>%
    mutate(publisher = "Copernicus") %>%
    select(institution, period, euro, doi, is_hybrid, publisher) %>%
    mutate(institution = stringr::str_replace(institution, "Swedish University", "Swedish University of Agricultural Sciences")) %>%
    mutate(institution = stringr::str_replace(institution, "Chalmers University", "Chalmers University of Technology")) %>%
    mutate(institution = stringr::str_replace(institution, "Luleå University", "Luleå University of Technology")) %>%
    mutate(institution = stringr::str_replace(institution, "Royal Institute of Technology", "KTH Royal Institute of Technology"))

org_acronyms <- read_tsv("data/org_acronym_name_map.tsv")

final_copernicus <- adjusted_copernicus %>%
    inner_join(org_acronyms, by = c("institution" = "organisation")) %>%
    select(-institution) %>%
    rename(institution = "acronym") %>%
    select(institution, period, euro, doi, is_hybrid, publisher) %>%
    arrange(institution)

write_tsv(final_copernicus, "data/copernicus/apc_copernicus_2016-2017.tsv")  
