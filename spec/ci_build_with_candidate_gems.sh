#!/bin/bash -l
#set -e
source .rvmrc

rvm gemset use ci_gems --create
rvm --force gemset empty ci_gems

gem install --no-ri --no-rdoc rake -v $(grep "rake" Gemfile | tr "'" '"' | cut -d '"' -f 4)
gem install --no-ri --no-rdoc ci_reporter rspec rugged parallel_tests
gem install --no-ri --no-rdoc \
    --source https://s3.amazonaws.com/bosh-ci-pipeline/gems/ \
    --pre \
    agent_client \
    blobstore_client \
    bosh_agent \
    bosh_aws_cpi \
    bosh_cli \
    bosh_cli_plugin_aws \
    bosh_cli_plugin_micro \
    bosh_common \
    bosh_cpi \
    bosh_encryption \
    bosh_openstack_cpi \
    bosh_registry \
    bosh_vcloud_cpi \
    bosh_vsphere_cpi \
    director \
    health_monitor \
    monit_api \
    package_compiler \
    ruby_vcloud_sdk \
    ruby_vim_sdk \
    simple_blobstore_server

bosh -v
rake $@