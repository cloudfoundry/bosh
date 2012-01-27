include_recipe "env"
include_recipe "ruby"
include_recipe "rubygems"
include_recipe "runit"

execute "apt-get update" do
  action :nothing
end

cookbook_file "/etc/apt/sources.list.d/01-postgres.list" do
  source "01-postgres.list"
  notifies :run, "execute[apt-get update]", :immediately
end

["postgresql-client-9.0", "libpq-dev"].each do |name|
  package name do
    options "--force-yes" # since it's not authenticated
  end
end

package "genisoimage"

runit_service "director" do
  run_restart false
end

template "/etc/logrotate.d/bosh-director" do
  source "director-logrotate.erb"
  owner "root"
  group "root"
  mode 0644
end

node[:director][:workers].times do |index|
  runit_service "director-worker-#{index}" do
    template_name "director-worker"
    options(:index => index)
    run_restart false
  end
end

package "git-core"

directory "#{node[:director][:path]}/shared" do
  owner node[:director][:runner]
  group node[:director][:runner]
  mode "0755"
  recursive true
  action :create
end

directory node[:director][:tmp] do
  owner node[:director][:runner]
  group node[:director][:runner]
  mode "1777"
  recursive true
  action :create
end

%w{config gems system logs}.each do |dir|
  directory "#{node[:director][:path]}/shared/#{dir}" do
    owner node[:director][:runner]
    group node[:director][:runner]
    mode "0755"
    action :create
  end
end

template "#{node[:director][:path]}/shared/config/director.yml" do
  source "#{node[:assets]}/director.yml.erb"
  owner node[:director][:runner]
  group node[:director][:runner]
  local true
  variables(
      :process_name => "director"
  )
end

template "#{node[:director][:path]}/shared/config/drain-workers.yml" do
  source "#{node[:assets]}/director.yml.erb"
  local true
  owner node[:director][:runner]
  group node[:director][:runner]
  variables(
      :process_name => "drain-workers"
  )
end

node[:director][:workers].times do |index|
  template "#{node[:director][:path]}/shared/config/director-worker-#{index}.yml" do
    source "#{node[:assets]}/director.yml.erb"
    local true
    owner node[:director][:runner]
    group node[:director][:runner]
    variables(
      :process_name => "director-worker-#{index}"
    )
  end
end

deploy_revision node[:director][:path] do
  repo "#{node[:director][:repos_path]}/bosh"
  user node[:director][:runner]
  revision "HEAD"
  migrate true
  migration_command "cd director && PATH=#{node[:ruby][:path]}/bin:$PATH #{node[:ruby][:path]}/bin/bundle exec rake migration:run[#{node[:director][:path]}/shared/config/director.yml]"
  shallow_clone true
  action :force_deploy
  restart_command do
    execute "/usr/bin/sv restart director" do
      ignore_failure true
    end

    node[:director][:workers].times do |index|
      execute "/usr/bin/sv restart director-worker-#{index}" do
        ignore_failure true
      end
    end
  end
  scm_provider Chef::Provider::Git
  symlink_before_migrate({})
  symlinks({})

  before_migrate do
    execute "#{node[:ruby][:path]}/bin/bundle install --deployment --without development test --local --path #{node[:director][:path]}/shared/gems" do
      cwd "#{release_path}/director"
    end

    node[:director][:workers].times do |index|
      execute "/usr/bin/sv 2 director-worker-#{index}" do
        ignore_failure true
      end
    end

    log "draining workers"

    execute "PATH=#{node[:ruby][:path]}/bin:$PATH bin/drain_workers -c #{node[:director][:path]}/shared/config/drain-workers.yml" do
      cwd "#{release_path}/director"
    end
  end
end
