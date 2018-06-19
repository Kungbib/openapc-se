library(tidyverse)
library(readxl)

converter <- read_xlsx("data/kth/original_data/apc_kth_2017.xlsx")
converter_dois <- filter(converter, !(is.na(doi)))
converter_non_dois <- filter(converter, (is.na(doi)))
write_tsv(converter_dois, "data/kth/original_data/apc_kth_2017_dois.tsv", na = "")
write_tsv(converter_non_dois, "data/kth/original_data/apc_kth_2017_non_dois.tsv", na = "")

