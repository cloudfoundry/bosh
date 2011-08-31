ntp_cmd = "/var/vcap/bosh/bin/ntp.sh"

template ntp_cmd do
  source "ntp.sh.erb"
  owner "root"
  group "root"
  mode 0755
  variables(
      :server => Chef::Config["ntp_server"] ? Chef::Config["ntp_server"] : node[:ntp][:server]
  )
end

cron "ntp_via_cron" do
  minute "0"
  command ntp_cmd
end
