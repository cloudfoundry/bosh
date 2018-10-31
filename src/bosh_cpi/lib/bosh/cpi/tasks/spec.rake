require 'rspec'
require 'rspec/core/rake_task'

namespace :spec do
  desc 'Run VM lifecycle specs'
  RSpec::Core::RakeTask.new(:lifecycle) do |t|
    t.pattern = 'spec/integration'
    t.rspec_opts = %w(--format documentation --color)
  end
end
