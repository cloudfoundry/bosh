require File.expand_path(File.dirname(__FILE__) + "/../../spec_helper")

describe "AWS" do
  STEMCELL_AMI = "ami-42cf592b"
  CF_STEMCELL = "bosh-stemcell-aws-0.7.0.tgz"

  # we always need a microbosh to deploy whatever the next step is
  before do
    Dir.chdir(micro_deployment_path) do
      run_bosh "aws generate micro_bosh '#{aws_configuration_template_path}' '#{vpc_outfile_path}'"
    end

    Dir.chdir(deployments_path) do
      puts "MICRO_BOSH.YML:"
      puts ERB.new(File.read("micro/micro_bosh.yml")).result

      puts ""
      run_bosh "micro deployment micro"
      run_bosh "micro deploy #{STEMCELL_AMI}"
      run_bosh "target micro.#{ENV["VPC_SUBDOMAIN"]}.cf-app.com"
    end
  end

  it "should be able to launch a MicroBosh from existing stemcell" do
    run_bosh "status"

    puts "DEPLOYMENT FINISHED!"
    puts "Ideally we'd run BAT tests now and mark this successful"

    #puts "Press enter to continue and cleanup your resources"
    #gets
  end

  xit "should be able to deploy CF-release on top of microbosh" do
    Dir.chdir deployments_path do
      run_bosh "download public stemcell #{CF_STEMCELL}"
      run_bosh "upload stemcell #{CF_STEMCELL}"
    end

    Dir.chdir cf_release_path do
      run_bosh "create release"
      run_bosh "upload release #{cf_dev_release_yaml_path}"
    end

    Dir.chdir deployments_path do
      run_bosh "deployment cf-aws-stub.yml"
      run_bosh "diff ../templates/cf-min-aws-vpc.erb"
    end
  end

  def cf_dev_release_yaml_path
    `ls #{cf_release_path}/dev_releases/cf*.yml`.strip
  end

  def cf_release_path
    @cf_release_path ||= begin
      path = File.join(BOSH_TMP_DIR, "spec", "cf-release")
      puts "Cloning CF-RELEASE"
      run "rm -rf #{path}"
      run "git clone git://github.com/cloudfoundry/cf-release.git '#{path}'"
      run "cd #{path} && ./update"
      path
    end
  end

  def deployments_aws_path
    @deployments_aws_path ||= begin
      path = File.join(BOSH_TMP_DIR, "spec", "deployments-aws")
      puts "Cloning DEPLOYMENTS-AWS"
      run "rm -rf #{path}"
      run "git clone --recursive git@github.com:cloudfoundry/deployments-aws.git '#{path}'"
      path
    end
  end
end
