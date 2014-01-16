require 'rspec'
require 'tempfile'
require 'rspec/core/rake_task'
require 'bosh/dev/bat_helper'

namespace :spec do
  desc 'Run BOSH integration tests against a local sandbox'
  task :integration do
    require 'parallel_tests/tasks'
    Rake::Task['parallel:spec'].invoke(ENV['TRAVIS'] ? 6 : nil, 'spec/integration/.*_spec.rb')
  end

  desc 'Run unit and functional tests for each BOSH component gem'
  task :parallel_unit do
    require 'common/thread_pool'
    trap('INT') { exit }

    builds = Dir['*'].select { |f| File.directory?(f) && File.exists?("#{f}/spec") }
    builds -= ['bat']

    cpi_builds = Dir['*'].select { |f| File.directory?(f) && f.end_with?("_cpi") }

    spec_logs = Dir.mktmpdir

    puts "Logging spec results in #{spec_logs}"

    Bosh::ThreadPool.new(max_threads: 10, logger: Logger.new('/dev/null')).wrap do |pool|
      builds.each do |build|
        puts "-----Building #{build}-----"

        pool.process do
          log_file    = "#{spec_logs}/#{build}.log"
          rspec_files = cpi_builds.include?(build) ? "spec/unit/" : "spec/"
          rspec_cmd   = "cd #{build} && rspec --tty -c -f p #{rspec_files} > #{log_file} 2>&1"

          if system(rspec_cmd)
            print File.read(log_file)
          else
            raise("#{build} failed to build unit tests: #{File.read(log_file)}")
          end
        end
      end

      pool.wait
    end
  end

  desc 'Run unit and functional tests linearly'
  task unit: %w(rubocop) do
    builds = Dir['*'].select { |f| File.directory?(f) && File.exists?("#{f}/spec") }
    builds -= ['bat']

    cpi_builds = Dir['*'].select { |f| File.directory?(f) && f.end_with?("_cpi") }

    builds.each do |build|
      puts "-----Building #{build}-----"
      rspec_files = cpi_builds.include?(build) ? "spec/unit/" : "spec/"
      rspec_cmd   = "cd #{build} && rspec #{rspec_files}"
      raise("#{build} failed to build unit tests") unless system(rspec_cmd)
    end
  end

  desc 'Run integration and unit tests in parallel'
  task :parallel_all do
    unit        = Thread.new { Rake::Task['spec:parallel_unit'].invoke }
    integration = Thread.new { Rake::Task['spec:integration'].invoke }
    [unit, integration].each(&:join)
  end

  namespace :external do
    desc 'AWS bootstrap CLI can provision and destroy resources'
    RSpec::Core::RakeTask.new(:aws_bootstrap) do |t|
      t.pattern = 'spec/external/aws_bootstrap_spec.rb'
      t.rspec_opts = %w(--format documentation --color)
    end
  end

  namespace :system do
    desc 'Run system (BATs) tests (deploys microbosh)'
    task :micro, [:infrastructure_name, :operating_system_name, :net_type, :agent_name] do |_, args|
      Bosh::Dev::BatHelper.for_rake_args(args).deploy_microbosh_and_run_bats
    end

    desc 'Run system (BATs) tests (uses existing microbosh)'
    task :existing_micro, [:infrastructure_name, :operating_system_name, :net_type, :agent_name] do |_, args|
      Bosh::Dev::BatHelper.for_rake_args(args).run_bats
    end
  end
end

desc 'Run unit and integration specs'
task :spec => ['spec:parallel_unit', 'spec:integration']
