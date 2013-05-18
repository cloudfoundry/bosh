# Copyright (c) 2009-2012 VMware, Inc.

source 'https://rubygems.org'

ruby '1.9.3'

gem "agent_client", :path => "agent_client"
gem "blobstore_client", :path => "blobstore_client"
gem "bosh_agent", :path => "bosh_agent"
gem "bosh_aws_cpi", :path => "bosh_aws_cpi"
gem "bosh_common", :path => "bosh_common"
gem "bosh_cpi", :path => "bosh_cpi"
gem "bosh_cli", :path => "bosh_cli"
gem "bosh_cli_plugin_aws", :path => "bosh_cli_plugin_aws"
gem "bosh_cli_plugin_micro", :path => "bosh_cli_plugin_micro"
gem "bosh_encryption", :path => "bosh_encryption"
gem "bosh_openstack_cpi", :path => "bosh_openstack_cpi"
gem "bosh_registry", :path => "bosh_registry"
gem "bosh_vcloud_cpi", :path => "bosh_vcloud_cpi"
gem "bosh_vsphere_cpi", :path => "bosh_vsphere_cpi"
gem "director", :path => "director"
gem "health_monitor", :path => "health_monitor"
gem "monit_api", :path => "monit_api"
gem "package_compiler", :path => "package_compiler"
gem "ruby_vcloud_sdk", :path => "ruby_vcloud_sdk"
gem "ruby_vim_sdk", :path => "ruby_vim_sdk"
gem "simple_blobstore_server", :path => "simple_blobstore_server"

gem "rake", "~>10.0"

group :production do
  # this was pulled from bosh_aws_registry's Gemfile.  Why does it exist?
  # also bosh_openstack_registry, director
  gem "pg"
  gem "mysql"
end

group :development do
  gem "ruby_gntp"
  gem "debugger" if RUBY_VERSION < "2.0.0"

  gem "fpm", github: "mmb/fpm", branch: "control_tar_group"
end

group :bat do
  gem "httpclient"
  gem "json"
  gem "minitar"
  gem "net-ssh"
end

group :development, :test do
  gem "parallel_tests"
  gem "rack-test"
  gem "guard"
  gem "guard-bundler"
  gem "guard-rspec"
  gem "ci_reporter"
  gem "rspec"
  gem "tracker-git", github: "cboone/tracker-git", branch: "edge"
  gem "webmock"

  gem "simplecov"
  gem "simplecov-rcov"

  # for director
  gem "machinist", "~>1.0"

  # for root level specs
  gem "rest-client"
  gem "redis"
  gem "nats"
  gem "rugged"

  # from ruby_vcloud_sdk
  gem "nokogiri-diff"

  gem "sqlite3"
end
