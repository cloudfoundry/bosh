require "rspec"
require "rspec/core/rake_task"
require 'tempfile'

namespace :spec do

  desc "Run BOSH integration tests against a local sandbox"
  RSpec::Core::RakeTask.new(:integration) do |t|
    t.pattern = "spec/integration/**/*_spec.rb"
    t.rspec_opts = %w(--format documentation --color)
  end

  desc "Run unit and functional tests for each BOSH component gem"
  task :unit do
    builds = Dir['*'].select {|f| File.directory?(f) && File.exists?("#{f}/spec")}
    builds -= ['bat']

    builds.each do |build|
      puts "-----#{build}-----"
      system("cd #{build} && rspec spec") || raise("#{build} failed to build unit tests")
    end
  end

  namespace :external do
    desc "AWS CPI can exercise the VM lifecycle"
    RSpec::Core::RakeTask.new(:vm_lifecycle) do |t|
      t.pattern = "spec/external/cpi_spec.rb"
      t.rspec_opts = %w(--format documentation --color)
    end

    desc "AWS bootstrap CLI can provision and destroy resources"
    RSpec::Core::RakeTask.new(:aws_bootstrap) do |t|
      t.pattern = "spec/external/aws_bootstrap_spec.rb"
      t.rspec_opts = %w(--format documentation --color)
    end
  end

  namespace :system do
    namespace :aws do
      desc "Run AWS MicroBOSH deployment suite"
      task :micro do
        begin
          Rake::Task['spec:system:aws:publish_gems'].invoke
          Rake::Task['stemcells:aws:publish_to_s3'].invoke(latest_stemcell_path, 'bosh-jenkins-artifacts')
          Rake::Task['stemcells:aws:publish_to_s3'].invoke(latest_micro_bosh_stemcell_path, 'bosh-jenkins-artifacts')
        ensure
          Rake::Task['spec:system:aws:teardown_microbosh'].invoke
        end
      end

      desc "Run AWS CF deployment suite"
      RSpec::Core::RakeTask.new(:cf) do |t|
        t.pattern = "spec/system/aws/**/*_spec.rb"
        t.rspec_opts = %w(--format documentation --color --tag cf)
      end

      task :deploy_micro do
        mkdir_p("/tmp/deployments/micro")
        chdir("/tmp/deployments") do
          chdir("micro") do
            run_bosh "aws generate micro_bosh '#{vpc_outfile_path}' '#{route53_outfile_path}'"
          end
          run_bosh "micro deployment micro"
          run_bosh "micro deploy #{latest_micro_bosh_stemcell_path}"
          run_bosh "login admin admin"

          run_bosh "upload stemcell #{latest_stemcell_path}", debug_on_fail: true

          st_version = stemcell_version(latest_stemcell_path)
          run_bosh "aws generate bat_manifest '#{vpc_outfile_path}' '#{route53_outfile_path}' '#{st_version}'"
        end
      end

      task :teardown_microbosh do
        chdir("/tmp/deployments") do
          run_bosh "delete deployment bat"
          run_bosh "micro delete"
        end
        rm_rf("/tmp/deployments")
      end

      task :bat => :deploy_micro do
        director = "micro.#{ENV["BOSH_VPC_SUBDOMAIN"]}.cf-app.com"
        ENV['BAT_DIRECTOR'] = director
        ENV['BAT_STEMCELL'] = latest_stemcell_path
        ENV['BAT_DEPLOYMENT_SPEC'] = "/tmp/deployments/bat.yml"
        ENV['BAT_VCAP_PASSWORD'] = 'c1oudc0w'
        ENV['BAT_FAST'] = 'true'
        #ENV['BAT_SKIP_SSH'] = 'true'
        #ENV['BAT_DEBUG'] = 'verbose'
        ENV['BAT_DNS_HOST'] = Resolv.getaddress(director)
        #Rake::Task['bat'].invoke
      end

      task :publish_gems => "spec:system:aws:bat" do
        build_number = ENV['BUILD_NUMBER']
        file_contents = File.read("#{ENV['WORKSPACE']}/BOSH_VERSION")
        file_contents.gsub!(/^([\d\.]+)\.pre\.\d+$/, "\\1.pre.#{build_number}")
        File.open("#{ENV['WORKSPACE']}/BOSH_VERSION", 'w') { |f| f.write file_contents }
        Rake::Task["all:pre_stage_latest"].invoke
        run("cd #{ENV['WORKSPACE']}/pkg && gem generate_index .")
        run("cd #{ENV['WORKSPACE']}/pkg && s3cmd sync . s3://bosh-jenkins-gems")
      end

      def stemcell_version(stemcell_path)
        Dir.mktmpdir do |dir|
          %x{tar xzf #{stemcell_path} --directory=#{dir} stemcell.MF} || raise("Failed to untar stemcell")
          stemcell_manifest = "#{dir}/stemcell.MF"
          st = YAML.load_file(stemcell_manifest)
          st["version"]
        end
      end

      def latest_micro_bosh_stemcell_path
        Dir.glob("#{ENV['JENKINS_HOME']}/jobs/aws_micro_bosh_stemcell/lastSuccessful/archive/light-*.tgz").first
      end

      def latest_stemcell_path
        Dir.glob("#{ENV['JENKINS_HOME']}/jobs/aws_bosh_stemcell/lastSuccessful/archive/light-*.tgz").first
      end

      def vpc_outfile_path
        "/mnt/deployments-aws/workspace/ci2/aws_vpc_receipt.yml"
      end

      def route53_outfile_path
        "/mnt/deployments-aws/workspace/ci2/aws_route53_receipt.yml"
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

    desc "Run AWS system-wide suite"
    RSpec::Core::RakeTask.new(:aws) do |t|
      t.pattern = "spec/system/aws/**/*_spec.rb"
      t.rspec_opts = %w(--format documentation --color)
    end
  end
end

desc "Run unit and integration specs"
task :spec => ["spec:unit", "spec:integration"]
