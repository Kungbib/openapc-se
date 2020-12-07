# läsa in olika förlagsfiler till en fil

library(tidyverse)
library(readxl)

uniform_data <- tibble(
    publisher = character(),
    doi = character(),
    journal = character(),
    eissn = character(),
    issn = character(),
    url = character(),
    date_published = date(),
    corr_author_org = character(),
    oa_type = character(),
    license = character(),
    apc_currency = character(),
    apc = double(),
    apc_date_paid = date(),
    source_file = character()
)

# cambridge university press
cup_data <- read_excel("O:/Avd-Publik-verksamhet/Enh. Nationell bibliotekssamverkan/Bibsamkonsortiet/Statistik/Publiceringsstatistik/Cambridge/2019/BIBSAM Read and Publish Report 2019.xlsx", sheet = 2, skip = 1)

uniform_cup_data <- cup_data %>%
    mutate(publisher = "cup",
           source_file = "cup_2019.xlsx") %>%
    select(publisher,
           DOI,
           `Publication Name`,
           `Online ISSN`,
           `Online Publication Date`,
           `Corresponding Author Email Domain`,
           `Journal Status`) %>%
    rename(doi = DOI,
           journal = `Publication Name`,
           eissn = `Online ISSN`)


degruyter_data <- read_excel("C:/Users/camlin/data/förlag_publiceringsdata/degruyter_2019.xlsx")

uniform_degruyter_data <- degruyter_data %>%
    mutate(publisher = "degruyter") %>%
    select(publisher,
           DOI...10) %>%
    rename(doi = DOI...10)
        
# frontiers hanteras separat

iop_data <- read_excel("C:/Users/camlin/data/förlag_publiceringsdata/iop_2019.xlsx")

uniform_iop_data <- iop_data %>%
    mutate(publisher = "iop") %>%
    select(publisher,
           DOI) %>%
    rename(doi = DOI)

oup_data <- read_excel("C:/Users/camlin/data/förlag_publiceringsdata/oup_2019.xlsx")

uniform_oup_data <- oup_data %>%
    mutate(publisher = "oup") %>%
    select(publisher,
           DOI) %>%
    rename(doi = DOI)

rsc_data <- read_excel("C:/Users/camlin/data/förlag_publiceringsdata/rsc_2019.xlsx")

uniform_rsc_data <- rsc_data %>%
    mutate(publisher = "rsc") %>%
    select(publisher,
           DOI) %>%
    mutate(DOI = str_c("https://doi.org/10.1039/", DOI)) %>%
    rename(doi = DOI)

springercompact_data_1 <- read_excel("C:/Users/camlin/data/förlag_publiceringsdata/springercompact_2019.xlsx", skip=4)
springercompact_data_2 <- read_excel("C:/Users/camlin/data/förlag_publiceringsdata/springercompact_2019.xlsx", skip=4, sheet = 2)

springercompact_data <- bind_rows(springercompact_data_1, springercompact_data_2)

uniform_springercompact_data <- springercompact_data %>%
    mutate(publisher = "springercompact") %>%
    select(publisher,
           DOI) %>%
    rename(doi = DOI)

springerfullyoa_data_1 <- read_excel("C:/Users/camlin/data/förlag_publiceringsdata/springerfullyoa_2019.xlsx", skip=4, sheet = 3)
springerfullyoa_data_2 <- read_excel("C:/Users/camlin/data/förlag_publiceringsdata/springerfullyoa_2019.xlsx", skip=4, sheet = 4)

springerfullyoa_data <- bind_rows(springerfullyoa_data_1, springerfullyoa_data_2)

uniform_springerfullyoa_data <- springerfullyoa_data %>%
    mutate(publisher = "springerfullyoa") %>%
    select(publisher,
           DOI) %>%
    rename(doi = DOI)

taylorandfrancis_data <- read_csv("C:/Users/camlin/data/förlag_publiceringsdata/taylorandfrancis_2019.csv")

uniform_taylorandfrancis_data <- taylorandfrancis_data %>%
    mutate(publisher = "taylorandfrancis") %>%
    select(publisher,
           doi)




final_table <- bind_rows(uniform_data, 
                         uniform_cup_data,
                         uniform_degruyter_data,
                         uniform_iop_data,
                         uniform_oup_data,
                         uniform_rsc_data,
                         uniform_springercompact_data,
                         uniform_springerfullyoa_data,
                         uniform_taylorandfrancis_data)

final_table <- final_table %>%
    distinct()
