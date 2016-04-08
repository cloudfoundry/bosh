require 'rspec'
require 'tempfile'
require 'rspec/core/rake_task'
require 'bosh/dev/bat_helper'
require 'bosh/dev/sandbox/nginx'
require 'bosh/dev/sandbox/services/connection_proxy_service'
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

    desc 'Run health monitor integration tests against a local sandbox'
    task :health_monitor => :install_dependencies do
      sh('go/src/github.com/cloudfoundry/bosh-agent/bin/build')
      run_integration_specs(tags: 'hm')
    end

    desc 'Install BOSH integration test dependencies (currently Nginx)'
    task :install_dependencies do
      unless ENV['SKIP_DEPS'] == 'true'
        unless ENV['SKIP_NGINX'] == 'true'
          nginx = Bosh::Dev::Sandbox::Nginx.new
          install_with_retries(nginx)
        end

        unless ENV['SKIP_TCP_PROXY_NGINX'] == 'true'
          tcp_proxy_nginx = Bosh::Dev::Sandbox::TCPProxyNginx.new
          install_with_retries(tcp_proxy_nginx)
        end

        unless ENV['SKIP_UAA'] == 'true'
          Bosh::Dev::Sandbox::UaaService.install
        end
      end
    end

    def install_with_retries(to_install)
      retries = 3
      begin
        to_install.install
      rescue
        retries -= 1
        retry if retries > 0
        raise
      end
    end

    def run_integration_specs(run_options={})
      Bosh::Dev::Sandbox::Workspace.clean

      num_processes   = ENV['NUM_GROUPS']
      num_processes ||= ENV['TRAVIS'] ? 4 : nil

      options = {}
      options.merge!(run_options)
      options[:count] = num_processes if num_processes
      options[:group] = ENV['GROUP'] if ENV['GROUP']

      puts 'Launching parallel execution of spec/integration'
      run_in_parallel('spec/integration', options)
    end

    def run_in_parallel(test_path, options={})
      spec_path = ENV['SPEC_PATH'] || ''
      count = " -n #{options[:count]}" unless options[:count].to_s.empty?
      group = " --only-group #{options[:group]}" unless options[:group].to_s.empty?
      tag = "SPEC_OPTS='--tag #{options[:tags]}'" unless options[:tags].nil?
      command = begin
        if '' != spec_path
          "#{tag} https_proxy= http_proxy= bundle exec rspec #{spec_path}"
        else
          "#{tag} https_proxy= http_proxy= bundle exec parallel_test '#{test_path}'#{count}#{group} --group-by filesize --type rspec -o '--format documentation'"
        end
      end
      puts command
      abort unless system(command)
    end
  end

  task :integration => %w(spec:integration:agent)

  def unit_exec(build, log_file = nil)
    command = unit_cmd(build, log_file)

    # inject command name so coverage results for each component don't clobber others
    if system({'BOSH_BUILD_NAME' => build}, "cd #{build} && #{command}") && log_file
      puts "----- BEGIN #{build}"
      puts "            #{command}"
      print File.read(log_file)
      puts "----- END   #{build}\n\n"
    else
      raise("#{build} failed to build unit tests: #{File.read(log_file)}") if log_file
    end
  end

  def unit_cmd(build, log_file = nil)
    "".tap do |cmd|
      cmd << "rspec --tty --backtrace -c -f p #{unit_files(build)}"
      cmd << " > #{log_file} 2>&1" if log_file
    end
  end

  def unit_files(build)
    cpi_builds.include?(build) ? 'spec/unit/' : 'spec/'
  end

  def unit_builds
    @unit_builds ||= begin
      builds = Dir['*'].select { |f| File.directory?(f) && File.exists?("#{f}/spec") }
      builds -= %w(bat)
    end
  end

  def cpi_builds
    @cpi_builds ||= unit_builds.select { |f| File.directory?(f) && f.end_with?("_cpi") }
  end

  namespace :unit do
    desc 'Run all unit tests for ruby components'
    task ruby: %w(rubocop) do
      trap('INT') { exit }
      log_dir = Dir.mktmpdir
      puts "Logging spec results in #{log_dir}"

      max_threads = ENV.fetch('BOSH_MAX_THREADS', 10).to_i
      null_logger = Logging::Logger.new('Ignored')
      Bosh::ThreadPool.new(max_threads: max_threads, logger: null_logger).wrap do |pool|
        unit_builds.each do |build|
          pool.process do
            unit_exec(build, "#{log_dir}/#{build}.log")
          end
        end

        pool.wait
      end
    end

    (unit_builds - cpi_builds).each do |build|
      desc "Run unit tests for the #{build} component"
      task build.sub(/^bosh[_-]/, '').intern do
        trap('INT') { exit }
        unit_exec(build)
      end
    end

    task(:agent) do
      # Do not use exec because this task is part of other tasks
      sh('cd go/src/github.com/cloudfoundry/bosh-agent/ && bin/test-unit')
    end
  end

  desc "Run all unit tests"
  task :unit => %w(spec:unit:ruby spec:unit:agent)

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
