#!/bin/sh

wget -P /opt/logclean/ -N --no-check-certificate https://rawgithubusercontent.ninjacloudnetworks.workers.dev/SereneWindCoding/Public-Shell/main/logclean.sh
chmod +x /opt/logclean/logclean.sh

cat >> /var/spool/cron/crontabs/root <<EOF
0 0 * * * bash /opt/logclean/logclean.sh
EOF