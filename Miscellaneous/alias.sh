#!/usr/bin/env bash

#CF
auth_email=""
auth_key=""
zone_name=""
record_name1=""
record_name2=""
record_name3=""
record_name4=""

#Domain
Domain1=""
Domain2=""
Domain3=""
Domain4=""


ip1=$(nslookup $Domain1 |egrep 'Address.*'|awk '{if(NR!=1)print $NF}')
ip2=$(nslookup $Domain2 |egrep 'Address.*'|awk '{if(NR!=1)print $NF}')
ip3=$(nslookup $Domain3 |egrep 'Address.*'|awk '{if(NR!=1)print $NF}')
ip4=$(nslookup $Domain4 |egrep 'Address.*'|awk '{if(NR!=1)print $NF}')
ip1_file="ip1.txt"
ip2_file="ip2.txt"
ip3_file="ip3.txt"
ip4_file="ip4.txt"
id1_file="cloudflare1.ids"
id2_file="cloudflare2.ids"
id3_file="cloudflare3.ids"
id4_file="cloudflare4.ids"
log1_file="cloudflare1.log"
log2_file="cloudflare2.log"
log3_file="cloudflare3.log"
log4_file="cloudflare4.log"

# LOGGER1
log() {
    if [ "$1" ]; then
        echo -e "[$(date)] - $1" >> $log1_file
    fi
}

# SCRIPT START
log "Check Initiated"

if [ -f $ip1_file ]; then
    old1_ip=$(cat $ip1_file)
    if [ $ip1 == $old1_ip ]; then
        echo "IP has not changed."
        exit 0
    fi
fi

if [ -f $id1_file ] && [ $(wc -l $id1_file | cut -d " " -f 1) == 2 ]; then
    zone_identifier=$(head -1 $id1_file)
    record_identifier=$(tail -1 $id1_file)
else
    zone_identifier=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$zone_name" -H "X-Auth-Email: $auth_email" -H "X-Auth-Key: $auth_key" -H "Content-Type: application/json" | grep -Po '(?<="id":")[^"]*' | head -1 )
    record_identifier=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$zone_identifier/dns_records?name=$record_name1" -H "X-Auth-Email: $auth_email" -H "X-Auth-Key: $auth_key" -H "Content-Type: application/json"  | grep -Po '(?<="id":")[^"]*')
    echo "$zone_identifier" > $id1_file
    echo "$record_identifier" >> $id1_file
fi

update=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$zone_identifier/dns_records/$record_identifier" -H "X-Auth-Email: $auth_email" -H "X-Auth-Key: $auth_key" -H "Content-Type: application/json" --data "{\"id\":\"$zone_identifier\",\"type\":\"A\",\"name\":\"$record_name1\",\"content\":\"$ip1\",\"ttl\":\"60\"}")

if [[ $update == *"\"success\":false"* ]]; then
    message="API UPDATE FAILED. DUMPING RESULTS:\n$update"
    log "$message"
    echo -e "$message"
    exit 1 
else
    message="IP changed to: $ip1"
    echo "$ip1" > $ip1_file
    log "$message"
    echo "$message"
fi

# LOGGER2
log() {
    if [ "$1" ]; then
        echo -e "[$(date)] - $1" >> $log2_file
    fi
}

# SCRIPT START
log "Check Initiated"

if [ -f $ip2_file ]; then
    old2_ip=$(cat $ip2_file)
    if [ $ip2 == $old2_ip ]; then
        echo "IP has not changed."
        exit 0
    fi
fi

if [ -f $id2_file ] && [ $(wc -l $id2_file | cut -d " " -f 1) == 2 ]; then
    zone_identifier=$(head -1 $id2_file)
    record_identifier=$(tail -1 $id2_file)
else
    zone_identifier=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$zone_name" -H "X-Auth-Email: $auth_email" -H "X-Auth-Key: $auth_key" -H "Content-Type: application/json" | grep -Po '(?<="id":")[^"]*' | head -1 )
    record_identifier=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$zone_identifier/dns_records?name=$record_name2" -H "X-Auth-Email: $auth_email" -H "X-Auth-Key: $auth_key" -H "Content-Type: application/json"  | grep -Po '(?<="id":")[^"]*')
    echo "$zone_identifier" > $id2_file
    echo "$record_identifier" >> $id2_file
fi

update=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$zone_identifier/dns_records/$record_identifier" -H "X-Auth-Email: $auth_email" -H "X-Auth-Key: $auth_key" -H "Content-Type: application/json" --data "{\"id\":\"$zone_identifier\",\"type\":\"A\",\"name\":\"$record_name2\",\"content\":\"$ip2\",\"ttl\":\"60\"}")

if [[ $update == *"\"success\":false"* ]]; then
    message="API UPDATE FAILED. DUMPING RESULTS:\n$update"
    log "$message"
    echo -e "$message"
    exit 1 
else
    message="IP changed to: $ip2"
    echo "$ip2" > $ip2_file
    log "$message"
    echo "$message"
fi

# LOGGER3
log() {
    if [ "$1" ]; then
        echo -e "[$(date)] - $1" >> $log3_file
    fi
}

# SCRIPT START
log "Check Initiated"

if [ -f $ip3_file ]; then
    old3_ip=$(cat $ip3_file)
    if [ $ip3 == $old3_ip ]; then
        echo "IP has not changed."
        exit 0
    fi
fi

if [ -f $id3_file ] && [ $(wc -l $id3_file | cut -d " " -f 1) == 2 ]; then
    zone_identifier=$(head -1 $id3_file)
    record_identifier=$(tail -1 $id3_file)
else
    zone_identifier=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$zone_name" -H "X-Auth-Email: $auth_email" -H "X-Auth-Key: $auth_key" -H "Content-Type: application/json" | grep -Po '(?<="id":")[^"]*' | head -1 )
    record_identifier=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$zone_identifier/dns_records?name=$record_name3" -H "X-Auth-Email: $auth_email" -H "X-Auth-Key: $auth_key" -H "Content-Type: application/json"  | grep -Po '(?<="id":")[^"]*')
    echo "$zone_identifier" > $id3_file
    echo "$record_identifier" >> $id3_file
fi

update=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$zone_identifier/dns_records/$record_identifier" -H "X-Auth-Email: $auth_email" -H "X-Auth-Key: $auth_key" -H "Content-Type: application/json" --data "{\"id\":\"$zone_identifier\",\"type\":\"A\",\"name\":\"$record_name3\",\"content\":\"$ip3\",\"ttl\":\"60\"}")

if [[ $update == *"\"success\":false"* ]]; then
    message="API UPDATE FAILED. DUMPING RESULTS:\n$update"
    log "$message"
    echo -e "$message"
    exit 1 
else
    message="IP changed to: $ip3"
    echo "$ip3" > $ip3_file
    log "$message"
    echo "$message"
fi

# LOGGER4
log() {
    if [ "$1" ]; then
        echo -e "[$(date)] - $1" >> $log4_file
    fi
}

# SCRIPT START
log "Check Initiated"

if [ -f $ip4_file ]; then
    old4_ip=$(cat $ip4_file)
    if [ $ip4 == $old4_ip ]; then
        echo "IP has not changed."
        exit 0
    fi
fi

if [ -f $id4_file ] && [ $(wc -l $id4_file | cut -d " " -f 1) == 2 ]; then
    zone_identifier=$(head -1 $id4_file)
    record_identifier=$(tail -1 $id4_file)
else
    zone_identifier=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$zone_name" -H "X-Auth-Email: $auth_email" -H "X-Auth-Key: $auth_key" -H "Content-Type: application/json" | grep -Po '(?<="id":")[^"]*' | head -1 )
    record_identifier=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$zone_identifier/dns_records?name=$record_name4" -H "X-Auth-Email: $auth_email" -H "X-Auth-Key: $auth_key" -H "Content-Type: application/json"  | grep -Po '(?<="id":")[^"]*')
    echo "$zone_identifier" > $id4_file
    echo "$record_identifier" >> $id4_file
fi

update=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$zone_identifier/dns_records/$record_identifier" -H "X-Auth-Email: $auth_email" -H "X-Auth-Key: $auth_key" -H "Content-Type: application/json" --data "{\"id\":\"$zone_identifier\",\"type\":\"A\",\"name\":\"$record_name4\",\"content\":\"$ip4\",\"ttl\":\"60\"}")

if [[ $update == *"\"success\":false"* ]]; then
    message="API UPDATE FAILED. DUMPING RESULTS:\n$update"
    log "$message"
    echo -e "$message"
    exit 1 
else
    message="IP changed to: $ip4"
    echo "$ip4" > $ip4_file
    log "$message"
    echo "$message"
fi