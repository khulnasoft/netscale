// +build fips

package main

import (
    _ "crypto/tls/fipsonly"
    "github.com/khulnasoft/netscale/cmd/netscale/tunnel"
)

func init () {
    tunnel.FipsEnabled = true
}
