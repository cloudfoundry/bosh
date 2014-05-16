require 'rspec'
require 'rspec/core/rake_task'

namespace :spec do
  namespace :lifecycle do
    desc 'Run VM lifecycle specs'
    RSpec::Core::RakeTask.new(:internal_cpi) do |t|
      t.pattern = 'spec/integration'
      t.rspec_opts = %w(--format documentation --color --tag ~external_cpi)
    end

    RSpec::Core::RakeTask.new(:external_cpi) do |t|
      t.pattern = 'spec/integration'
      t.rspec_opts = %w(--format documentation --color --tag external_cpi)
    end
  end

  # for temporary backwards compatibility, create a task called
  # lifecycle which uses the internal CPI
  task :lifecycle => ['lifecycle:internal_cpi']
end
