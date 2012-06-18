default[:health_monitor][:path]                = "/var/vcap/deploy/bosh/health_monitor"
default[:health_monitor][:tmp]                 = "/var/vcap/deploy/tmp"
default[:health_monitor][:repos_path]          = "/var/vcap/deploy/repos"
default[:health_monitor][:runner]              = "vcap"
default[:health_monitor][:loglevel]            = "info"

default[:health_monitor][:email_notifications] = false
default[:health_monitor][:email_recipients]    = [ ]
default[:health_monitor][:smtp][:from]         = nil
default[:health_monitor][:smtp][:host]         = nil
default[:health_monitor][:smtp][:port]         = nil
default[:health_monitor][:smtp][:tls]          = nil
default[:health_monitor][:smtp][:auth]         = nil
default[:health_monitor][:smtp][:user]         = nil
default[:health_monitor][:smtp][:password]     = nil
default[:health_monitor][:smtp][:domain]       = nil

default[:health_monitor][:http][:port] = 25923
default[:health_monitor][:http][:user] = "admin"
default[:health_monitor][:http][:password] = "admin"

default[:health_monitor][:director_account][:user]     = "admin"
default[:health_monitor][:director_account][:password] = "admin"

default[:health_monitor][:intervals][:poll_director] = 60
default[:health_monitor][:intervals][:poll_grace_period] = 30
default[:health_monitor][:intervals][:log_stats] = 300
default[:health_monitor][:intervals][:analyze_agents] = 60
default[:health_monitor][:intervals][:agent_timeout] = 180
default[:health_monitor][:intervals][:rogue_agent_alert] = 180
