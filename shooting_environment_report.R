#!/usr/local/bin/Rscript
library(tidyverse)
library(lubridate)
library(emayili)
library(rmarkdown)
#library(notifier)
library(odbc)
library(DBI)
library(dplyr)
library(knitr)

# config for automation
config <- read_csv("C:/Users/april.welch/Downloads/config.csv")
recipients <- "april.welch@baltimorecity.gov"
#config$recipient_url
filename <- paste0("shooting_environment_report_", today(), ".nb.html")
analytics_filename <- paste0("performance_analytics_", today(), ".nb.html")
#csv_filename <- paste0("shooting_environment_report_data_", "2020-12-08", ".csv")

# not sure why this is needed to find pandoc
Sys.setenv(RSTUDIO_PANDOC="C:\\Program Files\\Pandoc")




tryCatch({
  # connection to sql server
  con <-dbConnect(odbc::odbc(),
                  Driver = "SQL Server",
                  Server = "BALT-SQL-FC",
                  Database = "CitiStat",
                  Trusted_Connection = "True",
                  host = "localhost",
                  port = 1433)
}, error = function(err) {
  
  # if analytics report fails to render send me an email
  print("Please connect to VPN and manually rerun.",  title  = "Shooting Environment Report")
  
  render_email <- envelope() %>%
    emayili::from(config$from_address) %>%
    emayili::to(Sys.getenv("april.welch@baltimorecity.gov")) %>%
    emayili::subject("Shooting Environment Report: Not Connected to VPN") %>%
    emayili::html("Connect to VPN and manually run report script.")
  
  smtp <- server(host = "smtp.gmail.com",
                 port = 587,
                 username = config$from_address,
                 password = config$password)
  
  smtp(render_email)
}
)


message(paste0(Sys.time(), ": Getting crime data from SQL server"))

# part 1 crime query
violent_crime <- tbl(con, "Part1_Crime")  %>%
  filter(`Crime Date` >= "2020-01-01")

# sr query
#sr <- tbl(con, "CSR")  %>%
 # filter(`Created Date` >= "2021-02-10")
sr <- dbGetQuery(con, "SELECT [SR ID],
[Service Request Number],
[SR Type],
[Agency],
[Created Date],
[SR Status],
[Status Date],
[Priority],
[Due Date],
[Week Number],
[Street Address],
[Zip Code],
[Neighborhood],
[Latitude],
[Longitude],
[Police District],
[Council District],
[geo_east_west],
[Close Date],
[CHIP ID],
[SF Source],
[Contact Email],
[Borough],
[HashedRecord]
FROM CitiStat.dbo.CSR
Where [Created Date] >= \'2020-01-01\'")
# run queries 
violent_crime <- collect(violent_crime)
message(paste0(Sys.time(), ": Crime data retrieved from SQL server"))
sr <- collect(sr)
message(paste0(Sys.time(), ": Service request data retrieved from SQL server"))

# clean up field names in violent crime
names(violent_crime)<-str_replace_all(names(violent_crime), c(" " = "" ))
names(sr)<-str_replace_all(names(sr), c(" " = "" ))

violent_crime <- violent_crime %>%
  rename_all(funs(tolower)) %>%
  rename(district = "policedistrict")

sr <- sr %>%
  rename_all(funs(tolower)) %>%
  rename("servicerequestnum" = "servicerequestnumber")

# get date of last crime in table
last_crime <- max(as.Date(violent_crime$crimedate), na.rm = T)

# filter crime down to shootings in last week 
shootings <- violent_crime %>%
  filter(description %in% c("HOMICIDE", "SHOOTING"),
         crimedate <= last_crime - 2,
         crimedate >= last_crime - 9)

# get latitude and longitude from geometry
# sr <- sr %>%
#   mutate(
#     latitude = unlist(map(sr$geometry,1)),
#     longitude = unlist(map(sr$geometry,2)))

# Render analytics report ------------------

message(paste0(Sys.time(), ": Starting report render"))

tryCatch({
  
  if (last_crime >= today() -  7){
    
    # render analytics report
    rmarkdown::render(
      input = "analytics.Rmd",
      output_file = analytics_filename,
      #output_file = "example.nb.html",
      #output_file = "garbage.nb.html",
      output_dir = "reports",
      clean = T
    ) 
    
  } else {
    
    # send me an email if the data out of date (deprecate)
    #notify("Open Baltimore is more than one week out of date. Report not rendered.",  
     #      title  = "Shooting Environment Report")
    
    ob_ood_email <- envelope() %>%
      emayili::from(config$from_address) %>%
      emayili::to(Sys.getenv("CITY_EMAIL")) %>%
      emayili::subject("Shooting Environment Report: Open Baltimore Out of Date") %>%
      emayili::html("Open Baltimore is more than one week out of date. Contact BPD & BCIT to refresh.")
    
    smtp <- server(host = "smtp.gmail.com",
                   port = 587,
                   username = config$from_address,
                   password = config$password)
    
    smtp(ob_ood_email)
  }
  
  
}, error = function(err) {
  
  # if analytics report fails to render send me an email
#  notify("Analytics report rendering failed. Check logs.",  title  = "Shooting Environment Report")
  
  render_email <- envelope() %>%
    emayili::from(getElement(config, "from_address")) %>%
    emayili::to(Sys.getenv("CITY_EMAIL")) %>%
    emayili::subject("Shooting Environment Report: Analytics Render Failure") %>%
    emayili::html("Analytics report failed to render. Check logs.")
  
  smtp <- server(host = "smtp.gmail.com",
                 port = 587,
                 username = config$from_address,
                 password = config$password)
  
  smtp(render_email)
  
})


# Render new shooting environment report ---------------

tryCatch({
  
  if (last_crime >= today() -  7){
    
    # render report
    rmarkdown::render(
      input = "shooting_environment_report.Rmd",
      output_file = filename,
      #output_file = "example.nb.html",
      #output_file = "garbage.nb.html",
      output_dir = "reports",
      clean = T
    ) 
    
  } else {
    
    # if data out of date send me an email (deprecate)
   # notify("Open Baltimore is more than one week out of date. Report not rendered.",  title  = "Shooting Environment Report")
    
    ob_ood_email <- envelope() %>%
      emayili::from(config$from_address) %>%
      emayili::to(Sys.getenv("CITY_EMAIL")) %>%
      emayili::subject("Shooting Environment Report: Open Baltimore Out of Date") %>%
      emayili::html("Open Baltimore is more than one week out of date. Contact BPD & BCIT to refresh.")
    
    smtp <- server(host = "smtp.gmail.com",
                   port = 587,
                   username = config$from_address,
                   password = config$password)
    
    smtp(ob_ood_email)
  }
  
  
}, error = function(err) {
  
  # if report render fails send me an email
 # notify("Report Rendering Failed. Check Logs.",  title  = "Shooting Environment Report")
  
  render_email <- envelope() %>%
    emayili::from(config$from_address) %>%
    emayili::to(Sys.getenv("CITY_EMAIL")) %>%
    emayili::subject("Shooting Environment Report: Render Failure") %>%
    emayili::html("Shooting environment report failed to render. Check logs.")
  
  smtp <- server(host = "smtp.gmail.com",
                 port = 587,
                 username = config$from_address,
                 password = config$password)
  
  smtp(render_email)
  
})


# Send out new report and analytics report ---------

tryCatch({
  
  if (last_crime >= today() -  7){
    
    #attempt to send email
    email_subject <- paste0(
      "Shooting Environment Report, ", today()
    )
    
    email_message <-  read_file("email_message.txt")
    csv_filename <- paste0("shooting_environment_report_data_", today(), ".csv")
    
    email <- envelope() %>%
      emayili::from(config$from_address) %>%
      #emayili::to(guests$email_address) %>%
      emayili::to(Sys.getenv("CITY_EMAIL")) %>%
      emayili::subject(email_subject) %>%
      emayili::html(email_message) %>%
      emayili::attachment(
        path = paste0("reports/", filename),
        type = "text/html") %>%
      emayili::attachment(
        path = paste0("reports/", analytics_filename),
        type = "text/html") %>%
      emayili::attachment(
        path = paste0("reports/", csv_filename),
        type = "text/comma-separated-values")
   
    smtp <- server(host = "ssmtp.gmail.com",
                   port = 587,
                   username = config$from_address,
                   password = config$password)
    
    message(paste0(Sys.time(), ": Attempting email send"))
    smtp(email)
    message(paste0(Sys.time(), ": Emails sent"))
    
    # notify me on laptop that report is sent
  #  notify("Report sent.",  title  = "Shooting Environment Report")
    
    # move files to sent folder for analytics
    file.copy(paste0("reports/", csv_filename), "reports/sent/")
    file.copy(paste0("reports/", filename), "reports/sent/")
    file.copy(paste0("reports/", analytics_filename), "reports/sent/")
    file.remove(paste0("reports/", csv_filename))
    file.remove(paste0("reports/", filename))
    file.remove(paste0("reports/", analytics_filename))
  }
  
  
}, error = function(err) {
  
  # notification on laptop if email fails
 # notify("Report email failed to send.",  title  = "Shooting Environment Report")
  
  # also try to email me that the email failed
  render_email <- envelope() %>%
    emayili::from(config$from_address) %>%
    emayili::to(config$recipient_url) %>%
    emayili::subject("Shooting Environment Report: Email Failure") %>%
    emayili::html("Shooting environment email failed to send. Check logs.")
  
  smtp <- server(host = "smtp.gmail.com",
                 port = 587,
                 username = config$from_address,
                 password = config$password)
  
  smtp(render_email)
  
})
