library(tidyverse)
library(readxl)

# what organisation, short name? ex kth
organisation <- 'mah'

# data collected from which timeperiod? ex 2010-2019
timeperiod_data <- '2018'

# what's the name of the file to be converted?
indata_file <- 'data/mah/original_data/MAU_APC_2018_Till_KB.xlsx'


outdata_file_dois <- str_c('data/',organisation,'/','apc_',organisation,'_',timeperiod_data,'_dois.tsv')
outdata_file_non_dois <- str_c('data/',organisation,'/','apc_',organisation,'_',timeperiod_data,'_non_dois.tsv')


converter <- read_xlsx(indata_file)
converter_dois <- converter %>%
    filter(!(is.na(doi))) %>%
    select(institution, period, euro, doi, is_hybrid, publisher)
converter_non_dois <- filter(converter, (is.na(doi)))
write_tsv(converter_dois, outdata_file_dois, na = '')
write_tsv(converter_non_dois, outdata_file_non_dois, na = '')

