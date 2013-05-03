require "rspec"
require "rspec/core/rake_task"
require 'tempfile'

require "common/thread_pool"

require "parallel_tests/tasks"

namespace :spec do

  desc "Run BOSH integration tests against a local sandbox"
  task :integration do
    Rake::Task["parallel:spec"]
      .invoke(nil, "spec/integration/.*_spec.rb")
  end

  desc "Run unit and functional tests for each BOSH component gem"
  task :parallel_unit do
    trap("INT") do
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

  desc "Run unit and functional tests linearly"
  task :unit do
    builds = Dir['*'].select { |f| File.directory?(f) && File.exists?("#{f}/spec") }
    builds -= ['bat']

    builds.each do |build|
      puts "-----#{build}-----"
      system("cd #{build} && rspec spec") || raise("#{build} failed to build unit tests")
    end
  end

  desc "Run integration and unit tests in parallel"
  task :parallel_all do
    unit = Thread.new do
      Rake::Task["spec:parallel_unit"].invoke
    end
    integration = Thread.new do
      Rake::Task["spec:integration"].invoke
    end

    [unit, integration].each(&:join)
  end

  namespace :external do
    desc "AWS CPI can exercise the VM lifecycle"
    RSpec::Core::RakeTask.new(:aws_vm_lifecycle) do |t|
      t.pattern = "spec/external/aws_cpi_spec.rb"
      t.rspec_opts = %w(--format documentation --color)
    end

    desc "AWS bootstrap CLI can provision and destroy resources"
    RSpec::Core::RakeTask.new(:aws_bootstrap) do |t|
      t.pattern = "spec/external/aws_bootstrap_spec.rb"
      t.rspec_opts = %w(--format documentation --color)
    end

    desc "OpenStack CPI can exercise the VM lifecycle"
    RSpec::Core::RakeTask.new(:openstack_vm_lifecycle) do |t|
      t.pattern = "spec/external/openstack_cpi_spec.rb"
      t.rspec_opts = %w(--format documentation --color)
    end
  end

  namespace :system do
    namespace :aws do
      desc "Run AWS MicroBOSH deployment suite"
      task :micro do
        begin
          Rake::Task['spec:system:aws:publish_gems'].invoke
          publish_stemcell_to_s3(latest_aws_stemcell_path, 'bosh-jenkins-artifacts')
          publish_stemcell_to_s3(latest_aws_micro_bosh_stemcell_path, 'bosh-jenkins-artifacts')
        ensure
          Rake::Task['spec:system:aws:teardown_microbosh'].invoke
        end
      end

      task :deploy_micro do
        rm_rf("/tmp/deployments")
        mkdir_p("/tmp/deployments/micro")
        chdir("/tmp/deployments") do
          chdir("micro") do
            run_bosh "aws generate micro_bosh '#{vpc_outfile_path}' '#{route53_outfile_path}'"
          end
          run_bosh "micro deployment micro"
          run_bosh "micro deploy #{latest_aws_micro_bosh_stemcell_path}"
          run_bosh "login admin admin"

          run_bosh "upload stemcell #{latest_aws_stemcell_path}", debug_on_fail: true

          st_version = stemcell_version(latest_aws_stemcell_path)
          run_bosh "aws generate bat_manifest '#{vpc_outfile_path}' '#{route53_outfile_path}' '#{st_version}'"
        end
      end

      task :teardown_microbosh do
        chdir("/tmp/deployments") do
          run_bosh "delete deployment bat", :ignore_failures => true
          run_bosh "micro delete"
        end
        rm_rf("/tmp/deployments")
      end

      task :bat => :deploy_micro do
        director = "micro.#{ENV["BOSH_VPC_SUBDOMAIN"]}.cf-app.com"
        ENV['BAT_DIRECTOR'] = director
        ENV['BAT_STEMCELL'] = latest_aws_stemcell_path
        ENV['BAT_DEPLOYMENT_SPEC'] = "/tmp/deployments/bat.yml"
        ENV['BAT_VCAP_PASSWORD'] = 'c1oudc0w'
        ENV['BAT_FAST'] = 'true'
        #ENV['BAT_DEBUG'] = 'verbose'
        ENV['BAT_DNS_HOST'] = Resolv.getaddress(director)
        Rake::Task['bat'].invoke
      end

      task :publish_gems => "spec:system:aws:bat" do
        cd(ENV['WORKSPACE']) do
          build_number = ENV['BUILD_NUMBER']
          file_contents = File.read("BOSH_VERSION")
          file_contents.gsub!(/^([\d\.]+)\.pre\.\d+$/, "\\1.pre.#{build_number}")
          File.open("BOSH_VERSION", 'w') { |f| f.write file_contents }
          Rake::Task["all:pre_stage_latest"].invoke
          #run("cd pkg/gems && s3cmd get s3://bosh-jenkins-gems/gems/* .")
          Bundler.with_clean_env do
            # We need to run this without Bundler as we generate an index for all dependant gems when run with bundler
            run("cd pkg && gem generate_index .")
          end
          run("cd pkg && s3cmd sync . s3://bosh-jenkins-gems")
        end
      end
    end

    namespace :openstack do
      desc "Run OpenStack MicroBOSH deployment suite"
      task :micro do
        Rake::Task['spec:system:openstack:deploy_micro_dynamic_net'].invoke
        Rake::Task['spec:system:openstack:deploy_micro_manual_net'].invoke
        publish_stemcell_to_s3(latest_openstack_stemcell_path, 'bosh-jenkins-artifacts')
        publish_stemcell_to_s3(latest_openstack_micro_bosh_stemcell_path, 'bosh-jenkins-artifacts')
      end

      task :deploy_micro_dynamic_net do
        begin
          Rake::Task['spec:system:openstack:deploy_micro'].execute("dynamic")
        ensure
          Rake::Task['spec:system:openstack:teardown_microbosh'].execute
        end
      end

      task :deploy_micro_manual_net do
        begin
          Rake::Task['spec:system:openstack:deploy_micro'].execute("manual")
        ensure
          Rake::Task['spec:system:openstack:teardown_microbosh'].execute
        end
      end

      task :deploy_micro, [:net_type] do |t, net_type|
        rm_rf("/tmp/openstack-ci/deployments")
        mkdir_p("/tmp/openstack-ci/deployments/microbosh")
        chdir("/tmp/openstack-ci/deployments") do
          chdir("microbosh") do
            generate_openstack_micro_bosh(net_type)
          end
          run_bosh "micro deployment microbosh"
          run_bosh "micro deploy #{latest_openstack_micro_bosh_stemcell_path}"
          run_bosh "login admin admin"

          run_bosh "upload stemcell #{latest_openstack_stemcell_path}", debug_on_fail: true
          status = run_bosh "status"
          director_uuid = /UUID(\s)+((\w+-)+\w+)/.match(status)[2]
          st_version = stemcell_version(latest_openstack_stemcell_path)
          generate_openstack_bat_manifest(net_type, director_uuid, st_version)
        end

        Rake::Task['spec:system:openstack:bat'].execute
      end

      task :teardown_microbosh do
        chdir("/tmp/openstack-ci/deployments") do
          run_bosh "delete deployment bat", :ignore_failures => true
          run_bosh "delete stemcell bosh-stemcell #{stemcell_version(latest_openstack_stemcell_path)}", :ignore_failures => true
          run_bosh "micro delete"
        end
        rm_rf("/tmp/openstack-ci/deployments")
      end

      task :bat do
        cd(ENV['WORKSPACE']) do
          ENV['BAT_DIRECTOR'] = ENV["BOSH_OPENSTACK_VIP_DIRECTOR_IP"]
          ENV['BAT_STEMCELL'] = latest_openstack_stemcell_path
          ENV['BAT_DEPLOYMENT_SPEC'] = "/tmp/openstack-ci/deployments/bat.yml"
          ENV['BAT_VCAP_PASSWORD'] = 'c1oudc0w'
          ENV['BAT_VCAP_PRIVATE_KEY'] = ENV["BOSH_OPENSTACK_PRIVATE_KEY"]
          ENV['BAT_DNS_HOST'] = ENV["BOSH_OPENSTACK_VIP_DIRECTOR_IP"]
          ENV['BAT_FAST'] = 'true'
          Rake::Task['bat'].execute
        end
      end
    end

    def publish_stemcell_to_s3(stemcell_tgz, bucket_name)
      require "aws-sdk"

      AWS.config({
                     access_key_id: ENV['AWS_ACCESS_KEY_ID_FOR_STEMCELLS_JENKINS_ACCOUNT'],
                     secret_access_key: ENV['AWS_SECRET_ACCESS_KEY_FOR_STEMCELLS_JENKINS_ACCOUNT']
                 })

      Dir.mktmpdir do |dir|
        %x{tar xzf #{stemcell_tgz} --directory=#{dir} stemcell.MF} || raise("Failed to untar stemcell")
        stemcell_manifest = "#{dir}/stemcell.MF"
        stemcell_properties = Psych.load_file(stemcell_manifest)
        stemcell_S3_name = "#{stemcell_properties["name"]}-#{stemcell_properties["cloud_properties"]["infrastructure"]}"

        s3 = AWS::S3.new
        s3.buckets.create(bucket_name) # doesn't fail if already exists in your account
        bucket = s3.buckets[bucket_name]

        if stemcell_properties['cloud_properties']['ami']
          ami_id = stemcell_properties['cloud_properties']['ami']['us-east-1']

          obj = bucket.objects["last_successful_#{stemcell_S3_name}_ami_us-east-1"]

          obj.write(ami_id)
          obj.acl = :public_read
          puts "AMI name written to: #{obj.public_url :secure => false}"

          # NOTE: this URL is deprecated
          obj = bucket.objects["last_successful_#{stemcell_S3_name}_ami"]

          obj.write(ami_id)
          obj.acl = :public_read
          puts "AMI name written to: #{obj.public_url :secure => false}"
        end

        if stemcell_tgz.include?("/light-")
          obj = bucket.objects["last_successful_#{stemcell_S3_name}_light.tgz"]
          obj.write(:file => stemcell_tgz)
          obj.acl = :public_read
          puts "Lite stemcell written to: #{obj.public_url :secure => false}"
        end

        stemcell_tgz = File.dirname(stemcell_tgz) + "/" + File.basename(stemcell_tgz).gsub("light-", "")
        obj = bucket.objects["last_successful_#{stemcell_S3_name}.tgz"]
        obj.write(:file => stemcell_tgz)
        obj.acl = :public_read
        puts "Stemcell written to: #{obj.public_url :secure => false}"
      end
    end

    def stemcell_version(stemcell_path)
      Dir.mktmpdir do |dir|
        %x{tar xzf #{stemcell_path} --directory=#{dir} stemcell.MF} || raise("Failed to untar stemcell")
        stemcell_manifest = "#{dir}/stemcell.MF"
        st = Psych.load_file(stemcell_manifest)
        st["version"]
      end
    end

    def latest_aws_micro_bosh_stemcell_path
      Dir.glob("#{ENV['JENKINS_HOME']}/jobs/aws_micro_bosh_stemcell/lastSuccessful/archive/light-*.tgz").first
    end

    def latest_aws_stemcell_path
      Dir.glob("#{ENV['JENKINS_HOME']}/jobs/aws_bosh_stemcell/lastSuccessful/archive/light-*.tgz").first
    end

    def latest_openstack_micro_bosh_stemcell_path
      Dir.glob("#{ENV['JENKINS_HOME']}/workspace/openstack_micro_bosh_stemcell/micro-bosh-stemcell-openstack*.tgz").first
    end

    def latest_openstack_stemcell_path
      Dir.glob("#{ENV['JENKINS_HOME']}/workspace/openstack_bosh_stemcell/bosh-stemcell-openstack-*.tgz").first
    end

    def vpc_outfile_path
      "/mnt/deployments-aws/workspace/ci2/aws_vpc_receipt.yml"
    end

    def route53_outfile_path
      "/mnt/deployments-aws/workspace/ci2/aws_route53_receipt.yml"
    end

    def generate_openstack_micro_bosh(net_type)
      name = net_type
      vip = ENV["BOSH_OPENSTACK_VIP_DIRECTOR_IP"]
      ip = ENV["BOSH_OPENSTACK_MANUAL_IP"]
      net_id = ENV["BOSH_OPENSTACK_NET_ID"]
      auth_url = ENV["BOSH_OPENSTACK_AUTH_URL"]
      username = ENV["BOSH_OPENSTACK_USERNAME"]
      api_key = ENV["BOSH_OPENSTACK_API_KEY"]
      tenant = ENV["BOSH_OPENSTACK_TENANT"]
      region = ENV["BOSH_OPENSTACK_REGION"]
      private_key_path = ENV["BOSH_OPENSTACK_PRIVATE_KEY"]
      template_path = File.expand_path(File.join(File.dirname(__FILE__), "templates", "micro_bosh_openstack.yml.erb"))
      micro_bosh_manifest = ERB.new(File.read(template_path)).result(binding)
      File.open("micro_bosh.yml", "w+") do |f|
        f.write(micro_bosh_manifest)
      end
    end

    def generate_openstack_bat_manifest(net_type, director_uuid, st_version)
      vip = ENV["BOSH_OPENSTACK_VIP_BAT_IP"]
      net_id = ENV["BOSH_OPENSTACK_NET_ID"]
      stemcell_version = st_version
      net_cidr = ENV["BOSH_OPENSTACK_NETWORK_CIDR"]
      net_reserved = ENV["BOSH_OPENSTACK_NETWORK_RESERVED"]
      net_static = ENV["BOSH_OPENSTACK_NETWORK_STATIC"]
      net_gateway = ENV["BOSH_OPENSTACK_NETWORK_GATEWAY"]
      template_path = File.expand_path(File.join(File.dirname(__FILE__), "templates", "bat_openstack.yml.erb"))
      bat_manifest = ERB.new(File.read(template_path)).result(binding)
      File.open("bat.yml", "w+") do |f|
        f.write(bat_manifest)
      end
    end

    def bosh_config_path
      # We should keep a reference to the tempfile, otherwise,
      # when the object gets GC'd, the tempfile is deleted.
      @bosh_config_tempfile ||= Tempfile.new("bosh_config")
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
        err_msg = "Failed: '#{cmd}' from #{Dir.pwd}, with exit status #{$?.to_i}\n\n #{cmd_out}"

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
        run_bosh "task last --debug", {:last_number => 100}
        @run_bosh_failures = 0
      end
      raise
    end

  end
end

desc "Run unit and integration specs"
task :spec => ["spec:parallel_unit", "spec:integration"]
