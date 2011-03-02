log_level         :debug
cookbook_path     "/var/vcap/deploy/cookbooks"
file_cache_path   "/tmp/chef-solo"
http_proxy        "http://wdc-proxy01.cso.vmware.com:3128"
https_proxy       "http://wdc-proxy01.cso.vmware.com:3128"
no_proxy          "eng.vmware.com,localhost,127.0.0.0/8,10.0.0.0/8"
