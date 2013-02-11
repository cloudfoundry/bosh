require File.expand_path(File.dirname(__FILE__) + "/../../spec_helper")

describe "AWS" do
  STEMCELL_AMI = "ami-42cf592b"
  STEMCELL_VERSION = "1.5.0"
  CF_STEMCELL = "bosh-stemcell-aws-#{STEMCELL_VERSION}.pre.tgz"

  # we always need a microbosh to deploy whatever the next step is
  before do
    unless ENV["NO_PROVISION"]
      Dir.chdir(micro_deployment_path) do
        run_bosh "aws generate micro_bosh '#{aws_configuration_template_path}' '#{vpc_outfile_path}'"
      end
    end

    Dir.chdir(deployments_path) do
      unless ENV["NO_PROVISION"]
        puts "MICRO_BOSH.YML:"
        puts ERB.new(File.read("micro/micro_bosh.yml")).result

        puts ""
        run_bosh "micro deployment micro"
        run_bosh "micro deploy #{STEMCELL_AMI}"
      end
      run_bosh "target micro.#{ENV["VPC_SUBDOMAIN"]}.cf-app.com"
      run_bosh "login admin admin"
    end
  end

  it "should be able to launch a MicroBosh from existing stemcell" do
    run_bosh "status"

    puts "DEPLOYMENT FINISHED!"
    puts "Ideally we'd run BAT tests now and mark this successful"

    #puts "Press enter to continue and cleanup your resources"
    #gets
  end

  it "should be able to deploy CF-release on top of microbosh", cf: true do
    Dir.chdir deployments_path do
      existing_stemcells = run_bosh "stemcells", :return_output => true, :ignore_failures => true
      if existing_stemcells.include?("bosh-release")
        puts "Deleting existing stemcell bosh-release"
        run_bosh "delete stemcell bosh-release #{STEMCELL_VERSION}"
      end
      if ENV["STEMCELL_DIR"]
        stemcell_path = "#{ENV["STEMCELL_DIR"]}/#{CF_STEMCELL}"
        puts "Using existing stemcell on this machine: #{stemcell_path}"
        run_bosh "upload stemcell #{stemcell_path}"
      else
        puts "Downloading public stemcell: #{CF_STEMCELL}"
        run_bosh "download public stemcell #{CF_STEMCELL}"
        run_bosh "upload stemcell #{CF_STEMCELL}"
      end
    end

    Dir.chdir cf_release_path do
      existing_releases = run_bosh "releases", :return_output => true, :ignore_failures => true
      if existing_releases.include?("bosh-release")
        puts "Deleting existing bosh-release"
        run_bosh "delete release bosh-release"
      end
      run_bosh "create release"
      run_bosh "upload release"
    end

    Dir.chdir deployments_path do
      run "#{deployments_aws_path}/generators/generator.rb '#{vpc_outfile_path}' '#{aws_configuration_template_path}'"
      FileUtils.cp("cf-aws-stub.yml", "cf-aws.yml")
      run_bosh "deployment cf-aws.yml"
      run_bosh "diff #{deployments_aws_path}/templates/cf-min-aws-vpc.yml.erb"
      run_bosh "deploy"
    end
  end

  def cf_release_path
    @cf_release_path ||= begin
      path = File.join(BOSH_TMP_DIR, "spec", "cf-release")
      puts "Cloning CF-RELEASE"
      if File.exist? path
        run "cd '#{path}' && git reset --hard"
      else
        run "git clone git://github.com/cloudfoundry/cf-release.git '#{path}'"
      end
      run "cd '#{path}' && ./update"
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
