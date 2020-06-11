#!/bin/bash

systemctl stop systemd-resolved

if [ ! -d /etc/dnsseeder ]; then
    mkdir -p /etc/dnsseeder
fi

cat <<EOF > /etc/dnsseeder/Corefile
mainnet.seeder.example.com {
    dnsseed {
        network mainnet
        bootstrap_peers mainnet.z.cash:8233 dnsseed.str4d.xyz:8233 mainnet.is.yolo.money:8233 mainnet.seeder.zfnd.org:8233
        crawl_interval 30m
        record_ttl 600
    }
}

testnet.seeder.example.com {
    dnsseed {
        network testnet
        bootstrap_peers testnet.z.cash:18233 testnet.is.yolo.money:18233 testnet.seeder.zfnd.org:18233
        crawl_interval 15m
        record_ttl 300
    }
}
EOF
