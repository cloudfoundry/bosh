V_RUBY = "1.9.3-p327"

packages = %w[
  debootstrap
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

script "install_ruby" do
  interpreter "bash"
  user "root"
  creates "/usr/local/bin/ruby"
  cwd "/usr/local/src/"

  code <<-EOH
  # First need to install libyaml
  wget http://pyyaml.org/download/libyaml/yaml-0.1.4.tar.gz
  tar zxvf yaml-0.1.4.tar.gz
  cd yaml-0.1.4
  ./configure --prefix=/usr/local
  make
  make install

  # Install ruby
  wget ftp://ftp.ruby-lang.org/pub/ruby/1.9/ruby-#{V_RUBY}.tar.gz
  tar zxvf ruby-#{V_RUBY}.tar.gz
  cd ruby-#{V_RUBY}
  ./configure --prefix=/usr/local --enable-shared --disable-install-doc --with-opt-dir=/usr/local/lib
  make
  make install
  EOH
end

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
