#!/bin/bash

set -uxeo pipefail

systemctl stop dnsseeder

rm /etc/systemd/system/multi-user.target.wants/dnsseeder.service
rm /etc/systemd/system/dnsseeder.service
rm /etc/systemd/resolved.conf.d/10-resolved-override.conf

rm -r /etc/dnsseeder

systemctl daemon-reload
systemctl restart systemd-resolved
