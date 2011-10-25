include_recipe "env"
include_recipe "ruby"
include_recipe "rubygems"
include_recipe "runit"

gem_package "nats" do
  version node[:event_nats][:version]
  gem_binary "#{node[:ruby][:path]}/bin/gem"
end

directory node[:event_nats][:path] do
  mode 0775
  owner node[:event_nats][:runner]
  group node[:event_nats][:runner]
  action :create
  recursive true
end

template "#{node[:event_nats][:path]}/nats.yml" do
  source "nats.yml.erb"
  owner node[:event_nats][:runner]
  group node[:event_nats][:runner]
  notifies :restart, "service[event_nats]"
end

runit_service "event_nats"
