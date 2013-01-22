#!/usr/bin/env ruby

def bundle_without
  ENV['HAS_JOSH_K_SEAL_OF_APPROVAL'] ? "--without development" : ""
end

def run_bundler_in(dir)
  system("cd #{dir} && (bundle check || bundle install #{bundle_without})") || raise("Bundle Failed")
end

if ENV['SUITE'] == "integration"
  %w{spec cli director health_monitor simple_blobstore_server agent}.each do |dir|
    run_bundler_in(dir)
  end

  exec("cd spec && bundle exec rake spec")
else
  builds = Dir['*'].select {|f| File.directory?(f) && File.exists?("#{f}/spec")}
  builds.delete('bat')
  builds.delete('aws_bootstrap')

  redis_pid = fork { exec("redis-server  --port 63790") }
  at_exit { Process.kill("KILL", redis_pid) }

  builds.each do |build|
    p "-----#{build}-----"
    run_bundler_in(build)
    system("cd #{build} && bundle exec rspec spec") || raise("FAILED -- #{build}")
  end
end