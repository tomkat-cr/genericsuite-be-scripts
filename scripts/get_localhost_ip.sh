#!/bin/bash
# get_localhost_ip.sh
# 2023-11-27 | CR
#
ip_address=$(ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1')
echo "$ip_address"

