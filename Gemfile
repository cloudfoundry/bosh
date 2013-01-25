# Copyright (c) 2009-2012 VMware, Inc.

source :rubygems

gem "bosh_agent", path: "bosh_agent"
gem "bosh_common", path: "common"
gem "bosh_cpi", path: "cpi"
gem "agent_client", path: "agent_client"
gem "bosh_aws_bootstrap", path: "aws_bootstrap"
gem "bosh_aws_cpi", path: "aws_cpi"
gem "bosh_aws_registry", path: "aws_registry"
gem "blobstore_client", path: "blobstore_client"
gem "simple_blobstore_server", path: "simple_blobstore_server"
gem "bosh_cli", path: "cli"
gem "director", path: "director"
gem "health_monitor", path: "health_monitor"
gem "bosh_deployer", path: "deployer"
gem "bosh_encryption", path: "encryption"
gem "monit_api", path: "monit_api"
gem "bosh_openstack_registry", path: "openstack_registry"
gem "package_compiler", path: "package_compiler"
gem "ruby_vcloud_sdk", path: "ruby_vcloud_sdk"
gem "ruby_vim_sdk", path: "ruby_vim_sdk"
gem "bosh_vcloud_cpi", path: "vcloud_cpi"
gem "bosh_vsphere_cpi", path: "vsphere_cpi"

gem "rake", "~>10.0"

group :production do
  # this was pulled from bosh_aws_registry's Gemfile.  Why does it exist?
  # also bosh_openstack_registry, director
  gem "pg"
end

group :development do
  gem "ruby_gntp"
  gem "ruby-debug19"
end

group :development, :test do

  # for BAT
  gem "httpclient"
  gem "json"
  gem "minitar"
  gem "net-ssh"

  gem "rack-test"
  gem "guard"
  gem "guard-bundler"
  gem "guard-rspec"
  gem "ci_reporter"
  gem "rspec"

  gem "simplecov"
  gem "simplecov-rcov"

  # for director
  gem "machinist", "~>1.0"

  # for root level specs
  gem "rest-client"
  gem "redis"
  gem "nats"

  # from ruby_vcloud_sdk
  gem "nokogiri-diff"

  # this was pulled from bosh_aws_registry's Gemfile.  Why does it exist?
  # also bosh_openstack_registry, vsphere_cpi, director
  gem "sqlite3"

  #  gem "guard-yard"
  #  gem "redcarpet"
  #  gem "rb-fsevent"
end
