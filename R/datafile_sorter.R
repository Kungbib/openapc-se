# chl 180607
# script to make subsets of data
#
#
library(tidyverse)

apc_se <- read_csv("data/apc_se.csv")
springer_dois <- read_tsv("data/springer/Springer_Compact_2016_2018.tsv")

springer_data <- left_join(springer_dois, apc_se, by="doi")
apc_se_without_springer <- anti_join(apc_se, springer_dois, by="doi")

write_tsv(springer_data, "data/springer_data_1.tsv") 
write_tsv(apc_se_without_springer, "data/apc_se_without_springer_1.tsv") 
