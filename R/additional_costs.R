
library(tidyverse)
library(readxl)

# indata_file <- str_c('data/', organisation, '/original_data/apc_bth_additional_costs-2024.csv')

add_costs_outdata_file <- str_c('data/',organisation,'/','add_costs_',organisation,'_',timeperiod_data,'.csv')
add_costs_not_sending_file <- str_c('data/',organisation,'/','add_costs_not_sending_',organisation,'_',timeperiod_data,'.csv')

add_costs <- read_xlsx(indata_file, sheet = 2) %>% 
    mutate(doi = str_to_lower(str_replace_all(doi, "[\\s]", "")),
           doi = if_else(str_starts(doi, "10."), doi, str_replace(doi, "^.*(?=10.*)", ""))
    )

doi_dubbletter_add_costs <- group_by(add_costs, doi) %>% 
    filter(n() > 1) %>% 
    ungroup() %>% 
    arrange(doi)

add_costs_for_sending <- filter(add_costs, doi %in% indata$doi) %>% 
    mutate(across(2:9, ~ format(round(0.0904 * .x, 2), nsmall = 2))) # OBS! ändra här om annat år/omräkningsfaktor 2024: 0.0875

add_costs_not_sending <- anti_join(add_costs, add_costs_for_sending, by = "doi")

# add_costs_for_sending_retro <- filter(add_costs, doi %in% openapcinitiative_data$doi)

if (nrow(add_costs_for_sending) > 0) write_csv(add_costs_for_sending, add_costs_outdata_file, na = '')
if (nrow(add_costs_not_sending) > 0) write_csv(add_costs_not_sending, add_costs_not_sending_file, na = '')
