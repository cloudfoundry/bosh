require 'rspec'
require 'rspec/core/rake_task'

rspec_opts = %w(--format documentation --color)
rspec_opts << '--fail-fast' if (ENV['BAT_FAIL_FAST'] || 'false').downcase == 'true'

rspec_opts << "--format Bosh::Dev::DataDogFormatter --require bosh/dev/data_dog_formatter" if ENV.key?('BAT_DATADOG_API_KEY')

desc 'Run BAT tests'
RSpec::Core::RakeTask.new(:bat) do |t|
  require 'fileutils'
  puts "Curent directory is #{FileUtils.pwd}"

  t.pattern = %W[bat/spec/env_spec.rb bat/spec/bat/*_spec.rb]
  t.rspec_opts = rspec_opts
end

namespace :bat do
  desc 'Verify BAT environment'
  RSpec::Core::RakeTask.new(:env) do |t|
    require 'fileutils'
    puts "Curent directory is #{FileUtils.pwd}"

    t.pattern = %W[spec/env_spec.rb]
    t.rspec_opts = rspec_opts
  end
end
