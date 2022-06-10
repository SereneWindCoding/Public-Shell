#!/usr/bin/env bash

wget -N --no-check-certificate https://download.renzhe.work/cuocuo -O /usr/bin/cuocuo
chmod +x /usr/bin/cuocuo
echo "Finished"
shutdown -r now