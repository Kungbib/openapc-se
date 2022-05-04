library(tidyverse)
library(readxl)

# what organisation, short name? ex kth
organisation <- 'hig'

# data collected from which timeperiod? ex 2010-2019, 2020_Q1
timeperiod_data <- '2021'

# what's the name of the file to be converted?
indata_file <- 'data/hig/original_data/HiG_APC_2021.xlsx'
tu_file <- tibble(
  institution = character(),
  period = double(),
  sek = double(),
  doi = character(),
  is_hybrid = logical()
)


# outdata_file_dois <- str_c('data/',organisation,'/','apc_',organisation,'_',timeperiod_data,'_dois.csv')
# outdata_file_non_dois <- str_c('data/',organisation,'/','apc_',organisation,'_',timeperiod_data,'_non_dois.csv')
outdata_file <- str_c('data/',organisation,'/','apc_',organisation,'_',timeperiod_data,'.csv')
check_file <- str_c('data/',organisation,'/','check_',organisation,'_',timeperiod_data,'.csv')


converter <- read_xlsx(indata_file)
# converter <- read_tsv(indata_file)

converter <- converter %>%
  # standard:
  mutate(euro = format(round(0.0986*sek, 2), nsmall = 2)) %>% #valutakurs 2021 hämtad från https://www.riksbank.se/sv/statistik/sok-rantor--valutakurser/arsgenomsnitt-valutakurser/?y=2020&m=12&s=Comma&f=y
  # KI (ett år före, kvartalsvisa medelvärden):
  # mutate(euro = format(round(0.0981*sek, 2), nsmall = 2)) %>% #valutakurs 2021 q3 hämtad från https://www.riksbank.se/sv/statistik/sok-rantor--valutakurser/ (månadsgenomsnitt)    select(-sek) %>%
  select(-sek) %>%
  select(institution, period, euro, doi, is_hybrid, publisher, journal_full_title, issn, issn_print, issn_electronic, url)

#tvätta mot Bibsam-data
bibsam_data <- read_csv("data/19_21_bibsam_data.csv")
converter_checked <- anti_join(converter, bibsam_data, by = "doi")
check <- semi_join(converter, bibsam_data, by = "doi")

write_csv(converter_checked, outdata_file, na = '')
write_csv(check, check_file, na = '')

rbind(tu_file, converter_checked)


# converter_dois <- converter %>%
#     filter(!(is.na(doi))) %>%
#     select(institution, period, euro, doi, is_hybrid, publisher)
# 
# converter_non_dois <- filter(converter, (is.na(doi)))

# write_tsv(converter_dois, outdata_file_dois, na = '')
# write_tsv(converter_non_dois, outdata_file_non_dois, na = '')

