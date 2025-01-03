require 'rspec'
require 'rspec/core/rake_task'
require 'parallel_tests/tasks'

namespace :spec do
  namespace :integration do
    require 'integration_support/workspace'
    require 'integration_support/sandbox'

    def run_integration_specs(tags: nil)
      IntegrationSupport::Sandbox.install_dependencies
      IntegrationSupport::Workspace.clean
      IntegrationSupport::Workspace.uaa_service.start

      proxy_env = 'https_proxy= http_proxy='

      rspec_opts += "--tag #{tags}" if tags
      rspec_opts = "SPEC_OPTS='--format documentation #{rspec_opts}'"

      parallel_options = '--multiply-processes 0.5'
      if (num_processes = ENV.fetch('NUM_PROCESSES', nil))
        parallel_options += " -n #{num_processes}"
      end

      paths = ENV.fetch('SPEC_PATH', ['spec']).split(',').join(' ')

      command =
        "#{proxy_env} #{rspec_opts} bundle exec parallel_rspec #{parallel_options} #{paths}"

      puts command
      raise unless system(command)
    ensure
      IntegrationSupport::Workspace.uaa_service.stop
    end
  end

  desc 'Run all integration tests against a local sandbox'
  task :integration do
    run_integration_specs
  end

  desc 'Run template test unit tests (i.e. Bosh::Template::Test)'
  task :template_test_unit do # TODO _why?_ this is run as part of `spec:unit:template:parallel`
    puts 'Template test unit tests (ERB templates)'
    sh('cd bosh-template/spec/assets/template-test-release/src && rspec')
  end

  namespace :unit do
    def excluded_component_dirs
      []
    end

    def component_dir_names
      @component_dir_names ||= (Dir['*/spec'].map { |d| File.dirname(d) } - excluded_component_dirs)
    end

    def component_symbol(component_dir_name)
      component_dir_name.gsub('-', '_').sub(/^bosh_/, '').to_sym
    end

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

    component_dir_names.each do |component_dir_name|
      desc "Run unit tests for the #{component_dir_name} component"
      task component_symbol(component_dir_name) do
        trap('INT') { exit }
        sh("cd #{File.expand_path(component_dir_name)} && rspec")
      end

      namespace component_symbol(component_dir_name) do
        desc "Run parallel unit tests for the #{component_dir_name} component"
        task :parallel do
          trap('INT') { exit }
          sh("cd #{File.expand_path(component_dir_name)} && parallel_rspec spec")
        end
      end
    end

    desc 'Run all migrations tests'
    task :migrations do
      trap('INT') { exit }
      sh("cd #{File.expand_path('bosh-director')} && rspec spec/unit/db/migrations/")
    end

    desc 'Run all unit tests in parallel'
    multitask parallel: %w[spec:unit:release:parallel] + component_dir_names.map{|d| "spec:unit:#{component_symbol(d)}:parallel" } do
      trap('INT') { exit }
    end
  end

  desc 'Run all unit tests'
  task unit: %w[spec:unit:release] + component_dir_names.map{|d| "spec:unit:#{component_symbol(d)}" }
end

desc 'Run unit and integration specs'
task spec: %w[spec:unit spec:integration]
