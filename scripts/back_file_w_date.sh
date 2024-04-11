#!/bin/sh
# scripts/back_file_w_date.sh
# 2023-07-20 | CR

if [ "$1" = "" ]; then
    echo "Usage: sh back_file_w_date.sh <filename>"
    exit 1
fi
if [ ! -f "$1" ]; then
    echo "ERROR: File not found: $1"
    exit 1
fi
BACKUP_FILENAME="$1.`date +%Y-%m-%d_%H-%M-%s`.bak"
cp "$1" ${BACKUP_FILENAME}
echo "${BACKUP_FILENAME}"
