packages = %w[
  debootstrap
  ruby1.9.3
  build-essential
  quota
  libcurl4-gnutls-dev
  libxml2-dev
  libxslt-dev
  zip
  unzip
  curl
  wget
  runit
  sqlite3
  redis-server
  libsqlite3-dev
  postgresql-9.1
  libpq-dev
]

packages.each do |package_name|
  package package_name do
    action :install
  end
end

gem_package "bundler" do
  action :install
  gem_binary "/usr/bin/gem"
end

execute "install bosh gems" do
  cwd "/bosh"
  command "bundle install"
  action :run
end

service "redis" do
  action :start
end

#execute "migrate database" do
#  cwd "/bosh/director"
#  command "bundle exec bin/migrate -c /vagrant/config/warden.yml"
#end
#
#execute "start director" do
#  cwd "/bosh/director"
#  command "bundle exec bin/director -c /vagrant/config/warden.yml"
#end

#execute "help" do
#  echo "the ipaddress is asldfj"
#end
