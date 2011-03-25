log_level         :debug
cookbook_path     "/var/vcap/deploy/cookbooks"
file_cache_path   "/tmp/chef-solo"
http_proxy        "http://172.30.22.100:3128"
https_proxy       "http://172.30.22.100:3128"
no_proxy          ".emcatmos.com,localhost,127.0.0.0/8,172.16.0.0/16"
