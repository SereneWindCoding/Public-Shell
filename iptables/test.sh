#!/bin/bash

# 遍历所有表
for table in filter nat mangle; do
    echo "Clearing 80 and 443 rules from $table table..."

    # 删除INPUT链中与80和443端口相关的规则
    iptables -t $table -S INPUT | grep -E "dport (80|443)" | while read line; do
        rule=$(echo $line | sed 's/-A/-D/')
        iptables -t $table $rule
        echo "Deleted from INPUT: $rule"
    done

    # 删除OUTPUT链中与80和443端口相关的规则
    iptables -t $table -S OUTPUT | grep -E "sport (80|443)" | while read line; do
        rule=$(echo $line | sed 's/-A/-D/')
        iptables -t $table $rule
        echo "Deleted from OUTPUT: $rule"
    done

    # 删除FORWARD链中与80和443端口相关的规则
    iptables -t $table -S FORWARD | grep -E "dport (80|443)" | while read line; do
        rule=$(echo $line | sed 's/-A/-D/')
        iptables -t $table $rule
        echo "Deleted from FORWARD: $rule"
    done

done

echo "All 80 and 443 port rules cleared from iptables."

# 检查规则是否已成功删除
echo "Current iptables rules:"
iptables -L -n -v
