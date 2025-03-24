
library(tidyverse)
library(readxl)

# 2024: HV, HH

add_costs_outdata_file <- str_c('data/',organisation,'/','add_costs_',organisation,'_',timeperiod_data,'.csv')

add_costs <- read_xlsx(indata_file, sheet = 2) %>% 
    mutate(doi = str_replace_all(doi, "[\\s]", ""),
           doi = if_else(str_starts(doi, "10."), doi, str_replace(doi, "^.*(?=10.*)", ""))
    )

add_costs_for_sending <- filter(add_costs, doi %in% indata$doi) %>% 
    mutate(across(2:9, ~ format(round(0.0875 * .x, 2), nsmall = 2))) # OBS! ändra här om annat år/omräkningsfaktor

# add_costs_for_sending_retro <- filter(add_costs, doi %in% openapcinitiative_data$doi)

if (nrow(add_costs_for_sending) > 0) write_csv(add_costs_for_sending, add_costs_outdata_file, na = '')
