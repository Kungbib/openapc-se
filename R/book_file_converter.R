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
organisation <- 'liu'

# data collected from which timeperiod? ex 2010-2019, 2020_Q1
timeperiod_data <- '2024'

# what's the name of the file to be converted?
# indata_file <- str_c('data/', organisation, '/original_data/Miun bpc_template 2024.xlsx')
indata_file <- str_c('data/', organisation, '/original_data/KB-mall 2024VT.xlsx')
indata_file_parttwo <- str_c('data/', organisation, '/original_data/Open APC LiU 2024HT.xlsx')

outdata_file <- str_c('data/', organisation, '/bookpc_', organisation, '_', timeperiod_data, '.csv')
check_initiative_file <- str_c('data/',organisation,'/','book_check_initiative_',organisation,'_',timeperiod_data,'.csv')
missing_doi_isbn_file <- str_c('data/', organisation, "/missing_doi_and_isbn_", organisation, "_", timeperiod_data, ".csv" )


# conversion --------------------------------------------------------------
indata <- read_xlsx(indata_file, sheet = 2, col_types = column_types) 

indata_parttwo <- read_xlsx(indata_file_parttwo, sheet = 2, col_types = column_types)

indata <- bind_rows(indata, indata_parttwo)
# %>% # %>% mutate(institution = organisation) 
#     filter(doi != "Ej ännu publicerad") %>% 
#     filter(!str_detect(Kommentar, "Kapitel")) %>% 
#     select(-Kommentar)

# add columns
indata <- mutate(indata,
                 publisher = NA,
                 book_title = NA,
                 isbn_1 = NA,
                 isbn_2 = NA,
                 isbn_3 = NA)
# remove extra column(s) 
indata <- select(indata, -url) 

# check column names creates character string with wrong names
check_column_names <- setdiff(colnames(indata), column_names) 

# if wrong names, rename all column names to correct
indata <- rename_with(indata, ~ column_names)

# create table rows which have no doi or isbn
missing_doi_isbn <- filter(indata, is.na(doi) & is.na(isbn_1) & is.na(isbn_2) & is.na(isbn_3))
# remove rows which have no doi or isbn
indata <- filter(indata, !is.na(doi) | !is.na(isbn_1) | !is.na(isbn_2) | !is.na(isbn_3))

doi_check <- subset(indata, str_detect(doi, "[\\s]")) # hittar mellanslag i doi

indata <- mutate(indata, 
                 # doi = str_replace(doi, "https://", ""),
                 doi = str_replace_all(doi, "[\\s]", ""),
                 doi = if_else(str_starts(doi, "10."), doi, str_replace(doi, "^.*(?=10.*)", "")),
                 isbn_1 = str_replace_all(isbn_1, "-", "")
)
doi_check <- subset(indata, str_detect(doi, "[\\s]")) # hittar mellanslag i doi

# för att ta bort - i ISBN
indata <- mutate(indata, across( 8:10, ~ str_remove_all(.x, "-")))

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
  mutate(euro = format(round(0.0875 * sek, 2), nsmall = 2)) %>% # valutakurs 2022 0.0941 hämtad från 
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
