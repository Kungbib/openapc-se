library(tidyverse)
library(readxl)

# Bibsam data
data_bibsam <- read_csv("../normalisera_forlagsdata/result_files/19_25_bibsam_data.csv") %>% 
    filter(doi != "10.1177/14034948251319382") %>% # för att ta bort sage publikation som ska vara med i OpenAPC enligt Henrik, se mejl
    # filter(publisher != "mdpi") %>% 
    filter(!(publisher == "aps" & oa_type == "gold"))

data_openapc_de <- read_csv("https://raw.githubusercontent.com/OpenAPC/openapc-de/master/data/apc_de.csv") %>% 
    mutate(doi = str_to_lower(doi))

organisation <- "uu"

bibsam_check <- read_csv(paste0("data/", organisation, "/check_bibsam_", organisation, "_2025.csv"))

bibsam_info <- semi_join(data_bibsam, bibsam_check, by = "doi")


kau_mdpi <- bibsam_check

mdpi_additions <- bind_rows(du_mdpi, gih_mdpi, hh_mdpi, kau_mdpi)

write_csv(mdpi_additions, "data/additions_corrections/se_apc_additions_mdpi_2025.csv", na = '')
