default[:redis][:version] = "2.2.1"
default[:redis][:path] = "/var/vcap/deploy/redis/redis-#{redis[:version]}"
default[:redis][:runner] = "vcap"
default[:redis][:port] = 25255
default[:redis][:password] = "R3d!S"
