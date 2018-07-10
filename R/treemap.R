library(tidyverse)
library(treemap)

data <- read_csv("data/apc_se.csv")

test <- data %>%
    group_by(publisher) %>%
    summarise(euro = sum(euro)) %>%
    mutate(eurolabel = format(euro, digits = 3, big.mark = " "))

test$label <- paste(test$publisher, test$eurolabel, sep = "\n")

#palette.HCL.options <- list(hue_start=10, hue_end=320)

treemap(test,
        index = "label",
        vSize = "euro",
        type = "index",
        palette = "YlOrRd",
        #palette.HCL.options = palette.HCL.options,
        title = "Spending on APCs (in euro, €) by publisher",
        #title = "",
        fontsize.title = 14,
        fontsize.labels = 10,
        lowerbound.cex.labels = 0.5,
        border.col = "white",
        fontcolor.labels = "black")

