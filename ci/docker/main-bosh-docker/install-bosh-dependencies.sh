#!/bin/bash -ex

apt-get update && apt-get -y install zip

pushd /tmp > /dev/null
    curl -o bosh-deployment.zip https://codeload.github.com/cloudfoundry/bosh-deployment/zip/master
    unzip bosh-deployment.zip
    mv bosh-deployment-master /usr/local/bosh-deployment
    rm bosh-deployment.zip
popd > /dev/null

curl -o /usr/local/bin/bosh https://s3.amazonaws.com/bosh-cli-artifacts/bosh-cli-2.0.2-linux-amd64
chmod +x /usr/local/bin/bosh