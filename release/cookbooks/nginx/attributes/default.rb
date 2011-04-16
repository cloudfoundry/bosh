default[:nginx][:version]    = "1.0.0"
default[:nginx][:path]       = "/var/vcap/deploy/nginx/nginx-#{nginx[:version]}"
default[:nginx][:runner]     = "vcap"
default[:nginx][:worker_processes] = 2
default[:nginx][:worker_connections] = 8192
