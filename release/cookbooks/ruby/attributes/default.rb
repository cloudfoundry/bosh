default[:ruby][:version] = "1.8.7-p302"
default[:ruby][:source]  = "http://ftp.ruby-lang.org//pub/ruby/1.8/ruby-#{ruby[:version]}.tar.gz"
default[:ruby][:path]    = "/var/vcap/deploy/rubies/ruby-#{ruby[:version]}"
