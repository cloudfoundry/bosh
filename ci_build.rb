#!/usr/bin/env ruby

def bundle_without
  ENV['HAS_JOSH_K_SEAL_OF_APPROVAL'] ? "--without development" : "" # aka: on travis
end

def run_build(build)
  p "-----#{build}-----"
  system("cd #{build} && bundle exec rspec spec") || raise(build)
end

system("bundle check || bundle #{bundle_without}")

if ENV['SUITE'] == "integration"
  run_build('integration_tests')
else
  builds = Dir['*'].select {|f| File.directory?(f) && File.exists?("#{f}/spec")}
  builds -= ['bat']
  builds -= ['integration_tests'] if ENV['SUITE'] == "unit"

  redis_pid = fork { exec("redis-server  --port 63790") }
  at_exit { Process.kill("KILL", redis_pid) }

  builds.each do |build|
    run_build(build)
  end
end
