include_recipe "env"
include_recipe "ruby"
include_recipe "rubygems"
include_recipe "runit"

gem_package "nats" do
  version node[:nats][:version]
  gem_binary "#{node[:ruby][:path]}/bin/gem"
end

directory node[:nats][:path] do
  mode 0775
  owner node[:nats][:runner]
  group node[:nats][:runner]
  action :create
  recursive true
end

template "#{node[:nats][:path]}/nats.yml" do
  source "nats.yml.erb"
  owner node[:nats][:runner]
  group node[:nats][:runner]
  notifies :restart, "service[nats]"
end

runit_service "nats"