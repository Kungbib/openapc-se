# kod för att omvandla Bibsams publiceringsdata till den form som
# Open APC Initiative använder: 
# https://github.com/OpenAPC/openapc-de/wiki/schema#transformative-agreements-data-set
# Bibsams publiceringsdata innehåller även data som kan sägas vara
# APC-baserad i stil med det som sedan tidigare samlas i Open APC Sweden.
# Därför delas Bibsams publiceringsdata upp i två mängder nedan.

library(tidyverse)

bibsam_data <- read_csv("https://raw.githubusercontent.com/Kungbib/oa-tskr/master/Bibsam_artikeldata/19_22_bibsam_data.csv")

# ange de förlag där Bibsam har apc-baserade avtal 
# (artiklar betalas styckevis):
apc_agreements <- c("mdpi", "frontiers")

# första mängden utgörs av de transformativa avtalen:  
transformative_bibsam_data <- bibsam_data %>%
  filter(!publisher %in% apc_agreements)

# andra mängden är de som betalas per artikel:
apc_bibsam_data <- bibsam_data %>%
  filter(publisher %in% apc_agreements)

# för transformativa avtal anges inte enskild kostnad, däremot är doi
# obligatorisk för Initiative så de poster som inte har doi filtreras bort
transformative_bibsam_data_for_export <- transformative_bibsam_data %>%
  transmute(institution = name_sve,
            period = year_paid,
            doi = doi,
            is_hybrid = if_else(oa_type == "hybrid", TRUE, FALSE)
            ) %>%
  filter(!(is.na(doi)))

# i den mängd som ska till den ursprungliga Initiaitve-samlingen omvandlas 
# sek till euro med årsgenomsnitt från 
# https://www.riksbank.se/sv/statistik/sok-rantor--valutakurser/arsgenomsnitt-valutakurser/?y=2022&m=12&s=Comma&f=y
# av någon anledning finns det flera poster som inte har ett pris här,
# och det är oklart varför eftersom de ofta har ett pris i masterfilen på Github.
# tills vidare sorteras de bort.
apc_bibsam_data_for_export <- apc_bibsam_data %>%
  transmute(institution = name_sve,
            period = year_paid,
            sek = bibsam_price_sek,
            doi = doi,
            is_hybrid = if_else(oa_type == "hybrid", TRUE, FALSE)
  ) %>%
  mutate(euro = if_else(period == 2019, sek/10.5892,
                        if_else(period == 2020, sek/10.4867,
                                 if_else(period == 2021, sek/10.1449,
                                         if_else(period == 2022, sek/10.6317, 0))))
         ) %>%
  select(institution, period, euro, doi, is_hybrid) %>%
  filter(!(is.na(doi)),
         !(is.na(euro)))

write_csv("transformative_for_export.csv", transformative_bibsam_data_for_export)
write_csv("apc_based_for_export.csv", apc_bibsam_data_for_export)