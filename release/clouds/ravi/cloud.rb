default_run_options[:pty] = true

set :http_proxy,  "http://proxy.eng.vmware.com:3128"
set :ftp_proxy,   "http://proxy.eng.vmware.com:3128"
set :no_proxy,    ".eng.vmware.com,localhost,127.0.0.0/8,10.0.0.0/8"
set :sudo,        "/usr/bin/sudo -i"

set :user,        "vmc"
set :runner,      "vmc"
set :workers,     2

role :director,   "10.135.200.11"
role :workers,    "10.135.200.11"
role :redis,      "10.135.200.10"
role :blobstore,  "10.135.200.10"