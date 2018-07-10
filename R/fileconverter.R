library(tidyverse)
library(readxl)

# what organisation, short name? ex kth
organisation <- 'gu'

# data collected from which timeperiod? ex 2010-2019
timeperiod_data <- 'add_may_2018'

# what's the name of the file to be converted?
indata_file <- 'data/gu/original_data/komplettering_KB_maj18.xlsx'


outdata_file_dois <- str_c('data/',organisation,'/','apc_',organisation,'_',timeperiod_data,'_dois.tsv')
outdata_file_non_dois <- str_c('data/',organisation,'/','apc_',organisation,'_',timeperiod_data,'_non_dois.tsv')


converter <- read_xlsx(indata_file)
converter_dois <- filter(converter, !(is.na(doi)))
converter_non_dois <- filter(converter, (is.na(doi)))
write_tsv(converter_dois, outdata_file_dois, na = '')
write_tsv(converter_non_dois, outdata_file_non_dois, na = '')

