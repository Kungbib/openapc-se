# Script for preparing corrections to OpenAPC DE

# required libraries ------------------------------------------------------
library(tidyverse)
library(readxl)
library(openxlsx)

column_types <- c("text", "numeric", "numeric", "text", "logical", "text", "text", "text", "text", "text", "text")

openapcinitiative_data <- read_csv("https://raw.githubusercontent.com/OpenAPC/openapc-de/master/data/apc_de.csv")

organisation <- "lu"
file_name <- "mdpi_korr_2024.xlsx"

correction_file <- str_c('data/', organisation, '/corrections/', file_name)

correction_data <- read_xlsx(correction_file, col_types = column_types)

lu_corrections <- semi_join(correction_data, openapcinitiative_data, by = "doi") %>% 
    mutate(euro = format(round(0.0875 * sek, 2), nsmall = 2))

bibsam_data <- read_rds("~/r/_r_datafiles/bibsam_data_19_24.rds")

lu_corr <- semi_join(correction_data, bibsam_data, by = "doi")


lu_2024_corrections <- read.csv("data/lu/apc_lu_2024.csv") %>% 
    semi_join(lu_corrections, by = "doi")

write.csv(lu_2024_corrections, "data/lu/lu_2024_mdpi_deletions.csv")
