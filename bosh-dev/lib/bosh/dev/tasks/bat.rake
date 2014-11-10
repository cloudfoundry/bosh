require 'rspec'
require 'rspec/core/rake_task'

task :bat do
  bat_test = ENV.fetch('BAT_TEST', 'spec')
  Dir.chdir('bat') { exec('rspec', bat_test) }
end

namespace :bat do
  task :env do
    Dir.chdir('bat') { exec('rspec', 'spec/system/env_spec.rb') }
  end
end
