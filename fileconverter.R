library(tidyverse)

converter <- read_xlsx("data/oru/original_data/ORU APC_data 2015_2017_upload 20180601.xlsx")
# converter <- select(converter, 1:5)
write_tsv(converter, "data/oru/apc_oru_2015_2017.tsv", na = "")

test <- read_csv("data/oru/apc_oru_2015_2017.tsv")
