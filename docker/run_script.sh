#!/bin/bash

git -C OptionSmile pull

dolt creds check
dolt --data-dir=/data sql-server &

# wait until sql-server is up
sleep 10

python3 OptionSmile/script/calculate_and_store.py
