# Copyright (c) 2009-2012 VMware, Inc.

source 'https://rubygems.org' 

gem "agent_client", path: "agent_client"
gem "blobstore_client", path: "blobstore_client"
gem "bosh_agent", path: "bosh_agent"
gem "bosh_aws_bootstrap", path: "bosh_aws_bootstrap"
gem "bosh_aws_cpi", path: "bosh_aws_cpi"
gem "bosh_aws_registry", path: "bosh_aws_registry"
gem "bosh_common", path: "bosh_common"
gem "bosh_cpi", path: "bosh_cpi"
gem "bosh_cli", path: "bosh_cli"
gem "bosh_deployer", path: "bosh_deployer"
gem "bosh_encryption", path: "bosh_encryption"
gem "bosh_openstack_cpi", path: "bosh_openstack_cpi"
gem "bosh_openstack_registry", path: "bosh_openstack_registry"
gem "bosh_vcloud_cpi", path: "bosh_vcloud_cpi"
gem "bosh_vsphere_cpi", path: "bosh_vsphere_cpi"
gem "director", path: "director"
gem "health_monitor", path: "health_monitor"
gem "monit_api", path: "monit_api"
gem "package_compiler", path: "package_compiler"
gem "ruby_vcloud_sdk", path: "ruby_vcloud_sdk"
gem "ruby_vim_sdk", path: "ruby_vim_sdk"
gem "simple_blobstore_server", path: "simple_blobstore_server"

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

group :bat do
  gem "httpclient"
  gem "json"
  gem "minitar"
  gem "net-ssh"
end

group :development, :test do

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

  gem "sqlite3"

  #  gem "guard-yard"
  #  gem "redcarpet"
  #  gem "rb-fsevent"
end
