#!/bin/bash
# Deployment of the DNS seeder with systemd
#
# Usage: sudo ./install_systemd.sh <domain>
# Example: sudo ./install_systemd.sh seeder.zfnd.org

set -uxeo pipefail

mkdir -p /etc/dnsseeder

if [ ! -d /etc/systemd/resolved.conf.d ]; then
    mkdir /etc/systemd/resolved.conf.d
fi

cp build_output/coredns /etc/dnsseeder/coredns

cat <<EOF > /etc/dnsseeder/Corefile
# Replace systemd-resolved so we can bind .:53 without breaking the system DNS.
# Load-balances forwarded queries across Cloudflare and both Google DNS servers
. {
    bind 127.0.0.53
    forward . 1.1.1.1 8.8.8.8 8.8.4.4 {
        except ${1}
    }
}

EOF

cat coredns/Corefile >> /etc/dnsseeder/Corefile

cp systemd/dnsseeder.service /etc/dnsseeder/
cp systemd/10-resolved-override.conf /etc/dnsseeder/

ln -sf /etc/dnsseeder/dnsseeder.service /etc/systemd/system/
ln -sf /etc/dnsseeder/dnsseeder.service /etc/systemd/system/multi-user.target.wants/
ln -sf /etc/dnsseeder/10-resolved-override.conf /etc/systemd/resolved.conf.d/

systemctl daemon-reload
systemctl stop systemd-resolved
systemctl start dnsseeder
systemctl start systemd-resolved
