default[:ruby][:version] = "1.9.2-p180"
default[:ruby][:source]  = "http://ftp.ruby-lang.org//pub/ruby/1.9/ruby-#{ruby[:version]}.tar.gz"
default[:ruby][:path]    = "/var/vcap/deploy/rubies/ruby-#{ruby[:version]}"
