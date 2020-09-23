#!/usr/local/bin/Rscript
library(tidyverse)
library(lubridate)
library(emayili)
library(rmarkdown)

config <- read_csv("config.csv")
recipients <- read_csv(config$recipient_url)
filename <- paste0("shooting_environment_report_", today(), ".nb.html")

# not sure why this is needed to find pandoc
Sys.setenv(RSTUDIO_PANDOC="/Applications/RStudio.app/Contents/MacOS/pandoc")

rmarkdown::render(
  input = "shooting_environment_report.Rmd",
  output_file = filename,
  #output_file = "example.nb.html",
  output_dir = "reports",
  clean = T
)   

email_subject <- paste0(
  "Shooting Environment Report, ", today()
)

email_message <-  read_file("email_message.txt")

email <- envelope() %>%
  emayili::from(config$from_address) %>%
  emayili::to(recipients$email_address) %>%
  #emayili::to("justin.elszasz@baltimorecity.gov") %>%
  emayili::subject(email_subject) %>%
  emayili::html(email_message) %>%
  emayili::attachment(path = paste0("reports/", filename),
                     type = "text/html")

smtp <- server(host = "smtp.gmail.com",
               port = 465,
               username = config$from_address,
               password = config$password)

smtp(email)
