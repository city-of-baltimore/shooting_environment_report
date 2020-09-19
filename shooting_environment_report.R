#!/usr/bin/Rscript
library(tidyverse)
library(lubridate)
library(emayili)
library(rmarkdown)
library(googlesheets4)

config <- read.csv("config.csv")
recipients <- read_sheet(config$recipient_url)
filename <- paste0("shooting_environment_report_", today(), ".nb.html")

rmarkdown::render(
  input = "shooting_environment_report.Rmd",
  output_file = "example.nb.html",
  #output_file = filename,
  output_dir = "reports",
  clean = T,
  envir = new.env()
)   

email_subject <- paste0(
  "[TEST] Shooting Environment Report, ", today()
)

email_message <- "
Greetings,<br><br>

The attached report identifies all currently open service requests within a 500 ft. radius of recent homicides and shootings in Baltimore. The following agencies may have open service requests identified in this report:<br>

<ul>
  <li>DOT</li>
  <li>DPW</li>
  <li>DHCD</li>
  <li>BGE</li>
  <li>BCRP</li>
  <li>Liquor Board</li>
</ul>

<b>Environmental issues are a critical public safety concern.</b> Addressing these issues in areas of recent violence can help stabilize the area and prevent repeat events in the vicinity.<br><br>

Thank you in advance for your attention.<br><br>

Please contact <a href='mailto:justin.elszasz@baltimorecity'>Justin Elszasz</a> in the Mayor's Office of Performance and Innovation for questions regarding this report.<br><br><br>


<i>(Hey team, this was just a test. Take a look through the report when you get a chance and see if everything is clear and working. Excited to hear what you think of blasting this to a bunch of people (and who should be on that list) every week and how we might track how these are getting done.)</i>
"


email <- envelope() %>%
  emayili::from(config$from_address) %>%
  emayili::to(recipients$email_address) %>%
  emayili::subject(email_subject) %>%
  emayili::html(email_message) %>%
  emayili::attachment(path = paste0("reports/", filename),
                      type = "text/html")

smtp <- server(host = "smtp.gmail.com",
               port = 465,
               username = config$from_address,
               password = config$password)

smtp(email, verbose = TRUE)
