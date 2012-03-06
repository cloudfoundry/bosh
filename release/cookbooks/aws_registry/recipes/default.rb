include_recipe "env"
include_recipe "ruby"
include_recipe "rubygems"
include_recipe "runit"

runit_service "aws_registry" do
  run_restart false
end

package "git-core"

directory "#{node[:aws_registry][:path]}/shared" do
  owner node[:aws_registry][:runner]
  group node[:aws_registry][:runner]
  mode "0755"
  recursive true
  action :create
end

directory node[:aws_registry][:tmp] do
  mode "1777"
  recursive true
  action :create
end

%w{config gems logs}.each do |dir|
  directory "#{node[:aws_registry][:path]}/shared/#{dir}" do
    owner node[:aws_registry][:runner]
    group node[:aws_registry][:runner]
    mode "0755"
    action :create
  end
end

template "#{node[:aws_registry][:path]}/shared/config/aws_registry.yml" do
  source "aws_registry.yml.erb"
  owner node[:aws_registry][:runner]
  group node[:aws_registry][:runner]
  notifies :restart, "service[aws_registry]"
end

deploy_revision node[:aws_registry][:path] do
  scm_provider Chef::Provider::Git

  repo "#{node[:aws_registry][:repos_path]}/bosh"
  user node[:aws_registry][:runner]
  revision "HEAD"

  migrate true

  migration_command "cd aws_registry && PATH=#{node[:ruby][:path]}/bin:$PATH " \
                    "./bin/migrate -c #{node[:aws_registry][:path]}/shared/config/aws_registry.yml"

  symlink_before_migrate({})
  symlinks({})

  shallow_clone true
  action :deploy

  restart_command do
    execute "/usr/bin/sv restart aws_registry" do
      ignore_failure true
    end
  end

  before_migrate do
    execute "#{node[:ruby][:path]}/bin/bundle install " \
            "--deployment --without development test " \
            "--local --path #{node[:aws_registry][:path]}/shared/gems" do
      ignore_failure true
      cwd "#{release_path}/aws_registry"
    end
  end
end
