
# required libraries ------------------------------------------------------
library(tidyverse)
library(readxl)


# settings: change before running -----------------------------------------

# what organisation, short name? ex kth
organisation <- 'su'

# data collected from which timeperiod? ex 2010-2019, 2020_Q1
timeperiod_data <- '2022'

# what's the name of the file to be converted?
indata_file <- str_c('data/', organisation, '/original_data/apc_su_2022.xlsx')

# tu_file <- tibble(
#   institution = character(),
#   period = double(),
#   sek = double(),
#   doi = character(),
#   is_hybrid = logical()
# )


# outdata_file_dois <- str_c('data/',organisation,'/','apc_',organisation,'_',timeperiod_data,'_dois.csv')
# outdata_file_non_dois <- str_c('data/',organisation,'/','apc_',organisation,'_',timeperiod_data,'_non_dois.csv')
outdata_file <- str_c('data/',organisation,'/','apc_',organisation,'_',timeperiod_data,'.csv')
check_bibsam_file <- str_c('data/',organisation,'/','check_bibsam_',organisation,'_',timeperiod_data,'.csv')
check_initiative_file <- str_c('data/',organisation,'/','check_initiative_',organisation,'_',timeperiod_data,'.csv')


# conversion --------------------------------------------------------------
column_types <- c("text", "numeric", "numeric", "text", "logical", "text", "text", "text", "text", "text", "text")
converter <- read_xlsx(indata_file, col_types = column_types)
# converter <- read_csv(indata_file)

# kom ihåg att KI är ett år före, och kommer leverera data under innevarande år, därav
# en egen rad för dem.
converter <- converter %>%
  # standard:
  mutate(euro = format(round(0.0941*sek, 2), nsmall = 2)) %>% #valutakurs 2022 hämtad från 
  # https://www.riksbank.se/sv/statistik/sok-rantor--valutakurser/arsgenomsnitt-valutakurser/
  # KI (ett år före, kvartalsvisa medelvärden):
  # mutate(euro = format(round(0.0954*sek, 2), nsmall = 2)) %>% #valutakurs 2022 q1 hämtad från https://www.riksbank.se/sv/statistik/sok-rantor--valutakurser/ (månadsgenomsnitt)    select(-sek) %>%
  select(-sek) %>%
  select(institution, period, euro, doi, is_hybrid, publisher, journal_full_title, issn, issn_print, issn_electronic, url)


# Bibsam check ------------------------------------------------------------

# separera de utan DOI och hantera dem separat, utanför Bibsam-checken.
without_dois <- filter(converter, is.na(doi))
with_dois <- filter(converter, !(is.na(doi)))

# tvätta mot Bibsams publiceringsdata (se till att använda uppdaterad fil)
bibsam_data <- read_csv("data/19_21_bibsam_data.csv")
with_dois_checked <- anti_join(with_dois, bibsam_data, by = "doi")
check_bibsam <- semi_join(with_dois, bibsam_data, by = "doi")

# sätt tillbaka de som inte har DOIs
all_data <- rbind(with_dois_checked, without_dois)


# Open APC Initiative check -----------------------------------------------

# checka mot Open APC Initiative data för att se om posten registrerats tidigare, antingen av
# samma lärosäte men då förmodligen olika kostnad, eller av två separata lärosäten:
# apc_de-filen behöver uppdateras kontinuerligt. Kan ersättas av den kommande svenska totalfilen.

openapcinitiative_data <- read_csv("data/apc_de.csv")
check_initiative <- inner_join(with_dois, openapcinitiative_data, by = "doi")
for_sending_to_initiative <- anti_join(with_dois_checked, check_initiative, by = "doi")


# Skriv till filer --------------------------------------------------------

write_csv(for_sending_to_initiative, outdata_file, na = '')
write_csv(check_bibsam, check_bibsam_file, na = '')
write_csv(check_initiative, check_initiative_file, na = '')




# Gammal kod, gå igenom ---------------------------------------------------

# tu_data <- rbind(tu_file, converter_checked)
tu_data <- rbind(tu_data, converter_checked)


#när alla är inlästa
tu_data_all <- tu_data %>%
  filter(period == 2021)

write_csv(tu_data_all, "data/tu_data_open_apc_se.csv", na = '')

# converter_dois <- converter %>%
#     filter(!(is.na(doi))) %>%
#     select(institution, period, euro, doi, is_hybrid, publisher)
# 
# converter_non_dois <- filter(converter, (is.na(doi)))

# write_tsv(converter_dois, outdata_file_dois, na = '')
# write_tsv(converter_non_dois, outdata_file_non_dois, na = '')

