# HACK to set up the proxies
["http_proxy", "https_proxy", "no_proxy"].each do |env|
  next unless Chef::Config[env]
  unless ENV[env] || ENV[env.upcase]
    ENV[env] = ENV[env.upcase] = Chef::Config[env]
  end
end
