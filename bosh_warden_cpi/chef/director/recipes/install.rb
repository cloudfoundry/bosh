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
  libsqlite3-dev
  libpq-dev
  dbus
  vim
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

script "install_redis" do
  interpreter "bash"
  user "root"
  creates "/usr/local/bin/redis-server"
  cwd "/usr/local/src/"

  code <<-EOH
  wget http://redis.googlecode.com/files/redis-2.6.12.tar.gz
  tar zxvf redis-2.6.12.tar.gz
  cd redis-2.6.12
  PREFIX=/usr/local make all install
  cp redis.conf /usr/local/etc
  EOH
end

packages.each do |package_name|
  package package_name do
    action :install
  end
end

gem_package "bundler" do
  action :install
  gem_binary "/usr/local/bin/gem"
end

execute "install bosh gems" do
  cwd "/bosh"
  command "bundle install"
  action :run
end

execute "create directory for bosh logs" do
  cwd "/var/log"
  command "mkdir -p bosh"
  action :run
end

execute "copy init scripts" do
  cwd "/"
  command "sudo cp bosh/bosh_warden_cpi/init/* /etc/init/"
end

execute "start bosh!" do
  command "sudo start bosh"
end
