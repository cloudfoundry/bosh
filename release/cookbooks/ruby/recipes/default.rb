include_recipe "env"

%w[ build-essential libssl-dev zlib1g-dev libreadline5-dev libxml2-dev ].each do |pkg|
  package pkg
end

remote_file "/tmp/ruby-#{node[:ruby][:version]}.tar.gz" do
  source "http://ftp.ruby-lang.org/pub/ruby/1.8/ruby-#{node[:ruby][:version]}.tar.gz"
  not_if { ::File.exists?("/tmp/ruby-#{node[:ruby][:version]}.tar.gz") }
end

directory node[:ruby][:path] do
  owner "root"
  group "root"
  mode "0755"
  recursive true
  action :create
end

bash "Install Ruby" do
  cwd "/tmp"
  code <<-EOH
  tar xzf ruby-#{node[:ruby][:version]}.tar.gz
  cd ruby-#{node[:ruby][:version]}
  ./configure --disable-pthread --prefix=#{node[:ruby][:path]}
  make
  make install
  EOH
  not_if do
    ::File.exists?("#{node[:ruby][:path]}/bin/ruby")
  end
end