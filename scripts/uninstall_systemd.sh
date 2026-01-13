#!/bin/bash
# Uninstall the DNS seeder systemd service

set -uxeo pipefail

systemctl stop dnsseeder

rm -f /etc/systemd/system/multi-user.target.wants/dnsseeder.service
rm -f /etc/systemd/system/dnsseeder.service
rm -f /etc/systemd/resolved.conf.d/10-resolved-override.conf

rm -rf /etc/dnsseeder

systemctl daemon-reload
systemctl restart systemd-resolved
