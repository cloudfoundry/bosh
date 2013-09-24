require 'rspec'
require 'rspec/core/rake_task'

rspec_opts = %w(--format documentation --color)
rspec_opts << '--fail-fast' if (ENV['BAT_FAIL_FAST'] || 'false').downcase == 'true'

rspec_opts.concat(%w(--format Bosh::Dev::DataDogFormatter --require bosh/dev/data_dog_formatter)) if ENV.key?('BAT_DATADOG_API_KEY')


task :bat do
  Dir.chdir('bat') do
    sh('rspec', *rspec_opts)
  end
end

namespace :bat do
  task :env do
    Dir.chdir('bat') do
      sh('rspec', 'spec/system/env_spec.rb', *rspec_opts)
    end
  end
end
