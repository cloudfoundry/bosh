require 'rspec'
require 'tempfile'
require 'rspec/core/rake_task'
require 'bosh/dev/bat_helper'
require 'bosh/dev/sandbox/nginx'
require 'bosh/dev/sandbox/workspace'
require 'common/thread_pool'
require 'bosh/dev/sandbox/services/uaa_service'
require 'parallel_tests/tasks'

namespace :spec do
  namespace :integration do
    desc 'Run BOSH integration tests against a local sandbox'
    task :agent => :install_dependencies do
      sh('go/src/github.com/cloudfoundry/bosh-agent/bin/build')
      run_integration_specs
    end

    desc 'Install BOSH integration test dependencies (currently Nginx)'
    task :install_dependencies do
      unless ENV['SKIP_DEPS'] == 'true'
        unless ENV['SKIP_NGINX'] == 'true'
          nginx = Bosh::Dev::Sandbox::Nginx.new
          retries = 3
          begin
            nginx.install
          rescue
            retries -= 1
            retry if retries > 0
            raise
          end
        end

        unless ENV['SKIP_UAA'] == 'true'
          Bosh::Dev::Sandbox::UaaService.install
        end
      end
    end

    def run_integration_specs
      Bosh::Dev::Sandbox::Workspace.clean

      num_processes   = ENV['NUM_GROUPS']
      num_processes ||= ENV['TRAVIS'] ? 4 : nil

      options = {}
      options[:count] = num_processes if num_processes
      options[:group] = ENV['GROUP'] if ENV['GROUP']

      puts 'Launching parallel execution of spec/integration'
      run_in_parallel('spec/integration', options)
    end

    def run_in_parallel(test_path, options={})
      spec_path = ENV['SPEC_PATH']
      count = " -n #{options[:count]}" unless options[:count].to_s.empty?
      group = " --only-group #{options[:group]}" unless options[:group].to_s.empty?
      command = begin
        if spec_path
          "https_proxy= http_proxy= bundle exec rspec #{spec_path}"
        else
          "https_proxy= http_proxy= bundle exec parallel_test '#{test_path}'#{count}#{group} --group-by filesize --type rspec -o '--format documentation'"
        end
      end
      puts command
      abort unless system(command)
    end
  end

  task :integration => %w(spec:integration:agent)

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
      null_logger = Logging::Logger.new('Ignored')
      Bosh::ThreadPool.new(max_threads: max_threads, logger: null_logger).wrap do |pool|
        builds.each do |build|
          pool.process do
            log_file    = "#{spec_logs}/#{build}.log"
            rspec_files = cpi_builds.include?(build) ? "spec/unit/" : "spec/"
            rspec_cmd   = "rspec --tty --backtrace -c -f p #{rspec_files}"

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

    task(:agent) do
      # Do not use exec because this task is part of other tasks
      sh('cd go/src/github.com/cloudfoundry/bosh-agent/ && bin/test-unit')
    end
  end

  task :unit => %w(spec:unit:ruby_gems spec:unit:agent)

  namespace :external do
    desc 'AWS bootstrap CLI can provision and destroy resources'
    RSpec::Core::RakeTask.new(:aws_bootstrap) do |t|
      t.pattern = 'spec/external/aws_bootstrap_spec.rb'
      t.rspec_opts = %w(--format documentation --color)
    end
  end

  namespace :system do
    desc 'Run system (BATs) tests (deploys microbosh)'
    task :micro, [:infrastructure_name, :hypervisor_name, :operating_system_name, :operating_system_version, :net_type, :agent_name, :light, :disk_format] do |_, args|
      Bosh::Dev::BatHelper.for_rake_args(args).deploy_microbosh_and_run_bats
    end

    desc 'Run system (BATs) tests (uses existing microbosh)'
    task :existing_micro, [:infrastructure_name, :hypervisor_name, :operating_system_name, :operating_system_version, :net_type, :agent_name, :light, :disk_format] do |_, args|
      Bosh::Dev::BatHelper.for_rake_args(args).run_bats
    end

    desc 'Deploy microbosh for system (BATs) tests'
    task :deploy_micro, [:infrastructure_name, :hypervisor_name, :operating_system_name, :operating_system_version, :net_type, :agent_name, :light, :disk_format] do |_, args|
      Bosh::Dev::BatHelper.for_rake_args(args).deploy_bats_microbosh
    end
  end
end

desc 'Run unit and integration specs'
task :spec => %w(spec:unit spec:integration)
