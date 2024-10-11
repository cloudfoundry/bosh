require 'logging'
require 'rspec'
require 'tempfile'
require 'rspec/core/rake_task'
require 'bosh/dev/sandbox/nginx'
require 'bosh/dev/sandbox/workspace'
require 'common/thread_pool'
require 'bosh/dev/sandbox/services/uaa_service'
require 'bosh/dev/sandbox/services/config_server_service'
require 'bosh/dev/verify_multidigest_manager'
require 'bosh/dev/gnatsd_manager'
require 'parallel_tests/tasks'
require 'fileutils'

namespace :spec do
  namespace :integration do
    desc 'Run health monitor integration tests against a local sandbox'
    task health_monitor: :install_dependencies do
      run_integration_specs(spec_path: 'spec/integration', tags: 'hm')
    end

    desc 'Install BOSH integration test dependencies (currently Nginx, UAA, and Config Server)'
    task :install_dependencies do
      unless ENV['SKIP_DEPS'] == 'true'
        install_with_retries(Bosh::Dev::Sandbox::Nginx.new) unless ENV['SKIP_NGINX'] == 'true'

        Bosh::Dev::Sandbox::UaaService.install unless ENV['SKIP_UAA'] == 'true'

        Bosh::Dev::Sandbox::ConfigServerService.install unless ENV['SKIP_CONFIG_SERVER'] == 'true'

        Bosh::Dev::VerifyMultidigestManager.install unless ENV['SKIP_VERIFY_MULTIDIGEST'] == 'true'

        Bosh::Dev::GnatsdManager.install unless ENV['SKIP_GNATSD'] == 'true'
      end

      compile_dependencies
    end

    desc 'Download BOSH Agent. Use only for local dev environment'
    task :download_bosh_agent do
      trap('INT') { exit }
      cmd = 'mkdir -p ./go/src/github.com/cloudfoundry && '
      cmd += 'cd ./go/src/github.com/cloudfoundry && '
      cmd += 'rm -rf bosh-agent && '
      cmd += 'git clone https://github.com/cloudfoundry/bosh-agent.git'
      sh(cmd)
    end

    def install_with_retries(to_install)
      retries = 3
      begin
        to_install.install
      rescue StandardError
        puts "Failed to install #{to_install.inspect} on retry=#{retries}"
        retries -= 1
        retry if retries.positive?
        raise
      end
    end

    def run_integration_specs(run_options = {})
      Bosh::Dev::Sandbox::Workspace.clean
      uaa_service = Bosh::Dev::Sandbox::Workspace.start_uaa

      num_processes = ENV['NUM_PROCESSES']

      options = {}
      options.merge!(run_options)
      options[:count] = num_processes if num_processes

      spec_path = options.fetch(:spec_path)

      puts "Launching parallel execution of #{spec_path}"
      run_in_parallel(spec_path, options)
    ensure
      uaa_service.stop if uaa_service
    end

    def run_in_parallel(test_path, options = {})
      spec_path = ENV.fetch('SPEC_PATH', '').split(',')
      count_flag = "-n #{options[:count]}" unless options[:count].to_s.empty?

      rspec_options = '--format documentation '
      rspec_options += "--tag #{options[:tags]} " unless options[:tags].nil?
      spec_opts = "SPEC_OPTS='#{rspec_options}'"

      cmd_prefix = "#{spec_opts} https_proxy= http_proxy= bundle exec"

      command = begin
        if !spec_path.empty?
          "#{cmd_prefix} rspec #{spec_path.join(' ')}"
        else
          "#{cmd_prefix} parallel_rspec #{count_flag} --multiply-processes 0.5 '#{test_path}'"
        end
      end

      puts command
      raise unless system(command)
    end

    def compile_dependencies
      puts 'If this fails you may want to run rake spec:integration:download_bosh_agent'
      sh('cd go/src/github.com/cloudfoundry/bosh-agent/; bin/build; cd -')
    end
  end

  desc 'Run all integration tests against a local sandbox'
  task integration: %w[spec:integration:install_dependencies] do
    run_integration_specs(spec_path: 'spec/integration')
  end

  desc 'Run template test unit tests (i.e. Bosh::Template::Test)'
  task :template_test_unit do # TODO _why?_ this is run as part of `spec:unit:template:parallel`
    puts 'Template test unit tests (ERB templates)'
    sh('cd bosh-template/spec/assets/template-test-release/src && rspec')
  end

  def component_spec_dirs
    @component_spec_dirs ||= Dir['*/spec']
  end

  def component_dir(component_spec_dir)
    File.dirname(component_spec_dir)
  end

  def component_symbol(component_spec_dir)
    component_dir(component_spec_dir).sub(/^bosh[_-]/, '').to_sym
  end

  namespace :unit do
    desc 'Run all release unit tests (ERB templates)'
    task :release do
      puts 'Run unit tests for the release (ERB templates)'
      sh("cd #{File.expand_path('..')} && rspec")
    end

    namespace :release do
      task :parallel do
        puts 'Run unit tests for the release (ERB templates)'
        sh("cd #{File.expand_path('..')} && parallel_rspec spec")
      end
    end

    component_spec_dirs.each do |component_spec_dir|
      desc "Run unit tests for the #{component_dir(component_spec_dir)} component"
      task component_symbol(component_spec_dir) do
        trap('INT') { exit }
        sh("cd #{File.expand_path(component_dir(component_spec_dir))} && rspec")
      end

      namespace component_symbol(component_spec_dir) do
        desc "Run parallel unit tests for the #{component_dir(component_spec_dir)} component"
        task :parallel do
          trap('INT') { exit }
          sh("cd #{File.expand_path(component_dir(component_spec_dir))} && parallel_rspec spec")
        end
      end
    end

    desc 'Run all migrations tests'
    task :migrations do
      trap('INT') { exit }
      sh("cd #{File.expand_path('bosh-director')} && rspec spec/unit/db/migrations/")
    end

    desc 'Run all unit tests in parallel'
    multitask parallel: %w[spec:unit:release:parallel] + component_spec_dirs.map{|d| "spec:unit:#{component_symbol(d)}:parallel" } do
      trap('INT') { exit }
    end
  end

  desc 'Run all unit tests'
  task unit: %w[spec:unit:release] + component_spec_dirs.map{|d| "spec:unit:#{component_symbol(d)}" }
end

desc 'Run unit and integration specs'
task spec: %w[spec:unit spec:integration]
