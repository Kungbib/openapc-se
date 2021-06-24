library(tidyverse)
library(readxl)

# what organisation, short name? ex kth
organisation <- 'ltu'

# data collected from which timeperiod? ex 2010-2019
timeperiod_data <- '2020'

# what's the name of the file to be converted?
indata_file <- 'data/ltu/original_data/LtuOpen APCdata_202001_202012_KB.xlsx'


outdata_file_dois <- str_c('data/',organisation,'/','apc_',organisation,'_',timeperiod_data,'_dois.tsv')
outdata_file_non_dois <- str_c('data/',organisation,'/','apc_',organisation,'_',timeperiod_data,'_non_dois.tsv')


converter <- read_xlsx(indata_file)
# converter <- read_tsv(indata_file)

converter <- converter %>%
    # standard:
    mutate(euro = 0.0954*sek) %>% #valutakurs 2020 hämtad från https://www.riksbank.se/sv/statistik/sok-rantor--valutakurser/arsgenomsnitt-valutakurser/?y=2020&m=12&s=Comma&f=y
    # KI (ett år före, kvartalsvisa medelvärden):
    # mutate(euro = 0.0989*sek) %>% #valutakurs 2021 q1 hämtad från https://www.riksbank.se/sv/statistik/sok-rantor--valutakurser/arsgenomsnitt-valutakurser/?y=2020&m=12&s=Comma&f=y
    select(-sek) %>%
    select(institution, period, euro, doi, is_hybrid, publisher, journal_full_title, issn, issn_print, issn_electronic, url)

converter_dois <- converter %>%
    filter(!(is.na(doi))) %>%
    select(institution, period, euro, doi, is_hybrid, publisher)

converter_non_dois <- filter(converter, (is.na(doi)))

write_tsv(converter_dois, outdata_file_dois, na = '')
write_tsv(converter_non_dois, outdata_file_non_dois, na = '')

