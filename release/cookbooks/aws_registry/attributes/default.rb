default[:aws_registry][:path]                = "/var/vcap/deploy/bosh/aws_registry"
default[:aws_registry][:tmp]                 = "/var/vcap/deploy/tmp"
default[:aws_registry][:repos_path]          = "/var/vcap/deploy/repos"
default[:aws_registry][:runner]              = "vcap"
default[:aws_registry][:loglevel]            = "info"

default[:aws_registry][:http][:port] = 25777
default[:aws_registry][:http][:user] = "admin"
default[:aws_registry][:http][:password] = "admin"

