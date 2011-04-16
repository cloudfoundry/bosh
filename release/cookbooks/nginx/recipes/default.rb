include_recipe "env"
include_recipe "runit"

package "libpcre3"
package "libpcre3-dev"
package "libssl-dev"

remote_file "/tmp/nginx-#{node[:nginx][:version]}.tar.gz" do
  source "http://nginx.org/download/nginx-#{node[:nginx][:version]}.tar.gz"
  not_if { ::File.exists?("/tmp/nginx-#{node[:nginx][:version]}.tar.gz") }
end

%w[logs run sites].each do |dir|
  directory "#{node[:nginx][:path]}/#{dir}" do
    owner node[:nginx][:runner]
    group node[:nginx][:runner]
    mode "0755"
    recursive true
    action :create
  end
end

bash "Install Nginx" do
  cwd "/tmp"
  code <<-EOH
  tar xzf nginx-#{node[:nginx][:version]}.tar.gz
  cd nginx-#{node[:nginx][:version]}
  ./configure --prefix=#{node[:nginx][:path]}
  make
  make install
  EOH
  not_if do
    ::File.exists?("#{node[:nginx][:path]}/sbin/nginx")
  end
end

runit_service "nginx"

template "nginx.conf" do
  path "#{node[:nginx][:path]}/conf/nginx.conf"
  source "nginx.conf.erb"
  owner node[:nginx][:runner]
  group node[:nginx][:runner]
  mode "0644"
  notifies :restart, "service[nginx]", :immediately
end
