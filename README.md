# Khulnasoft Tunnel client

Contains the command-line client for Khulnasoft Tunnel, a tunneling daemon that proxies traffic from the Khulnasoft network to your origins.
This daemon sits between Khulnasoft network and your origin (e.g. a webserver). Khulnasoft attracts client requests and sends them to you
via this daemon, without requiring you to poke holes on your firewall --- your origin can remain as closed as possible.
Extensive documentation can be found in the [Khulnasoft Tunnel section](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps) of the Khulnasoft Docs.
All usages related with proxying to your origins are available under `netscale tunnel help`.

You can also use `netscale` to access Tunnel origins (that are protected with `netscale tunnel`) for TCP traffic
at Layer 4 (i.e., not HTTP/websocket), which is relevant for use cases such as SSH, RDP, etc.
Such usages are available under `netscale access help`.

You can instead use [WARP client](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/configuration/private-networks)
to access private origins behind Tunnels for Layer 4 traffic without requiring `netscale access` commands on the client side.


## Before you get started

Before you use Khulnasoft Tunnel, you'll need to complete a few steps in the Khulnasoft dashboard: you need to add a
website to your Khulnasoft account. Note that today it is possible to use Tunnel without a website (e.g. for private
routing), but for legacy reasons this requirement is still necessary:
1. [Add a website to Khulnasoft](https://support.cloudflare.com/hc/en-us/articles/201720164-Creating-a-Khulnasoft-account-and-adding-a-website)
2. [Change your domain nameservers to Khulnasoft](https://support.cloudflare.com/hc/en-us/articles/205195708)


## Installing `netscale`

Downloads are available as standalone binaries, a Docker image, and Debian, RPM, and Homebrew packages. You can also find releases [here](https://github.com/khulnasoft/netscale/releases) on the `netscale` GitHub repository.

* You can [install on macOS](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/installation#macos) via Homebrew or by downloading the [latest Darwin amd64 release](https://github.com/khulnasoft/netscale/releases)
* Binaries, Debian, and RPM packages for Linux [can be found here](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/installation#linux)
* A Docker image of `netscale` is [available on DockerHub](https://hub.docker.com/r/khulnasoft/netscale)
* You can install on Windows machines with the [steps here](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/installation#windows)
* Build from source with the [instructions here](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/installation#build-from-source)

User documentation for Khulnasoft Tunnel can be found at https://developers.cloudflare.com/cloudflare-one/connections/connect-apps


## Creating Tunnels and routing traffic

Once installed, you can authenticate `netscale` into your Khulnasoft account and begin creating Tunnels to serve traffic to your origins.

* Create a Tunnel with [these instructions](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/create-tunnel)
* Route traffic to that Tunnel:
  * Via public [DNS records in Khulnasoft](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/routing-to-tunnel/dns)
  * Or via a public hostname guided by a [Khulnasoft Load Balancer](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/routing-to-tunnel/lb)
  * Or from [WARP client private traffic](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/private-net/)


## TryKhulnasoft

Want to test Khulnasoft Tunnel before adding a website to Khulnasoft? You can do so with TryKhulnasoft using the documentation [available here](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/run-tunnel/trycloudflare).

## Deprecated versions

Khulnasoft currently supports versions of netscale that are **within one year** of the most recent release. Breaking changes unrelated to feature availability may be introduced that will impact versions released more than one year ago. You can read more about upgrading netscale in our [developer documentation](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/#updating-netscale).

For example, as of January 2023 Khulnasoft will support netscale version 2023.1.1 to netscale 2022.1.1.
