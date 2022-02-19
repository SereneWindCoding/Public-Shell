#!/usr/bin/env bash

echo "log clear start....."
find /etc/soga/access_log/ -type f -mtime +3 -name "*.csv" -exec rm -rf {} \;
echo "log clear end"