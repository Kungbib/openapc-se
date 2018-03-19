#chl 180224
#skript för att behandla excel-fil från Springer Compact.
#bladet Approved YTD xxxx läses in.

library(tidyverse)
library(readxl)

springer_2017 <- read_xlsx("data/springer/apc_springer_2017.xlsx", sheet = "Approved YTD 2017", skip = 4)
#se till att inte filen är öppen i excel, ger fel "Evaluation error: zip file x cannot be opened.

adjusted_springer_2017 <- springer_2017 %>%
    select(Institution, DOI) %>%
    rename(institution = Institution, doi = DOI) %>%
    mutate(period = 2017, euro = 2200, is_hybrid = TRUE, publisher = "Springer") %>%
    mutate(institution = stringr::str_replace(institution, "Lulea University of Technology", "Luleå University of Technology")) %>%
    mutate(institution = stringr::str_replace(institution, "Royal Institute of Technology", "KTH Royal Institute of Technology")) %>%
    mutate(institution = stringr::str_replace(institution, "Dalarna University", "Dalarna University College")) %>%
    mutate(institution = stringr::str_replace(institution, "Halmstad University", "Halmstad University College")) %>%
    mutate(institution = stringr::str_replace(institution, "Jönköping University", "Jönköping University Foundation")) %>%
    mutate(institution = stringr::str_replace(institution, "Karolinska Institute", "Karolinska Institutet")) %>%
    mutate(institution = stringr::str_replace(institution, "Kristianstad University", "Kristianstad University College")) %>%
    mutate(institution = stringr::str_replace(institution, "Mälardalen University", "Mälardalen University College")) %>%
    mutate(institution = stringr::str_replace(institution, "Södertörn University", "Södertörns University College")) %>%
    mutate(institution = stringr::str_replace(institution, "Umea University", "Umeå University")) %>%
    mutate(institution = stringr::str_replace(institution, "University of Boras", "Borås University College")) %>%
    mutate(institution = stringr::str_replace(institution, "University of Gävle", "Gävle University College")) %>%
    mutate(institution = stringr::str_replace(institution, "University of Skövde", "Skövde University College")) %>%
    mutate(institution = stringr::str_replace(institution, "University West", "University College West"))

org_acronyms <- read_tsv("data/org_acronym_name_map.tsv")

final_springer_2017 <- adjusted_springer_2017 %>%
    inner_join(org_acronyms, by = c("institution" = "organisation")) %>%
    select(-institution) %>%
    rename(institution = "acronym") %>%
    select(institution, period, euro, doi, is_hybrid) %>%
    arrange(institution)

diff <- anti_join(adjusted_springer_2017, final_springer_2017, by = "doi")

cleaning_orgs <- diff %>%
    group_by(institution) %>%
    summarise(count = n())

write_tsv(final_springer_2017, "data/springer/apc_springer_2017.tsv")  
