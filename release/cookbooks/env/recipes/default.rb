# HACK to set up the proxies
["http_proxy", "https_proxy", "no_proxy"].each do |env|
  next unless Chef::Config[env]
  unless ENV[env] || ENV[env.upcase]
    ENV[env] = ENV[env.upcase] = Chef::Config[env]
  end
end

if node[:env][:sysctl]
  template "/etc/sysctl.d/90-bosh.conf" do
    source "90-bosh.conf.erb"
    notifies :restart, "service[procps]"
  end
end