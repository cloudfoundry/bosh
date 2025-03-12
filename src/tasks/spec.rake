namespace :spec do
  desc 'Run all integration tests against a local sandbox'
  task :integration do
    $LOAD_PATH << File.join(BOSH_SRC_ROOT, 'spec')
    require 'integration_support/sandbox'
    IntegrationSupport::Sandbox.setup

    rspec_opts = ['--format documentation']
    rspec_opts += ENV.fetch('RSPEC_TAGS', '').split(',').map { |t| "--tag #{t}" }

    paths = ENV.fetch('SPEC_PATH', 'spec').split(',').join(' ')

    spec_runner_command =
      if paths =~ /:\d+/ # line number was specified; run with `rspec`
        "bundle exec rspec #{rspec_opts.join(' ')}"
      else # no line number specified; run with `parallel_rspec`
        "SPEC_OPTS='#{rspec_opts.join(' ')}' bundle exec parallel_rspec"
      end

    proxy_env = 'https_proxy= http_proxy='

    sh("#{proxy_env} #{spec_runner_command} #{paths}")
  ensure
    IntegrationSupport::Sandbox.teardown
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
      sh("cd #{BOSH_REPO_ROOT} && rspec")
    end

    namespace :release do
      task :parallel do
        puts 'Run unit tests for the release (ERB templates)'
        sh("cd #{BOSH_REPO_ROOT} && parallel_rspec spec")
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
