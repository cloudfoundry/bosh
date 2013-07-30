require 'bosh/dev/bat'
require 'bosh/dev/bat_helper'

module Bosh::Dev::Bat
  class AwsRunner
    include Rake::FileUtilsExt

    def initialize
      @bat_helper = Bosh::Dev::BatHelper.new('aws')
      @mnt = ENV.fetch('FAKE_MNT', '/mnt')
    end

    def deploy_micro
      get_deployments_aws

      FileUtils.rm_rf(bat_helper.artifacts_dir)
      FileUtils.mkdir_p(bat_helper.micro_bosh_deployment_dir)

      Dir.chdir(bat_helper.artifacts_dir) do
        Dir.chdir(bat_helper.micro_bosh_deployment_dir) do
          run_bosh "aws generate micro_bosh '#{vpc_outfile_path}' '#{route53_outfile_path}'"
        end
        run_bosh "micro deployment #{bat_helper.micro_bosh_deployment_name}"
        run_bosh "micro deploy #{bat_helper.micro_bosh_stemcell_path}"
        run_bosh 'login admin admin'

        run_bosh "upload stemcell #{bat_helper.bosh_stemcell_path}", debug_on_fail: true

        st_version = stemcell_version(bat_helper.bosh_stemcell_path)
        run_bosh "aws generate bat '#{vpc_outfile_path}' '#{route53_outfile_path}' '#{st_version}'"
      end
    end

    def run_bats
      director = "micro.#{ENV['BOSH_VPC_SUBDOMAIN']}.cf-app.com"

      ENV['BAT_DIRECTOR'] = director
      ENV['BAT_STEMCELL'] = bat_helper.bosh_stemcell_path
      ENV['BAT_DEPLOYMENT_SPEC'] = File.join(bat_helper.artifacts_dir, 'bat.yml')
      ENV['BAT_VCAP_PASSWORD'] = 'c1oudc0w'
      ENV['BAT_FAST'] = 'true'
      ENV['BAT_DNS_HOST'] = Resolv.getaddress(director)

      Rake::Task['bat'].invoke
    end

    def teardown_micro
      if Dir.exists?(bat_helper.artifacts_dir)
        Dir.chdir(bat_helper.artifacts_dir) do
          run_bosh 'delete deployment bat', :ignore_failures => true
          run_bosh 'micro delete', :ignore_failures => true
        end
        FileUtils.rm_rf(bat_helper.artifacts_dir)
      end
    end

    private

    attr_reader :bat_helper, :mnt

    def vpc_outfile_path
      File.join(mnt, 'deployments', ENV.to_hash.fetch('BOSH_VPC_SUBDOMAIN'), 'aws_vpc_receipt.yml')
    end

    def route53_outfile_path
      File.join(mnt, 'deployments', ENV.to_hash.fetch('BOSH_VPC_SUBDOMAIN'), 'aws_route53_receipt.yml')
    end

    def get_deployments_aws
      Dir.chdir(mnt) do
        if Dir.exists?('deployments')
          Dir.chdir('deployments') do
            run('git pull')
          end
        else
          run("git clone #{ENV.to_hash.fetch('BOSH_JENKINS_DEPLOYMENTS_REPO')} deployments")
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
        pwd = Dir.pwd rescue 'a deleted directory'
        err_msg = "Failed: '#{cmd}' from #{pwd}, with exit status #{$?.to_i}\n\n #{cmd_out}"

        if options[:ignore_failures]
          puts("#{err_msg}, continuing anyway")
        else
          raise(err_msg)
        end
      end
      cmd_out
    end
  end
end
