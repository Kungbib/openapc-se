# script for preparing data for Open APC Initiative, converting SEK to EUR
# Johan Fröberg (based on Camilla Lindelöws original)

# required libraries ------------------------------------------------------
library(tidyverse)
library(readxl)

# clean environment when doing several consecutive runs, keep bibsam- and openapc-data
rm(check_bibsam, check_initiative, converter, doi_check, doi_dubbletter_all,
   for_sending_to_initiative, with_dois, with_dois_checked, without_dois,
   check_bibsam_file, check_initiative_file, indata_file, outdata_file, 
   organisation, timeperiod_data, check_org_period, indata, high_apcs, check_column_names)

# definitions of column names and types
column_names <- c("institution", "period", "sek", "doi", "is_hybrid", "publisher", "journal_full_title", "issn", "issn_print", "issn_electronic", "url")
column_types <- c("text", "numeric", "numeric", "text", "logical", "text", "text", "text", "text", "text", "text")

# settings: change before running -----------------------------------------

# what organisation, short name? ex kth
organisation <- 'hig'

# data collected from which timeperiod? ex 2010-2019, 2020_Q1
timeperiod_data <- '2024'

# what's the name of the file or files to be converted?
# indata_file <- str_c('data/', organisation, '/original_data/APC-kostnader 2023_Malmö universitet_till KB.xlsx')
indata_file <- str_c('data/', organisation, '/original_data/HIG_APC_2024.xlsx')
# indata_file2 <- str_c('data/', organisation, '/original_data/apc_liu_ht2023.xlsx')

# outdata_file_dois <- str_c('data/',organisation,'/','apc_',organisation,'_',timeperiod_data,'_dois.csv')
# outdata_file_non_dois <- str_c('data/',organisation,'/','apc_',organisation,'_',timeperiod_data,'_non_dois.csv')
# outdata_file <- str_c('data/',organisation,'/','apc_',organisation,'_',timeperiod_data,'_additions','.csv') # for additions
outdata_file <- str_c('data/',organisation,'/','apc_',organisation,'_',timeperiod_data,'.csv')
check_bibsam_file <- str_c('data/',organisation,'/','check_bibsam_',organisation,'_',timeperiod_data,'.csv')
check_initiative_file <- str_c('data/',organisation,'/','check_initiative_',organisation,'_',timeperiod_data,'.csv')


# tu_file <- tibble(
#   institution = character(),
#   period = double(),
#   sek = double(),
#   doi = character(),
#   is_hybrid = logical()
# )

# check of incoming file -------------------------------------------------
# code to represent check list in Handbok_openapcsweden

# reads indata file, gives error if number of columns are incorrect, if so add missing columns in excel
indata <- read_xlsx(indata_file, col_types = column_types)

# # if multiple indata fiels
# indata <- bind_rows(read_xlsx(indata_file, col_types = column_types), read_xlsx(indata_file2, col_types = column_types))

# # csv import
# indata <- read_csv2(indata_file)

# # add columns if only five supplied
# indata <- mutate(indata,
#                  publisher = NA,
#                  journal_full_title = NA, 
#                  issn = NA,
#                  issn_print = NA,
#                  issn_electronic = NA, 
#                  url = NA)

# check column names creates character string with wrong names
check_column_names <- setdiff(colnames(indata), column_names) 

# if wrong names, rename all column names to correct
indata <- rename_with(indata, ~ column_names)

# check organisation and period
check_org_period <- filter(indata, period != timeperiod_data | institution != organisation)

# set correct organisation and period
indata <- mutate(indata,
                      institution = organisation, 
                      period = timeperiod_data)

# find spaces in doi
doi_check <- subset(indata, str_detect(doi, "[\\s]"))
# remove spaces in doi and change doi to right format
indata <- mutate(indata, 
                 # doi = str_replace(doi, "https://", ""),
                 doi = str_replace_all(doi, "[\\s]", ""),
                 doi = if_else(str_starts(doi, "10."), doi, str_replace(doi, "^.*(?=10.*)", ""))
                 )


doi_check <- subset(indata, str_detect(doi, "[\\s]"))

# find doi duplicates, if != 0 resolve with organisation alter and start over 
# doi_dubbletter <- subset(indata, duplicated(doi)) # hittar doi_dubbletter
doi_dubbletter_all <- group_by(indata, doi) %>% 
    filter(n() > 1) %>% 
    ungroup() %>% 
    arrange(doi)

# find high apc:s, if any resolve with organisation
high_apcs <- filter(indata, sek > 80000)

# conversion --------------------------------------------------------------

# converter <- read_xlsx(indata_file2, col_types = column_types)

# kom ihåg att KI är ett år före, och kommer leverera data under innevarande år, därav
# en egen rad för dem.
converter <- indata %>%
  # standard:
  mutate(euro = case_when(period == 2023 ~ format(round(0.0871 * sek, 2), nsmall = 2),
                          period == 2022 ~ format(round(0.0941 * sek, 2), nsmall = 2),
                          period == 2021 ~ format(round(0.0986 * sek, 2), nsmall = 2),
                          TRUE ~ NA)
         ) %>% 
  # valutakurs 2023 0.0871 
  # hämtad från https://www.riksbank.se/sv/statistik/sok-rantor--valutakurser/arsgenomsnitt-valutakurser/
    # valutakurs 2022 0.0941
  
  # KI (kvartalsvisa medelvärden):
  # mutate(euro = format(round(0.0937*sek, 2), nsmall = 2)) %>% #valutakurs 2022 q2-q4 hämtad från https://www.riksbank.se/sv/statistik/sok-rantor--valutakurser/ (månadsgenomsnitt)    select(-sek) %>%
  select(-sek) %>%
  select(institution, period, euro, doi, is_hybrid, publisher, journal_full_title, issn, issn_print, issn_electronic, url)


# Bibsam check ------------------------------------------------------------

# separera de utan DOI och hantera dem separat, utanför Bibsam-checken.
without_dois <- filter(converter, is.na(doi))
with_dois <- filter(converter, !(is.na(doi)))

# tvätta mot Bibsams publiceringsdata (se till att använda uppdaterad fil)
# bibsam_data <- read_csv("data/19_21_bibsam_data.csv") 
# ändrat till att läsa filen från GitHUB
bibsam_data <- read_csv("https://raw.githubusercontent.com/Kungbib/oa-tskr/master/Bibsam_artikeldata/19_22_bibsam_data.csv")

with_dois_checked <- anti_join(with_dois, bibsam_data, by = "doi")
check_bibsam <- semi_join(with_dois, bibsam_data, by = "doi")

# för att se info i bibsam-filen för eventeulla tidigare rapporterade publikationer
# check_bibsam_info <- filter(bibsam_data, doi %in% check_bibsam$doi)

# # sätt tillbaka de som inte har DOIs 
# all_data <- rbind(with_dois_checked, without_dois)
# # läggs nu tillbaka senare i processen

# Open APC Initiative check -----------------------------------------------

# checka mot Open APC Initiative data för att se om posten registrerats tidigare, antingen av
# samma lärosäte men då förmodligen olika kostnad, eller av två separata lärosäten:
# apc_de-filen behöver uppdateras kontinuerligt. Kan ersättas av den kommande svenska totalfilen.

# har bytt till att läsa den senaste från tyska git
# openapcinitiative_data <- read_csv("data/apc_de.csv")
openapcinitiative_data <- read_csv("https://raw.githubusercontent.com/OpenAPC/openapc-de/master/data/apc_de.csv")
check_initiative <- inner_join(with_dois, openapcinitiative_data, by = "doi")
for_sending_to_initiative <- anti_join(with_dois_checked, check_initiative, by = "doi") 
for_sending_to_initiative <- rbind(for_sending_to_initiative, without_dois) # lägger tillbaka de utan doi


# Skriv till filer --------------------------------------------------------

# check_bibsam och check_initiativ skrivs nu bara om publikationer redan finns i Bibsams eller OpenAPCs data
write_csv(for_sending_to_initiative, outdata_file, na = '')
if (nrow(check_bibsam) > 0) write_csv(check_bibsam, check_bibsam_file, na = '')
if (nrow(check_initiative) > 0) write_csv(check_initiative, check_initiative_file, na = '')



