#!/bin/bash

/usr/local/bin/netscale service uninstall
rm /usr/local/bin/netscale
pkgutil --forget com.khulnasoft.netscale