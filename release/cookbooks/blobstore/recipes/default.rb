include_recipe "env"
include_recipe "nginx"
include_recipe "ruby"
include_recipe "rubygems"
include_recipe "runit"

runit_service "blobstore" do
  run_restart false
end

package "git-core"

if node[:blobstore][:nginx]
  template "#{node[:nginx][:path]}/sites/blobstore.conf" do
    source "nginx.conf.erb"
    owner node[:nginx][:runner]
    group node[:nginx][:runner]
    mode "0644"
    notifies :restart, "service[nginx]"
  end
else
  file "#{node[:nginx][:path]}/sites/blobstore.conf" do
    action :delete
    notifies :restart, "service[nginx]", :immediately
  end
end

directory "#{node[:blobstore][:path]}/shared" do
  owner node[:blobstore][:runner]
  group node[:blobstore][:runner]
  mode "0755"
  recursive true
  action :create
end

directory node[:blobstore][:tmp] do
  mode "1777"
  recursive true
  action :create
end

%w{config gems logs}.each do |dir|
  directory "#{node[:blobstore][:path]}/shared/#{dir}" do
    owner node[:blobstore][:runner]
    group node[:blobstore][:runner]
    mode "0755"
    action :create
  end
end

template "#{node[:blobstore][:path]}/shared/config/simple_blobstore_server.yml" do
  source "simple_blobstore_server.yml.erb"
  owner node[:blobstore][:runner]
  group node[:blobstore][:runner]
  notifies :restart, "service[blobstore]"
end

deploy_revision node[:blobstore][:path] do
  repo "#{node[:blobstore][:repos_path]}/bosh"
  user node[:blobstore][:runner]
  revision "HEAD"
  migrate false
  shallow_clone true
  action :deploy
  restart_command do
    execute "/usr/bin/sv restart blobstore" do
      ignore_failure true
    end
  end
  scm_provider Chef::Provider::Git
  symlink_before_migrate({})
  symlinks({})

  before_migrate do
    execute "#{node[:ruby][:path]}/bin/bundle install --deployment --without development test --local --path #{node[:blobstore][:path]}/shared/gems" do
      ignore_failure true
      cwd "#{release_path}/simple_blobstore_server"
    end
  end
end
