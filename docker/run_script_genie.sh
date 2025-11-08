#!/bin/bash

# make sure we get the latest code version
git -C /OptionSmile pull

# make sure we get updated data
dolt config --global --add user.email "sschlenkrich@localhost"
dolt config --global --add user.name  "sschlenkrich"
#
cd /data/volatilities
dolt pull
#
cd /data/stocks
dolt pull

# prepare...
cd /OptionSmile/genie_app
# log the version we are running
git rev-parse --short HEAD > commit.txt

# start sql server
dolt --data-dir=/data sql-server &

# wait until sql-server is up
sleep 10

# start the app and server
julia --project -e "using GenieFramework; Genie.loadapp(); up(async=false);"
