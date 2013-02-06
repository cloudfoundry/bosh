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

  def self.included(base)
    base.before(:each) do
      ENV['BOSH_KEY_PAIR_NAME'] = "bosh_ci"
      ENV['BOSH_KEY_PATH'] = "/tmp/id_bosh_ci"

      system "rm -f #{ASSETS_DIR}/aws/create-vpc-output-*.yml"
      raise "Failed to create VPC resources" unless system "bundle exec bosh aws create vpc #{ASSETS_DIR}/aws/aws_configuration_template.yml.erb"

      puts "AWS RESOURCES CREATED SUCCESSFULLY!"
      p vpc_outfile
      ENV['MICROBOSH_IP'] = vpc_outfile["elastic_ips"]["bosh"]["ips"][0]
      ENV['BOSH_SUBNET_ID'] = vpc_outfile["vpc"]["subnets"]["bosh"]
    end

    base.after(:each) do
      puts "Using VPC output: #{vpc_outfile_path}"
      puts "Failed to terminate EC2 instances" unless system "bundle exec bosh -n aws terminate_all ec2 '#{vpc_outfile_path}'"
      puts "Failed to create VPC resources" unless system "bundle exec bosh -n aws delete vpc '#{vpc_outfile_path}'"
      puts "CLEANUP SUCCESSFUL"
    end
  end
end