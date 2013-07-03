require 'rspec'
require 'rspec/core/rake_task'

rspec_opts = %w(--format documentation --color)
rspec_opts << '--fail-fast' if (ENV['BAT_FAIL_FAST'] || 'false').downcase == 'true'

data_dog_formatter_path = File.expand_path('../../helpers/data_dog_formatter.rb', __FILE__)
rspec_opts << "--format Bosh::Helpers::DataDogFormatter --require #{data_dog_formatter_path}" if ENV.key?('BAT_DATADOG_API_KEY')

desc 'Run BAT tests'
RSpec::Core::RakeTask.new(:bat) do |t|
  cd 'bat'
  t.pattern = %w[spec/env_spec.rb spec/bat/*_spec.rb]
  t.rspec_opts = rspec_opts
end

namespace :bat do
  desc 'Verify BAT environment'
  RSpec::Core::RakeTask.new(:env) do |t|
    cd 'bat'
    t.pattern = 'spec/env_spec.rb'
    t.rspec_opts = rspec_opts
  end
end
