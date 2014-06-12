require 'rspec'
require 'tempfile'
require 'rspec/core/rake_task'
require 'bosh/dev/bat_helper'
require 'common/thread_pool'
require 'parallel_tests/tasks'

namespace :spec do
  namespace :integration do
    desc 'Run BOSH integration tests against a local sandbox with Ruby agent'
    task :ruby_agent do
      run_integration_specs('ruby')
    end

    desc 'Run BOSH integration tests against a local sandbox with Go agent'
    task :go_agent do
      sh('go_agent/bin/build')
      run_integration_specs('go')
    end

    def run_integration_specs(agent_type)
      ENV['BOSH_INTEGRATION_AGENT_TYPE'] = agent_type

      num_processes   = ENV['NUM_PROCESSES']
      num_processes ||= ENV['TRAVIS'] ? 6 : nil

      Rake::Task['parallel:spec'].invoke(num_processes, 'spec/integration')
    end
  end

  task :integration => %w(spec:integration:ruby_agent)

  namespace :unit do
    desc 'Run unit tests for each BOSH component gem in parallel'
    task ruby_gems: %w(rubocop) do
      trap('INT') { exit }

      builds = Dir['*'].select { |f| File.directory?(f) && File.exists?("#{f}/spec") }
      builds -= %w(bat)

      cpi_builds = builds.select { |f| File.directory?(f) && f.end_with?("_cpi") }

      spec_logs = Dir.mktmpdir

      puts "Logging spec results in #{spec_logs}"

      max_threads = ENV.fetch('BOSH_MAX_THREADS', 10).to_i
      Bosh::ThreadPool.new(max_threads: max_threads, logger: Logger.new('/dev/null')).wrap do |pool|
        builds.each do |build|
          pool.process do
            log_file    = "#{spec_logs}/#{build}.log"
            rspec_files = cpi_builds.include?(build) ? "spec/unit/" : "spec/"
            rspec_cmd   = "rspec --tty -c -f p #{rspec_files}"

            # inject command name so coverage results for each component don't clobber others
            if system({'BOSH_BUILD_NAME' => build}, "cd #{build} && #{rspec_cmd} > #{log_file} 2>&1")
              puts "----- BEGIN #{build}"
              puts "           #{rspec_cmd}"
              print File.read(log_file)
              puts "----- END   #{build}\n\n"
            else
              raise("#{build} failed to build unit tests: #{File.read(log_file)}")
            end
          end
        end

        pool.wait
      end
    end

    task(:go_agent) do
      # Do not use exec because this task is part of other tasks
      sh('go_agent/bin/test')
    end
  end

  task :unit => %w(spec:unit:ruby_gems spec:unit:go_agent)

  namespace :external do
    desc 'AWS bootstrap CLI can provision and destroy resources'
    RSpec::Core::RakeTask.new(:aws_bootstrap) do |t|
      t.pattern = 'spec/external/aws_bootstrap_spec.rb'
      t.rspec_opts = %w(--format documentation --color)
    end
  end

  namespace :system do
    desc 'Run system (BATs) tests (deploys microbosh)'
    task :micro, [:infrastructure_name, :operating_system_name, :operating_system_version, :net_type, :agent_name] do |_, args|
      Bosh::Dev::BatHelper.for_rake_args(args).deploy_microbosh_and_run_bats
    end

    desc 'Run system (BATs) tests (uses existing microbosh)'
    task :existing_micro, [:infrastructure_name, :operating_system_name, :operating_system_version, :net_type, :agent_name] do |_, args|
      Bosh::Dev::BatHelper.for_rake_args(args).run_bats
    end
  end
end

desc 'Run unit and integration specs'
task :spec => %w(spec:unit spec:integration)

desc 'Run unit and integration specs for Go related code'
task :gospec => %w(spec:unit spec:integration:go_agent)
