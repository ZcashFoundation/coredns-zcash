#!/bin/bash
#
# GCP Container OS Startup Script for Zcash DNS Seeder
#
# This script prepares the host for running the DNS seeder container.
# The container uses its built-in Corefile with ZFND defaults.
#
# To customize the Corefile, create /etc/dnsseeder/Corefile on the host
# and mount it into the container with: -v /etc/dnsseeder:/etc/dnsseeder:ro
#

set -euo pipefail

# Stop systemd-resolved to free port 53
systemctl stop systemd-resolved || true

# Ensure DNS resolution works by adding fallback nameservers
echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 8.8.4.4" >> /etc/resolv.conf
