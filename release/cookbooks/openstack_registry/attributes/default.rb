default[:openstack_registry][:path]                = "/var/vcap/deploy/bosh/openstack_registry"
default[:openstack_registry][:tmp]                 = "/var/vcap/deploy/tmp"
default[:openstack_registry][:repos_path]          = "/var/vcap/deploy/repos"
default[:openstack_registry][:runner]              = "vcap"
default[:openstack_registry][:loglevel]            = "info"

default[:openstack_registry][:http][:port] = 25778
default[:openstack_registry][:http][:user] = "admin"
default[:openstack_registry][:http][:password] = "admin"