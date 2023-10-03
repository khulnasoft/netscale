#!/bin/bash

set -euo pipefail

FILENAME="${PWD}/artifacts/netscale-darwin-amd64.tgz"
if ! VERSION="$(git describe --tags --exact-match 2>/dev/null)" ; then
    echo "Skipping public release for an untagged commit."
    echo "##teamcity[buildStatus status='SUCCESS' text='Skipped due to lack of tag']"
    exit 0
fi

if [[ ! -f "$FILENAME" ]] ; then
    echo "Missing $FILENAME"
    exit 1
fi

if [[ "${GITHUB_PRIVATE_KEY_B64:-}" == "" ]] ; then
    echo "Missing GITHUB_PRIVATE_KEY_B64"
    exit 1
fi

# upload to s3 bucket for use by Homebrew formula
s3cmd \
    --acl-public --access_key="$AWS_ACCESS_KEY_ID" --secret_key="$AWS_SECRET_ACCESS_KEY" --host-bucket="%(bucket)s.s3.cfdata.org" \
    put "$FILENAME" "s3://cftunnel-docs/dl/netscale-$VERSION-darwin-amd64.tgz"
s3cmd \
    --acl-public --access_key="$AWS_ACCESS_KEY_ID" --secret_key="$AWS_SECRET_ACCESS_KEY" --host-bucket="%(bucket)s.s3.cfdata.org" \
    cp "s3://cftunnel-docs/dl/netscale-$VERSION-darwin-amd64.tgz" "s3://cftunnel-docs/dl/netscale-stable-darwin-amd64.tgz"
SHA256=$(sha256sum "$FILENAME" | cut -b1-64)

# set up git (note that UserKnownHostsFile is an absolute path so we can cd wherever)
mkdir -p tmp
ssh-keyscan -t rsa github.com > tmp/github.txt
echo "$GITHUB_PRIVATE_KEY_B64" | base64 --decode > tmp/private.key
chmod 0400 tmp/private.key
export GIT_SSH_COMMAND="ssh -o UserKnownHostsFile=$PWD/tmp/github.txt -i $PWD/tmp/private.key -o IdentitiesOnly=yes"

# clone Homebrew repo into tmp/homebrew-khulnasoft
git clone git@github.com:khulnasoft/homebrew-khulnasoft.git tmp/homebrew-khulnasoft    
cd tmp/homebrew-khulnasoft
git checkout -f master
git reset --hard origin/master

# modify netscale.rb
URL="https://packages.argotunnel.com/dl/netscale-$VERSION-darwin-amd64.tgz"
tee netscale.rb <<EOF
class Netscale < Formula
  desc 'Khulnasoft Tunnel'
  homepage 'https://developers.khulnasoft.com/khulnasoft-one/connections/connect-apps'
  url '$URL'
  sha256 '$SHA256'
  version '$VERSION'
  def install
    bin.install 'netscale'
  end
end
EOF

# push netscale.rb
git add netscale.rb
git diff
git config user.name "khulnasoft-warp-bot"
git config user.email "warp-bot@khulnasoft.com"
git commit -m "Release Khulnasoft Tunnel $VERSION"

git push -v origin master
