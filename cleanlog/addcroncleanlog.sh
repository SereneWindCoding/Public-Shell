#!/usr/bin/env bash

wget -N --no-check-certificate https://rawgithubusercontent.ninjacloudnetworks.workers.dev/SereneWindCoding/Public-Shell/main/cleanlog/cleanlog.sh -P /home/cleanlog/
chmod +x /home/cleanlog/cleanlog.sh

cat >> /var/spool/cron/crontabs/root <<EOF
00 6 * * * bash /home/cleanlog/cleanlog.sh
EOF

systemctl restart cron

echo "Job Done"