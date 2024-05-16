#!/bin/sh
# scripts/show_date_time.sh
# 2024-05-03 | CR
if [ "${APP_TZ}" = "" ]; then
  APP_TZ='America/New_York'
fi
echo ""
TZ="${APP_TZ}" date
