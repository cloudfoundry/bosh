module AwsSystemExampleGroup
  def bosh_deploy_path
    "/tmp/bosh_deploy"
  end

  def self.included(base)
    base.before(:each) do
      system "rm -f #{ASSETS_DIR}/aws/create-vpc-output-*.yml"
      raise "Failed to create VPC resources" unless system "bundle exec bosh aws create vpc #{ASSETS_DIR}/aws/aws_configuration_template.yml.erb"

      puts "AWS RESOURCES CREATED SUCCESSFULLY!"

      FileUtils.rm_rf(bosh_deploy_path)
      FileUtils.mkdir_p(bosh_deploy_path)
      raise "Cannot clone deployments-aws repo to #{bosh_deploy_path}" unless system("git", "clone", "git@github.com:cloudfoundry/deployments-aws.git", bosh_deploy_path)
    end

    base.after(:each) do
      vpc_outfile = `ls #{ASSETS_DIR}/aws/create-vpc-output-*.yml`.strip
      puts "Using VPC output: #{vpc_outfile}"
      puts File.read(vpc_outfile)
      raise "Failed to create VPC resources" unless system "bundle exec bosh aws delete vpc '#{vpc_outfile}'"
      puts "CLEANUP SUCCESSFUL"
    end
  end
end