module AwsSystemExampleGroup
  def vpc_outfile_path
    `ls #{ASSETS_DIR}/aws/create-vpc-output-*.yml`.strip
  end

  def vpc_outfile
    YAML.load_file vpc_outfile_path
  end

  def microbosh_ip
    vpc_outfile["elastic_ips"]["bosh"]["ips"][0]
  end

  def bosh_config_path
    @bosh_config_path ||= Tempfile.new("bosh_config").path
  end

  def latest_micro_bosh_stemcell_path
    `readlink -nf #{ENV['WORKSPACE']}/../../aws_micro_bosh_stemcell/lastSuccessful/archive/*.tgz`
  end

  def latest_stemcell_path
    `readlink -nf #{ENV['WORKSPACE']}/../../aws_bosh_stemcell/lastSuccessful/archive/*.tgz`
  end

  def deployments_path
    File.join(BOSH_TMP_DIR, "spec", "deployments")
  end

  def micro_deployment_path
    File.join(deployments_path, "micro")
  end

  def bat_deployment_path
    File.join(deployments_path, "bat")
  end

  def aws_configuration_template_path
    "#{ASSETS_DIR}/aws/aws_configuration_template.yml.erb"
  end

  def run(cmd, options = {})
    r = true
    Bundler.with_clean_env do
      r=`#{cmd}`
      unless $?.success?
        err_msg = "Couldn't run '#{cmd}' from #{Dir.pwd}, failed with exit status #{$?.to_i}\n\n #{r}"

        if options[:ignore_failures]
          puts("#{err_msg}, continuing anyway")
          r = false unless options[:return_output]
        else
          raise(err_msg)
        end

      end
    end
    r
  end

  def run_bosh(cmd, options = {})
    run "#{binstubs_path}/bosh -v -n --config '#{bosh_config_path}' #{cmd}", options
  end

  def binstubs_path
    @binstubs_path ||= begin
      path = File.join(BOSH_TMP_DIR, "spec", "bin")
      run "rm -rf '#{path}'"
      FileUtils.mkdir_p path
      Dir.chdir(BOSH_ROOT_DIR) do
        run "bundle install --binstubs='#{path}' --local"
      end
      path
    end
  end

  def self.included(base)
    base.before(:each) do
      ENV['BOSH_KEY_PAIR_NAME'] = "bosh_ci"
      ENV['BOSH_KEY_PATH'] = "/tmp/id_bosh_ci"

      FileUtils.rm_rf deployments_path
      FileUtils.mkdir_p micro_deployment_path

      if ENV["NO_PROVISION"]
        puts "Not creating AWS resources, assuming we already have them"
      else
        system "rm -f #{ASSETS_DIR}/aws/create-vpc-output-*.yml"

        run_bosh "aws create vpc '#{aws_configuration_template_path}'"

        puts "AWS RESOURCES CREATED SUCCESSFULLY!"
      end
    end

    base.after(:each) do
      if ENV["NO_CLEANUP"]
        puts "Not cleaning up AWS resources"
      else
        puts "Using VPC output: #{vpc_outfile_path}"
        run_bosh "aws terminate_all ec2 '#{vpc_outfile_path}'", :ignore_failures => true
        run_bosh "aws delete_all volumes '#{vpc_outfile_path}'", :ignore_failures => true
        run_bosh "aws delete vpc '#{vpc_outfile_path}'"
        puts "CLEANUP SUCCESSFUL"
      end
    end
  end
end
