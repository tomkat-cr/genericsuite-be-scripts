#!/bin/sh
# Ports in use
sudo lsof -PiTCP -sTCP:LISTEN
