#!/bin/bash
set -eu
ln -s /usr/bin/netscale /usr/local/bin/netscale
mkdir -p /usr/local/etc/netscale/
touch /usr/local/etc/netscale/.installedFromPackageManager || true
