#!/usr/bin/env bash

cat /dev/null > /etc/soga/routes.toml
cat > /etc/soga/dns.yml <<EOF
192.168.8.8:
   - geosite:netflix
   - geosite:tvb
   - geosite:disney
EOF
soga restart