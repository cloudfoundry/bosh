#!/usr/bin/env ruby

builds = Dir['*'].select {|f| File.directory?(f) && File.exists?("#{f}/spec")}
builds -= ['bat', 'director', 'ruby_vcloud_sdk', 'vsphere_cpi', 'vcloud_cpi']

redis_pid = fork { exec("redis-server  --port 63790") }
at_exit { Process.kill("KILL", redis_pid) }

builds.each do |build|
  p "-----#{build}-----"
  system("cd #{build} && (bundle check || bundle) && bundle exec rspec spec") || raise(build)
end