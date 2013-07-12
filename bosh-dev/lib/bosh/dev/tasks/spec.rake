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
  task :unit do
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
      t.pattern = 'spec/external/vsphere_cpi_spec.rb'
      t.rspec_opts = %w(--format documentation --color)
    end

  end

  namespace :system do
    namespace :aws do
      def bat_helper
        @bat_helper ||= Bosh::Dev::BatHelper.new(ENV['WORKSPACE'], 'aws')
      end

      desc 'Run AWS MicroBOSH deployment suite'
      task :micro do
        begin
          Rake::Task['spec:system:aws:deploy_micro'].invoke
          Rake::Task['spec:system:aws:bat'].invoke
        ensure
          Rake::Task['spec:system:aws:teardown_microbosh'].invoke
        end
      end

      task :deploy_micro => :get_deployments_aws do
        rm_rf(bat_helper.artifacts_dir)
        mkdir_p(bat_helper.micro_bosh_deployment_dir)

        chdir(bat_helper.artifacts_dir) do
          chdir(bat_helper.micro_bosh_deployment_dir) do
            run_bosh "aws generate micro_bosh '#{vpc_outfile_path}' '#{route53_outfile_path}'"
          end
          run_bosh 'micro deployment micro'
          run_bosh "micro deploy #{bat_helper.micro_bosh_stemcell_path}"
          run_bosh 'login admin admin'

          run_bosh "upload stemcell #{bat_helper.bosh_stemcell_path}", debug_on_fail: true

          st_version = stemcell_version(bat_helper.bosh_stemcell_path)
          run_bosh "aws generate bat '#{vpc_outfile_path}' '#{route53_outfile_path}' '#{st_version}'"
        end
      end

      task :teardown_microbosh do
        if Dir.exists?(bat_helper.artifacts_dir)
          chdir(bat_helper.artifacts_dir) do
            run_bosh 'delete deployment bat', :ignore_failures => true
            run_bosh 'micro delete', :ignore_failures => true
          end
          rm_rf(bat_helper.artifacts_dir)
        end
      end

      task :bat do
        director = "micro.#{ENV["BOSH_VPC_SUBDOMAIN"]}.cf-app.com"
        ENV['BAT_DIRECTOR'] = director
        ENV['BAT_STEMCELL'] = bat_helper.bosh_stemcell_path
        ENV['BAT_DEPLOYMENT_SPEC'] = File.join(bat_helper.artifacts_dir, 'bat.yml')
        ENV['BAT_VCAP_PASSWORD'] = 'c1oudc0w'
        ENV['BAT_FAST'] = 'true'
        ENV['BAT_DNS_HOST'] = Resolv.getaddress(director)
        Rake::Task['bat'].invoke
      end

      task :get_deployments_aws do
        Dir.chdir('/mnt') do
          if Dir.exists?('deployments')
            Dir.chdir('deployments') do
              run('git pull')
            end
          else
            run("git clone #{ENV['BOSH_JENKINS_DEPLOYMENTS_REPO']} deployments")
          end
        end
      end
    end

    namespace :openstack do
      def bat_helper
        @bat_helper ||= Bosh::Dev::BatHelper.new(ENV['WORKSPACE'], 'openstack')
      end

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
        rm_rf(bat_helper.artifacts_dir)
        mkdir_p(bat_helper.micro_bosh_deployment_dir)

        chdir(bat_helper.artifacts_dir) do
          chdir(bat_helper.micro_bosh_deployment_dir) do
            generate_openstack_micro_bosh(net_type)
          end
          run_bosh 'micro deployment microbosh'
          run_bosh "micro deploy #{bat_helper.micro_bosh_stemcell_path}"
          run_bosh 'login admin admin'

          run_bosh "upload stemcell #{bat_helper.bosh_stemcell_path}", debug_on_fail: true
          status = run_bosh 'status'
          director_uuid = /UUID(\s)+((\w+-)+\w+)/.match(status)[2]
          st_version = stemcell_version(bat_helper.bosh_stemcell_path)
          generate_openstack_bat_manifest(net_type, director_uuid, st_version)
        end
      end

      task :teardown_microbosh do
        chdir(bat_helper.artifacts_dir) do
          run_bosh 'delete deployment bat', :ignore_failures => true
          run_bosh "delete stemcell bosh-stemcell #{stemcell_version(bat_helper.bosh_stemcell_path)}", :ignore_failures => true
          run_bosh 'micro delete', :ignore_failures => true
        end
        rm_rf(bat_helper.artifacts_dir)
      end

      task :bat do
        cd(ENV['WORKSPACE']) do
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
    end

    namespace :vsphere do
      def bat_helper
        @bat_helper ||= Bosh::Dev::BatHelper.new(ENV['WORKSPACE'], 'vsphere')
      end

      desc 'Run vSphere MicroBOSH deployment suite'
      task :micro do
        begin
          Rake::Task['spec:system:vsphere:deploy_micro'].invoke
          Rake::Task['spec:system:vsphere:bat'].invoke
        ensure
          Rake::Task['spec:system:vsphere:teardown_microbosh'].invoke
        end
      end

      task :deploy_micro do
        rm_rf(bat_helper.artifacts_dir)
        mkdir_p(bat_helper.micro_bosh_deployment_dir)

        cd(bat_helper.artifacts_dir) do
          cd(bat_helper.micro_bosh_deployment_dir) do
            generate_vsphere_micro_bosh
          end
          run_bosh 'micro deployment microbosh'
          run_bosh "micro deploy #{bat_helper.micro_bosh_stemcell_path}"
          run_bosh 'login admin admin'

          run_bosh "upload stemcell #{bat_helper.bosh_stemcell_path}", debug_on_fail: true
          status = run_bosh 'status'
          director_uuid = /UUID(\s)+((\w+-)+\w+)/.match(status)[2]
          st_version = stemcell_version(bat_helper.bosh_stemcell_path)
          generate_vsphere_bat_manifest(director_uuid, st_version)
        end
      end

      task :teardown_microbosh do
        cd(bat_helper.artifacts_dir) do
          run_bosh 'delete deployment bat', :ignore_failures => true
          run_bosh "delete stemcell bosh-stemcell #{stemcell_version(bat_helper.bosh_stemcell_path)}", :ignore_failures => true
          run_bosh 'micro delete', :ignore_failures => true
        end
        rm_rf(bat_helper.artifacts_dir)
      end

      task :bat do
        cd(ENV['WORKSPACE']) do
          ENV['BAT_DIRECTOR'] = ENV['BOSH_VSPHERE_MICROBOSH_IP']
          ENV['BAT_STEMCELL'] = bat_helper.bosh_stemcell_path
          ENV['BAT_DEPLOYMENT_SPEC'] = File.join(bat_helper.artifacts_dir, 'bat.yml')
          ENV['BAT_VCAP_PASSWORD'] = 'c1oudc0w'
          ENV['BAT_DNS_HOST'] = ENV['BOSH_VSPHERE_MICROBOSH_IP']
          ENV['BAT_FAST'] = 'true'
          Rake::Task['bat'].execute
        end
      end
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

    def vpc_outfile_path
      File.join('/mnt', 'deployments', ENV['BOSH_VPC_SUBDOMAIN'], 'aws_vpc_receipt.yml')
    end

    def route53_outfile_path
      File.join('/mnt', 'deployments', ENV['BOSH_VPC_SUBDOMAIN'], 'aws_route53_receipt.yml')
    end

    def generate_openstack_micro_bosh(net_type)
      name = net_type
      vip = ENV['BOSH_OPENSTACK_VIP_DIRECTOR_IP']
      ip = ENV['BOSH_OPENSTACK_MANUAL_IP']
      net_id = ENV['BOSH_OPENSTACK_NET_ID']
      auth_url = ENV['BOSH_OPENSTACK_AUTH_URL']
      username = ENV['BOSH_OPENSTACK_USERNAME']
      api_key = ENV['BOSH_OPENSTACK_API_KEY']
      tenant = ENV['BOSH_OPENSTACK_TENANT']
      region = ENV['BOSH_OPENSTACK_REGION']
      private_key_path = ENV['BOSH_OPENSTACK_PRIVATE_KEY']
      template_path = File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', '..', 'templates', 'micro_bosh_openstack.yml.erb'))
      micro_bosh_manifest = ERB.new(File.read(template_path)).result(binding)
      File.open("micro_bosh.yml", "w+") do |f|
        f.write(micro_bosh_manifest)
      end
    end

    def generate_openstack_bat_manifest(net_type, director_uuid, st_version)
      vip = ENV['BOSH_OPENSTACK_VIP_BAT_IP']
      net_id = ENV['BOSH_OPENSTACK_NET_ID']
      stemcell_version = st_version
      net_cidr = ENV['BOSH_OPENSTACK_NETWORK_CIDR']
      net_reserved = ENV['BOSH_OPENSTACK_NETWORK_RESERVED']
      net_static = ENV['BOSH_OPENSTACK_NETWORK_STATIC']
      net_gateway = ENV['BOSH_OPENSTACK_NETWORK_GATEWAY']
      template_path = File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', '..', 'templates', 'bat_openstack.yml.erb'))
      bat_manifest = ERB.new(File.read(template_path)).result(binding)
      File.open('bat.yml', 'w+') do |f|
        f.write(bat_manifest)
      end
    end

    def generate_vsphere_micro_bosh
      ip = ENV['BOSH_VSPHERE_MICROBOSH_IP']
      netmask = ENV['BOSH_VSPHERE_NETMASK']
      gateway = ENV['BOSH_VSPHERE_GATEWAY']
      dns = ENV['BOSH_VSPHERE_DNS']
      net_id = ENV['BOSH_VSPHERE_NET_ID']
      ntp_server = ENV['BOSH_VSPHERE_NTP_SERVER']
      vcenter = ENV['BOSH_VSPHERE_VCENTER']
      vcenter_user = ENV['BOSH_VSPHERE_VCENTER_USER']
      vcenter_pwd = ENV['BOSH_VSPHERE_VCENTER_PASSWORD']
      vcenter_dc = ENV['BOSH_VSPHERE_VCENTER_DC']
      vcenter_cluster = ENV['BOSH_VSPHERE_VCENTER_CLUSTER']
      vcenter_rp = ENV['BOSH_VSPHERE_VCENTER_RESOURCE_POOL']
      vcenter_folder_prefix = ENV['BOSH_VSPHERE_VCENTER_FOLDER_PREFIX']
      vcenter_ubosh_folder_prefix = ENV['BOSH_VSPHERE_VCENTER_UBOSH_FOLDER_PREFIX']
      vcenter_datastore_pattern = ENV['BOSH_VSPHERE_VCENTER_DATASTORE_PATTERN']
      vcenter_ubosh_datastore_pattern = ENV['BOSH_VSPHERE_VCENTER_UBOSH_DATASTORE_PATTERN']
      template_path = File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', '..', 'templates', 'micro_bosh_vsphere.yml.erb'))
      micro_bosh_manifest = ERB.new(File.read(template_path)).result(binding)
      File.open("micro_bosh.yml", "w+") do |f|
        f.write(micro_bosh_manifest)
      end
    end

    def generate_vsphere_bat_manifest(director_uuid, st_version)
      ip = ENV['BOSH_VSPHERE_BAT_IP']
      net_id = ENV['BOSH_VSPHERE_NET_ID']
      stemcell_version = st_version
      net_cidr = ENV['BOSH_VSPHERE_NETWORK_CIDR']
      net_reserved = ENV['BOSH_VSPHERE_NETWORK_RESERVED'].split(/[|,]/).map(&:strip)
      net_static = ENV['BOSH_VSPHERE_NETWORK_STATIC']
      net_gateway = ENV['BOSH_VSPHERE_NETWORK_GATEWAY']
      template_path = File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', '..', 'templates', 'bat_vsphere.yml.erb'))
      bat_manifest = ERB.new(File.read(template_path)).result(binding)
      File.open('bat.yml', 'w+') do |f|
        f.write(bat_manifest)
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
