default_run_options[:pty] = true

#set :gateway_user, ENV['GATEWAY_USER'] || Capistrano::CLI.ui.ask("What's your SSH gateway username?")
#set :gateway,     "#{gateway_user}@172.28.1.6"

set :http_proxy,  "http://proxy.vmware.com:3128"
set :ftp_proxy,   "http://proxy.vmware.com:3128"
set :no_proxy,    ".eng.vmware.com,localhost,127.0.0.0/8,192.168.0.0/16,10.138.0.0/16"
set :sudo,        "/usr/bin/sudo -i"

set :user,        "root"
set :runner,      "root"
set :workers,     1

role :director,   "10.138.68.2"
role :workers,    "10.138.68.2"
