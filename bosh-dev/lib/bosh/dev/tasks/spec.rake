require 'rspec'
require 'rspec/core/rake_task'
require 'tempfile'
require 'bosh/dev/bat_helper'

namespace :spec do
  desc 'Run BOSH integration tests against a local sandbox'
  task :integration do
    require 'parallel_tests/tasks'
    Rake::Task['parallel:spec'].invoke(nil, 'spec/integration/.*_spec.rb')
  end

  desc 'Run unit and functional tests for each BOSH component gem'
  task :parallel_unit do
    require 'common/thread_pool'

    trap('INT') do
      exit
    end

    builds = Dir['*'].select { |f| File.directory?(f) && File.exists?("#{f}/spec") }
    builds -= ['bat']

    spec_logs = Dir.mktmpdir

    puts "Logging spec results in #{spec_logs}"

    Bosh::ThreadPool.new(max_threads: 10, logger: Logger.new('/dev/null')).wrap do |pool|
      builds.each do |build|
        puts "-----Building #{build}-----"

        pool.process do
          log_file = "#{spec_logs}/#{build}.log"
          cmd = "cd #{build} && rspec --tty -c -f p spec > #{log_file} 2>&1"
          success = system(cmd)

          if success
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

    builds.each do |build|
      puts "-----#{build}-----"
      system("cd #{build} && rspec spec") || raise("#{build} failed to build unit tests")
    end
  end

  desc 'Run integration and unit tests in parallel'
  task :parallel_all do
    unit = Thread.new do
      Rake::Task['spec:parallel_unit'].invoke
    end
    integration = Thread.new do
      Rake::Task['spec:integration'].invoke
    end

    [unit, integration].each(&:join)
  end

  namespace :external do
    desc 'AWS CPI can exercise the VM lifecycle'
    RSpec::Core::RakeTask.new(:aws_vm_lifecycle) do |t|
      t.pattern = 'spec/external/aws_cpi_spec.rb'
      t.rspec_opts = %w(--format documentation --color)
    end

    desc 'AWS bootstrap CLI can provision and destroy resources'
    RSpec::Core::RakeTask.new(:aws_bootstrap) do |t|
      t.pattern = 'spec/external/aws_bootstrap_spec.rb'
      t.rspec_opts = %w(--format documentation --color)
    end

    desc 'OpenStack CPI can exercise the VM lifecycle'
    RSpec::Core::RakeTask.new(:openstack_vm_lifecycle) do |t|
      t.pattern = 'spec/external/openstack_cpi_spec.rb'
      t.rspec_opts = %w(--format documentation --color)
    end

    desc 'vSphere CPI can exercise the VM lifecycle'
    RSpec::Core::RakeTask.new(:vsphere_vm_lifecycle) do |t|
      require 'bosh/dev/build'
      ENV['BOSH_VSPHERE_STEMCELL'] = Bosh::Dev::Build.candidate.download_stemcell(infrastructure: Bosh::Stemcell::Infrastructure::Vsphere.new,
                                                                                  name: 'bosh-stemcell',
                                                                                  light: false)
      t.pattern = 'spec/external/vsphere_cpi_spec.rb'
      t.rspec_opts = %w(--format documentation --color)
    end
  end

  namespace :system do
    namespace :aws do
      desc 'Run AWS MicroBOSH deployment suite'
      task :micro do
        require 'bosh/dev/bat/aws_runner'
        Bosh::Dev::Bat::AwsRunner.new.run_bats
      end
    end

    namespace :openstack do
      desc 'Run OpenStack MicroBOSH deployment suite'
      task :micro do
        Rake::Task['spec:system:openstack:deploy_micro_dynamic_net'].invoke
        Rake::Task['spec:system:openstack:deploy_micro_manual_net'].invoke
      end

      task :deploy_micro_dynamic_net do
        begin
          Rake::Task['spec:system:openstack:deploy_micro'].execute('dynamic')
          Rake::Task['spec:system:openstack:bat'].execute
        ensure
          Rake::Task['spec:system:openstack:teardown_microbosh'].execute
        end
      end

      task :deploy_micro_manual_net do
        begin
          Rake::Task['spec:system:openstack:deploy_micro'].execute('manual')
          Rake::Task['spec:system:openstack:bat'].execute
        ensure
          Rake::Task['spec:system:openstack:teardown_microbosh'].execute
        end
      end

      task :deploy_micro, [:net_type] do |t, net_type|
        require 'bosh/dev/openstack/micro_bosh_deployment_manifest'
        require 'bosh/dev/openstack/bat_deployment_manifest'

        bat_helper = Bosh::Dev::BatHelper.new('openstack')

        chdir(bat_helper.artifacts_dir) do
          chdir(bat_helper.micro_bosh_deployment_dir) do

            micro_deployment_manifest = Bosh::Dev::Openstack::MicroBoshDeploymentManifest.new(net_type)
            micro_deployment_manifest.write
          end
          run_bosh "micro deployment #{bat_helper.micro_bosh_deployment_name}"
          run_bosh "micro deploy #{bat_helper.bosh_stemcell_path}"
          run_bosh 'login admin admin'

          run_bosh "upload stemcell #{bat_helper.bosh_stemcell_path}", debug_on_fail: true
          status = run_bosh 'status'
          director_uuid = /UUID(\s)+((\w+-)+\w+)/.match(status)[2]
          st_version = stemcell_version(bat_helper.bosh_stemcell_path)

          bat_deployment_manifest = Bosh::Dev::Openstack::BatDeploymentManifest.new(net_type, director_uuid, st_version)
          bat_deployment_manifest.write
        end
      end

      task :teardown_microbosh do
        bat_helper = Bosh::Dev::BatHelper.new('openstack')

        chdir(bat_helper.artifacts_dir) do
          run_bosh 'delete deployment bat', :ignore_failures => true
          run_bosh "delete stemcell bosh-stemcell #{stemcell_version(bat_helper.bosh_stemcell_path)}", :ignore_failures => true
          run_bosh 'micro delete', :ignore_failures => true
        end
      end

      task :bat do
        bat_helper = Bosh::Dev::BatHelper.new('openstack')

        ENV['BAT_DIRECTOR'] = ENV['BOSH_OPENSTACK_VIP_DIRECTOR_IP']
        ENV['BAT_STEMCELL'] = bat_helper.bosh_stemcell_path
        ENV['BAT_DEPLOYMENT_SPEC'] = File.join(bat_helper.artifacts_dir, 'bat.yml')
        ENV['BAT_VCAP_PASSWORD'] = 'c1oudc0w'
        ENV['BAT_VCAP_PRIVATE_KEY'] = ENV['BOSH_OPENSTACK_PRIVATE_KEY']
        ENV['BAT_DNS_HOST'] = ENV['BOSH_OPENSTACK_VIP_DIRECTOR_IP']
        ENV['BAT_FAST'] = 'true'
        Rake::Task['bat'].execute
      end
    end

    namespace :vsphere do
      desc 'Run vSphere MicroBOSH deployment suite'
      task :micro do
        require 'bosh/dev/bat/vsphere_runner'
        Bosh::Dev::Bat::VsphereRunner.new.run_bats
      end
    end

    def mnt
      @mnt ||= ENV.fetch('FAKE_MNT', '/mnt')
    end

    def stemcell_version(stemcell_tgz)
      stemcell_manifest(stemcell_tgz)['version']
    end

    def stemcell_manifest(stemcell_tgz)
      Dir.mktmpdir do |dir|
        system('tar', 'xzf', stemcell_tgz, '--directory', dir, 'stemcell.MF') || raise('Failed to untar stemcell')
        Psych.load_file(File.join(dir, 'stemcell.MF'))
      end
    end

    def bosh_config_path
      # We should keep a reference to the tempfile, otherwise,
      # when the object gets GC'd, the tempfile is deleted.
      @bosh_config_tempfile ||= Tempfile.new('bosh_config')
      @bosh_config_tempfile.path
    end

    def run(cmd, options = {})
      lines = []
      IO.popen(cmd).each do |line|
        puts line.chomp
        lines << line.chomp
      end.close # force the process to close so that $? is set
      if options[:last_number]
        line_number = options[:last_number]
        line_number = lines.size if lines.size < options[:last_number]
        cmd_out = lines[-line_number..-1].join("\n")
      else
        cmd_out = lines.join("\n")
      end

      unless $?.success?
        pwd = Dir.pwd rescue "a deleted directory"
        err_msg = "Failed: '#{cmd}' from #{pwd}, with exit status #{$?.to_i}\n\n #{cmd_out}"

        if options[:ignore_failures]
          puts("#{err_msg}, continuing anyway")
        else
          raise(err_msg)
        end
      end
      cmd_out
    end

    def run_bosh(cmd, options = {})
      debug_on_fail = options.fetch(:debug_on_fail, false)
      options.delete(:debug_on_fail)
      @run_bosh_failures ||= 0
      puts "bosh -v -n -P 10 --config '#{bosh_config_path}' #{cmd}"
      run "bosh -v -n -P 10 --config '#{bosh_config_path}' #{cmd}", options
    rescue
      @run_bosh_failures += 1
      if @run_bosh_failures == 1 && debug_on_fail
        # get the debug log, but only for the first failure, in case "bosh task last"
        # fails - or we'll end up in an endless loop
        run_bosh 'task last --debug', {:last_number => 100}
        @run_bosh_failures = 0
      end
      raise
    end
  end
end

desc 'Run unit and integration specs'
task :spec => ['spec:parallel_unit', 'spec:integration']
