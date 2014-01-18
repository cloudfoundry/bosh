require 'rspec'
require 'rspec/core/rake_task'

task :bat do
  Dir.chdir('bat') { exec('rspec') }
end

namespace :bat do
  task :env do
    Dir.chdir('bat') { exec('rspec', 'spec/system/env_spec.rb') }
  end
end
