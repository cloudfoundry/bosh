include_recipe "env"
include_recipe "ruby"
include_recipe "rubygems"
include_recipe "runit"

runit_service "director" do
  run_restart false
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
  mode "0777"
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
  local true
  variables(
      :process_name => "director"
  )
end

template "#{node[:director][:path]}/shared/config/drain-workers.yml" do
  source "#{node[:assets]}/director.yml.erb"
  local true
  variables(
      :process_name => "drain-workers"
  )
end

node[:director][:workers].times do |index|
  template "#{node[:director][:path]}/shared/config/director-worker-#{index}.yml" do
    source "#{node[:assets]}/director.yml.erb"
    local true
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
  # HACK: create a rake task instead
  migration_command "cd director && bundle exec sequel -m db/migrations `ruby -r \"yaml\" -e \"puts YAML.load_file('#{node[:director][:path]}/shared/config/director.yml')['db']\"`"
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
    execute "#{node[:ruby][:path]}/bin/bundle install --deployment --without development,test --local --path #{node[:director][:path]}/shared/gems" do
      ignore_failure true
      cwd "#{release_path}/director"
    end

    node[:director][:workers].times do |index|
      execute "/usr/bin/sv 2 director-worker-#{index}" do
        ignore_failure true
      end
    end

    log "draining workers"

    execute "bin/drain_workers -c #{node[:director][:path]}/shared/config/drain-workers.yml" do
      ignore_failure true
      cwd "#{release_path}/director"
    end
  end
end
