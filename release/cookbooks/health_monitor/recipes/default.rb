include_recipe "env"
include_recipe "ruby"
include_recipe "rubygems"
include_recipe "runit"

runit_service "health_monitor" do
  run_restart false
end

package "git-core"

directory "#{node[:health_monitor][:path]}/shared" do
  owner node[:health_monitor][:runner]
  group node[:health_monitor][:runner]
  mode "0755"
  recursive true
  action :create
end

directory node[:health_monitor][:tmp] do
  mode "1777"
  recursive true
  action :create
end

%w{config gems logs}.each do |dir|
  directory "#{node[:health_monitor][:path]}/shared/#{dir}" do
    owner node[:health_monitor][:runner]
    group node[:health_monitor][:runner]
    mode "0755"
    action :create
  end
end

template "#{node[:health_monitor][:path]}/shared/config/health_monitor.yml" do
  source "health_monitor.yml.erb"
  owner node[:health_monitor][:runner]
  group node[:health_monitor][:runner]
  notifies :restart, "service[health_monitor]"
end

deploy_revision node[:health_monitor][:path] do
  scm_provider Chef::Provider::Git

  repo "#{node[:health_monitor][:repos_path]}/bosh"
  user node[:health_monitor][:runner]
  revision "HEAD"
  migrate false
  shallow_clone true
  action :deploy

  restart_command do
    execute "/usr/bin/sv restart health_monitor" do
      ignore_failure true
    end
  end

  symlink_before_migrate({})
  symlinks({})

  before_migrate do
    execute "#{node[:ruby][:path]}/bin/bundle install --deployment --without development test --local --path #{node[:health_monitor][:path]}/shared/gems" do
      ignore_failure true
      cwd "#{release_path}/health_monitor"
    end
  end
end
