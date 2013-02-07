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

  def deployments_path
    File.expand_path("../../../tmp/spec/deployments", __FILE__)
  end

  def micro_deployment_path
    File.join(deployments_path, "micro")
  end

  def aws_configuration_template_path
    "#{ASSETS_DIR}/aws/aws_configuration_template.yml.erb"
  end

  def run(cmd, options = {})
    if !system(cmd)
      err_msg = "Couldn't run '#{cmd}' from #{Dir.pwd}, failed with exit status #{$?}"

      if options[:ignore_failures]
        puts("#{err_msg}, continuing anyway")
        return false
      else
        raise(err_msg)
      end
    end
    true
  end

  def run_bosh(cmd, options = {})
    run "bundle exec bosh -n --config '#{bosh_config_path}' #{cmd}", options
  end


  def self.included(base)
    base.before(:each) do
      ENV['BOSH_KEY_PAIR_NAME'] = "bosh_ci"
      ENV['BOSH_KEY_PATH'] = "/tmp/id_bosh_ci"

      system "rm -f #{ASSETS_DIR}/aws/create-vpc-output-*.yml"
      FileUtils.rm_rf deployments_path
      FileUtils.mkdir_p micro_deployment_path

      run_bosh "aws create vpc '#{aws_configuration_template_path}'"

      puts "AWS RESOURCES CREATED SUCCESSFULLY!"
    end

    base.after(:each) do
      puts "Using VPC output: #{vpc_outfile_path}"
      run_bosh "aws terminate_all ec2 '#{vpc_outfile_path}'", :ignore_failures => true
      run_bosh "aws delete_all volumes '#{vpc_outfile_path}'", :ignore_failures => true
      run_bosh "aws delete vpc '#{vpc_outfile_path}'"
      puts "CLEANUP SUCCESSFUL"
    end
  end
end