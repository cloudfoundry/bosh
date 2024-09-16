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
require 'bosh/dev/test_runner'
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
      FileUtils.mkdir_p('tmp')
      File.open('tmp/compilation.log', 'w') do |compilation_log|
        unless ENV['SKIP_DEPS'] == 'true'
          unless ENV['SKIP_NGINX'] == 'true'
            nginx = Bosh::Dev::Sandbox::Nginx.new(Bosh::Core::Shell.new(compilation_log))
            install_with_retries(nginx)
          end

          Bosh::Dev::Sandbox::UaaService.install unless ENV['SKIP_UAA'] == 'true'

          Bosh::Dev::Sandbox::ConfigServerService.install unless ENV['SKIP_CONFIG_SERVER'] == 'true'

          Bosh::Dev::VerifyMultidigestManager.install unless ENV['SKIP_VERIFY_MULTIDIGEST'] == 'true'

          Bosh::Dev::GnatsdManager.install unless ENV['SKIP_GNATSD'] == 'true'
        end

        compile_dependencies
      end
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
      count = " -n #{options[:count]}" unless options[:count].to_s.empty?
      tag = "SPEC_OPTS='--tag #{options[:tags]}'" unless options[:tags].nil?

      command = begin
        if !spec_path.empty?
          "#{tag} https_proxy= http_proxy= bundle exec rspec #{spec_path.join(' ')}"
        else
          <<-BASH
          #{tag} https_proxy= http_proxy= bundle exec parallel_test \
            --runtime-log parallel_runtime_rspec.log \
            -m 0.5 \
            '#{test_path}'#{count} --type rspec
          BASH
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
    sh('rspec bosh-template/spec/assets/template-test-release/src/spec/config.erb_spec.rb')
  end

  namespace :unit do
    runner = Bosh::Dev::TestRunner.new

    desc 'Run all unit tests for ruby components'
    task :ruby do
      trap('INT') { exit }
      runner.ruby
    end

    desc 'Run all unit tests for ruby components in parallel'
    task :ruby_parallel do
      trap('INT') { exit }
      runner.ruby(parallel: true)
    end

    desc 'Run all release unit tests (ERB templates)'
    task :release do
      puts 'Run unit tests for the release (ERB templates)'
      Dir.chdir '..' do
        sh(runner.unit_cmd)
      end
    end

    runner.unit_builds.each do |build|
      desc "Run unit tests for the #{build} component"
      task build.sub(/^bosh[_-]/, '').intern do
        trap('INT') { exit }
        Dir.chdir build do
          sh("#{runner.unit_cmd(build)}")
        end
      end

      namespace build.sub(/^bosh[_-]/, '').intern do
        desc "Run parallel unit tests for the #{build} component"
        task :parallel do
          trap('INT') { exit }
          Dir.chdir build do
            sh("#{runner.unit_parallel(build)}")
          end
        end
      end
    end

    desc 'Run all migrations tests'
    task :migrations do
      trap('INT') { exit }
      cmd = 'rspec --tty --backtrace -c -f p ./spec/unit/db/migrations/'
      sh("cd bosh-director && #{cmd}")
    end

    desc 'Run all unit tests in parallel'
    task parallel: %w[spec:unit:release spec:unit:ruby_parallel spec:template_test_unit]
  end

  desc 'Run all unit tests'
  task unit: %w[spec:unit:release spec:unit:ruby spec:template_test_unit]
end

desc 'Run unit and integration specs'
task spec: %w[spec:unit spec:integration]
