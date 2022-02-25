library(tidyverse)
library(readxl)

# what organisation, short name? ex kth
organisation <- 'ki'

# data collected from which timeperiod? ex 2010-2019, 2020_Q1
timeperiod_data <- '2021_Q3'

# what's the name of the file to be converted?
indata_file <- 'data/ki/original_data/APC-data till KB Q3 2021.xlsx'


outdata_file_dois <- str_c('data/',organisation,'/','apc_',organisation,'_',timeperiod_data,'_dois.tsv')
outdata_file_non_dois <- str_c('data/',organisation,'/','apc_',organisation,'_',timeperiod_data,'_non_dois.tsv')


converter <- read_xlsx(indata_file)
# converter <- read_tsv(indata_file)

converter <- converter %>%
    # standard:
    # mutate(euro = format(round(0.0954*sek, 2), nsmall = 2)) %>% #valutakurs 2020 hämtad från https://www.riksbank.se/sv/statistik/sok-rantor--valutakurser/arsgenomsnitt-valutakurser/?y=2020&m=12&s=Comma&f=y
    # KI (ett år före, kvartalsvisa medelvärden):
    mutate(euro = format(round(0.0981*sek, 2), nsmall = 2)) %>% #valutakurs 2021 q2 hämtad från https://www.riksbank.se/sv/statistik/sok-rantor--valutakurser/ (månadsgenomsnitt)
    select(-sek) %>%
    select(institution, period, euro, doi, is_hybrid, publisher, journal_full_title, issn, issn_print, issn_electronic, url)

converter_dois <- converter %>%
    filter(!(is.na(doi))) %>%
    select(institution, period, euro, doi, is_hybrid, publisher)

converter_non_dois <- filter(converter, (is.na(doi)))

write_tsv(converter_dois, outdata_file_dois, na = '')
write_tsv(converter_non_dois, outdata_file_non_dois, na = '')

