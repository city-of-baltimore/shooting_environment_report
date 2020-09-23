#!/usr/local/bin/bash
LOG_FILENAME="logs/report_$(date +"%Y-%m-%d").log"

cd ~/Google\ Drive/work_analysis/shooting_environment_report
/usr/local/bin/Rscript shooting_environment_report.R >& $LOG_FILENAME