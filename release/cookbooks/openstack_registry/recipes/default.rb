include_recipe "env"
include_recipe "ruby"
include_recipe "rubygems"
include_recipe "runit"

runit_service "openstack_registry" do
  run_restart false
end

package "git-core"

directory "#{node[:openstack_registry][:path]}/shared" do
  owner node[:openstack_registry][:runner]
  group node[:openstack_registry][:runner]
  mode "0755"
  recursive true
  action :create
end

directory node[:openstack_registry][:tmp] do
  mode "1777"
  recursive true
  action :create
end

%w{config gems logs}.each do |dir|
  directory "#{node[:openstack_registry][:path]}/shared/#{dir}" do
    owner node[:openstack_registry][:runner]
    group node[:openstack_registry][:runner]
    mode "0755"
    action :create
  end
end

template "#{node[:openstack_registry][:path]}/shared/config/openstack_registry.yml" do
  source "openstack_registry.yml.erb"
  owner node[:openstack_registry][:runner]
  group node[:openstack_registry][:runner]
  notifies :restart, "service[openstack_registry]"
end

deploy_revision node[:openstack_registry][:path] do
  scm_provider Chef::Provider::Git

  repo "#{node[:openstack_registry][:repos_path]}/bosh"
  user node[:openstack_registry][:runner]
  revision "HEAD"

  migrate true

  migration_command "cd openstack_registry && PATH=#{node[:ruby][:path]}/bin:$PATH " \
                    "./bin/migrate -c #{node[:openstack_registry][:path]}/shared/config/openstack_registry.yml"

  symlink_before_migrate({})
  symlinks({})

  shallow_clone true
  action :deploy

  restart_command do
    execute "/usr/bin/sv restart openstack_registry" do
      ignore_failure true
    end
  end

  before_migrate do
    execute "#{node[:ruby][:path]}/bin/bundle install " \
            "--deployment --without development test " \
            "--local --path #{node[:openstack_registry][:path]}/shared/gems" do
      ignore_failure true
      cwd "#{release_path}/openstack_registry"
    end
  end
end
