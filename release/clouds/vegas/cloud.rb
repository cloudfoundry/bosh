default_run_options[:pty] = true

set :gateway_user, ENV['GATEWAY_USER'] || Capistrano::CLI.ui.ask("What's your SSH gateway username?")
set :gateway,     "#{gateway_user}@172.28.1.6"

set :http_proxy,  "http://squid01.las01.emcatmos.com:3128"
set :ftp_proxy,   "http://squid01.las01.emcatmos.com:3128"
set :no_proxy,    ".emcatmos.com,localhost,127.0.0.0/8,172.16.0.0/16"
set :sudo,        "/usr/bin/sudo -i"

set :user,        "vmc"
set :runner,      "vmc"
set :workers,     2

role :director,   "172.30.252.113"
role :workers,    "172.30.252.113"
role :redis,      "172.30.40.12"
role :blobstore,  "172.30.40.12"