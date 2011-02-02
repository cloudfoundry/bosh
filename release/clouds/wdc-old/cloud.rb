default_run_options[:pty] = true

set :http_proxy,  "http://wdc-proxy01.cso.vmware.com:3128"
set :ftp_proxy,   "http://wdc-proxy01.cso.vmware.com:3128"
set :no_proxy,    ".cso.vmware.com,localhost,127.0.0.0/8,10.0.0.0/8"
set :sudo,        "/usr/bin/sudo -i"

set :user,        "vmc"
set :runner,      "vmc"
set :workers,     2

role :director,   "10.255.21.211"
role :workers,    "10.255.21.211"
role :redis,      "10.255.24.10"
role :blobstore,  "10.255.24.10"