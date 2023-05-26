# required libraries ------------------------------------------------------
library(tidyverse)
library(readxl)


# settings: change before running -----------------------------------------

# what organisation, short name? ex kth
organisation <- 'sh'

# data collected from which timeperiod? ex 2010-2019, 2020_Q1
timeperiod_data <- '2022'

# what's the name of the file to be converted?
indata_file <- str_c('data/', organisation, '/original_data/open_apc_sh_2022_books.xlsx')

outdata_file <- str_c('data/',organisation,'/','bookpc_',organisation,'_',timeperiod_data,'.csv')
check_initiative_file <- str_c('data/',organisation,'/','book_check_initiative_',organisation,'_',timeperiod_data,'.csv')


# conversion --------------------------------------------------------------
converter <- read_xlsx(indata_file)

doi_check <- subset(converter, str_detect(doi, "[\\s]")) # hittar mellanslag i doi
doi_dubbletter <- subset(converter, duplicated(doi)) # hittar doi_dubbletter

converter <- converter %>%
  # standard:
  mutate(euro = format(round(0.0941*sek, 2), nsmall = 2)) %>% #valutakurs 2022 hämtad från 
  # https://www.riksbank.se/sv/statistik/sok-rantor--valutakurser/arsgenomsnitt-valutakurser/
  select(-sek) %>%
  relocate(euro, .after = period)

# Open APC Initiative check -----------------------------------------------

# checka mot Open APC Initiative book data för att se om posten registrerats tidigare, antingen av
# samma lärosäte men då förmodligen olika kostnad, eller av två separata lärosäten:
# apc_de-filen behöver uppdateras kontinuerligt. Kan ersättas av den kommande svenska totalfilen.

openapcinitiative_book_data <- read_csv("https://raw.githubusercontent.com/OpenAPC/openapc-de/master/data/bpc.csv")
check_initiative <- inner_join(converter, openapcinitiative_book_data, by = "doi", na_matches = "never")
for_sending_to_initiative <- anti_join(converter, check_initiative, by = "doi") 

# Skriv till filer --------------------------------------------------------

write_csv(for_sending_to_initiative, outdata_file, na = '')
write_csv(check_initiative, check_initiative_file, na = '')
