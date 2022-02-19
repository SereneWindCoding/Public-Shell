#!/usr/bin/env bash

wget -N --no-check-certificate https://raw.githubusercontent.com/SereneWindCoding/Public-Shell/main/cleanlog/cleanlog.sh -P /home/cleanlog/
chmod +x /home/cleanlog/cleanlog.sh

cat >> /var/spool/cron/crontabs/root <<EOF
0 2 * * * bash /home/cleanlog/cleanlog.sh
EOF

echo "Job Done"