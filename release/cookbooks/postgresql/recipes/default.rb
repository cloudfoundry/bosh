include_recipe "env"

execute "apt-get update" do
  action :nothing
end

cookbook_file "/etc/apt/sources.list.d/01-postgres.list" do
  source "01-postgres.list"
  notifies :run, "execute[apt-get update]", :immediately
end

package "postgresql-9.0" do
  options "--force-yes" # since it's not authenticated
end

template "/etc/logrotate.d/postgresql-common" do
  source "postgresql-common.erb"
  owner "root"
  group "root"
  mode 0644
end

directory node[:postgresql][:data_directory] do
  owner "postgres"
  group "postgres"
  mode 0700
  recursive true
  action :create
  notifies :stop, "service[postgresql]", :immediately
end

bash "init data directory" do
  code "sudo -u postgres /usr/lib/postgresql/9.0/bin/initdb -D #{node[:postgresql][:data_directory]}"
  timeout 5
  not_if { ::File.exists?("#{node[:postgresql][:data_directory]}/PG_VERSION") }
end

template "/etc/postgresql/9.0/main/pg_hba.conf" do
  source "pg_hba.conf.erb"
  owner "postgres"
  group "postgres"
  mode 0600
  notifies :reload, "service[postgresql]"
end

template "/etc/postgresql/9.0/main/postgresql.conf" do
  source "postgresql.conf.erb"
  owner "postgres"
  group "postgres"
  mode 0600
  notifies :restart, "service[postgresql]"
end

service "postgresql" do
  supports :restart => true, :status => false, :reload => true
  action :start
end

bash "create database" do
  code "sudo -u postgres createdb #{node[:postgresql][:database]}"
  timeout 5
  not_if { %x[sudo -u postgres psql -c "SELECT datname FROM pg_database WHERE datname='#{node[:postgresql][:database]}'"].include?("1 row") }
end

bash "create user" do
  code "sudo -u postgres createuser -s #{node[:postgresql][:user]}"
  timeout 5
  not_if { %x[sudo -u postgres psql -c "SELECT usename FROM pg_user WHERE usename = '#{node[:postgresql][:user]}'"].include?("1 row") }
end

bash "set database user password" do
  code "sudo -u postgres psql -c 'alter role #{node[:postgresql][:user]} password '\\''#{node[:postgresql][:password]}'\\'"
  timeout 5
end
