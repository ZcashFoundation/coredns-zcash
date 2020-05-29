#!/bin/bash

set -exuo pipefail

WORKDIR="$(pwd)"
BUILD_DIR=$(mktemp -d)
COREDNS_VERSION="v1.6.9"

git clone --branch ${COREDNS_VERSION} https://github.com/coredns/coredns ${BUILD_DIR}
cd ${BUILD_DIR}
echo "dnsseed:github.com/zcashfoundation/dnsseeder/dnsseed" >> plugin.cfg
echo "replace github.com/btcsuite/btcd => github.com/gtank/btcd v0.0.0-20191012142736-b43c61a68604" >> go.mod
make

if [ ! -d ${WORKDIR}/build_output ]; then
    mkdir ${WORKDIR}/build_output
fi

cp ${BUILD_DIR}/coredns ${WORKDIR}/build_output/coredns
cd ${WORKDIR}
rm -rf ${BUILD_DIR}
