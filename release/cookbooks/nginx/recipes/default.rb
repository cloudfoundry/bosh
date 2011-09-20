include_recipe "env"
include_recipe "runit"

package "libpcre3"
package "libpcre3-dev"
package "libssl-dev"

remote_file File.join("/tmp", "nginx-#{node[:nginx][:version]}.tar.gz") do
  source "http://nginx.org/download/nginx-#{node[:nginx][:version]}.tar.gz"
  not_if { ::File.exists?(File.join("/tmp", "nginx-#{node[:nginx][:version]}.tar.gz")) }
end

remote_file File.join("/tmp", "nginx_upload_module-#{node[:nginx][:upload_module_version]}.tar.gz") do
  source "http://www.grid.net.ru/nginx/download/nginx_upload_module-#{node[:nginx][:upload_module_version]}.tar.gz"
  not_if { ::File.exists?(File.join("/tmp", "nginx_upload_module-#{node[:nginx][:upload_module_version]}.tar.gz")) }
end

%w[logs run sites upload].each do |dir|
  directory File.join(node[:nginx][:path], dir) do
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
  tar xzf nginx_upload_module-#{node[:nginx][:upload_module_version]}.tar.gz
  tar xzf nginx-#{node[:nginx][:version]}.tar.gz
  cd nginx-#{node[:nginx][:version]}
  ./configure --prefix=#{node[:nginx][:path]} --add-module=#{File.join("/tmp", "nginx_upload_module-" + node[:nginx][:upload_module_version])}
  make
  make install
  EOH
  not_if "#{File.join(node[:nginx][:path], "sbin/nginx")} -V 2>&1 | grep nginx_upload_module"
end

runit_service "nginx"

template "nginx.conf" do
  path File.join(node[:nginx][:path], "conf/nginx.conf")
  source "nginx.conf.erb"
  owner node[:nginx][:runner]
  group node[:nginx][:runner]
  mode "0644"
  notifies :restart, "service[nginx]", :immediately
end
