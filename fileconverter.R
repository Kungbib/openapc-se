library(tidyverse)

converter <- read_xlsx("data/oru/original_data/ORU APC_data 2015_2017_upload 20180601.xlsx")
converter_dois <- filter(converter, !(is.na(doi)))
converter_non_dois <- filter(converter, (is.na(doi)))
write_tsv(converter_dois, "data/oru/original_data/apc_oru_2015_2017_dois.tsv", na = "")
write_tsv(converter_non_dois, "data/oru/original_data/apc_oru_2015_2017_non_dois.tsv", na = "")

