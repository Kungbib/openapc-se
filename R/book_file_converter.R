# required libraries ------------------------------------------------------
library(tidyverse)
library(readxl)


# definitions of column names and types
column_names <- c("institution", "period", "sek", "doi", "backlist_oa", "publisher", "book_title", "isbn_1", "isbn_2", "isbn_3")
column_types <- c("text", "numeric", "numeric", "text", "logical", "text", "text", "text", "text", "text")

# rm between consecutive runs
rm(organisation, timeperiod_data, indata_file, outdata_file, check_initiative_file, missing_doi_isbn_file, indata,
   missing_doi_isbn, check_column_names, doi_check, doi_dubbletter_all, isbn_dubbletter_all, 
   converter, check_initiative, for_sending_to_initiative)

# settings: change before running -----------------------------------------

# what organisation, short name? ex kth
organisation <- 'sh'

# data collected from which timeperiod? ex 2010-2019, 2020_Q1
timeperiod_data <- '2023'

# what's the name of the file to be converted?
indata_file <- str_c('data/', organisation, '/original_data/bpc_sh_2023.xlsx')

outdata_file <- str_c('data/', organisation, '/bookpc_', organisation, '_', timeperiod_data, '.csv')
check_initiative_file <- str_c('data/',organisation,'/','book_check_initiative_',organisation,'_',timeperiod_data,'.csv')
missing_doi_isbn_file <- str_c('data/', organisation, "/missing_doi_and_isbn_", organisation, "_", timeperiod_data, ".csv" )


# conversion --------------------------------------------------------------
indata <- read_xlsx(indata_file)

# check column names creates character string with wrong names
check_column_names <- setdiff(colnames(indata), column_names) 

# if wrong names, rename all column names to correct
indata <- rename_with(indata, ~ column_names)

# remove extra column(s) and rows which have no doi or isbn, which first are written to separate table
indata <- select(indata, -url) 
missing_doi_isbn <- filter(indata, is.na(doi) & is.na(isbn_1))
indata <- filter(indata, !is.na(doi) | !is.na(isbn_1))

doi_check <- subset(indata, str_detect(doi, "[\\s]")) # hittar mellanslag i doi

indata <- mutate(indata, 
                 # doi = str_replace(doi, "https://", ""),
                 doi = str_replace_all(doi, "[\\s]", ""),
                 doi = if_else(str_starts(doi, "10."), doi, str_replace(doi, "^.*(?=10.*)", "")),
                 isbn_1 = str_replace_all(isbn_1, "-", "")
)

# hittar doi_dubbletter
doi_dubbletter_all <- group_by(indata, doi) %>% 
    filter(n() > 1) %>% 
    ungroup() %>% 
    arrange(doi) 

isbn_dubbletter_all <- group_by(indata, isbn_1) %>% 
    filter(n() > 1) %>% 
    ungroup() %>% 
    arrange(doi)

converter <- indata %>%
  # standard:
  mutate(euro = format(round(0.0871*sek, 2), nsmall = 2)) %>% # valutakurs 2022 0.0941 hämtad från 
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
if (nrow(check_initiative) > 0) write_csv(check_initiative, check_initiative_file, na = '')
if (nrow(missing_doi_isbn) > 0) write_csv(missing_doi_isbn, missing_doi_isbn_file, na = '')
