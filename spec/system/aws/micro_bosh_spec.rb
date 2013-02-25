require "spec_helper"
require "bosh_agent/version"
require 'resolv'

describe "AWS" do
  STEMCELL_VERSION = Bosh::Agent::VERSION

  # we always need a microbosh to deploy whatever the next step is
  before do
    unless ENV["NO_PROVISION"]
      Dir.chdir(micro_deployment_path) do
        run_bosh "aws generate micro_bosh '#{vpc_outfile_path}'"
      end
    end

    Dir.chdir(deployments_path) do
      unless ENV["NO_PROVISION"]
        puts "MICRO_BOSH.YML:"
        puts ERB.new(File.read("micro/micro_bosh.yml")).result

        puts "Deploying latest microbosh stemcell from #{latest_micro_bosh_stemcell}"
        run_bosh "micro deployment micro"
        run_bosh "micro deploy #{latest_micro_bosh_stemcell}"
      end
      run_bosh "target micro.#{ENV["BOSH_VPC_SUBDOMAIN"]}.cf-app.com"
      run_bosh "login admin admin"
    end
  end

  it "should be able to launch a MicroBosh from existing stemcell" do
    run_bosh "status"
    puts "DEPLOYMENT FINISHED!"

    puts "Running BAT Tests"
    unless ENV["NO_PROVISION"]
      puts "Uploading latest stemcell from #{latest_stemcell_path}"
      run_bosh "upload stemcell #{latest_stemcell_path}"
    end


    Dir.chdir(bat_deployment_path) do
      st_version = stemcell_version(latest_stemcell_path)
      run_bosh "aws generate bat_manifest '#{vpc_outfile_path}' '#{st_version}'"
    end

    director = "micro.#{ENV["BOSH_VPC_SUBDOMAIN"]}.cf-app.com"
    bat_env = {
        'BAT_DIRECTOR' => director,
        'BAT_STEMCELL' => latest_stemcell_path,
        'BAT_DEPLOYMENT_SPEC' => "#{bat_deployment_path}/bat.yml",
        'BAT_VCAP_PASSWORD' => 'c1oudc0w',
        'BAT_FAST' => 'true',
        'BAT_SKIP_SSH' => 'true',
        'BAT_DEBUG' => 'verbose',
        'BAT_DNS_HOST' => Resolv.getaddress(director),
    }
    system(bat_env, "rake bat").should be_true
  end

  it "should be able to deploy CF-release on top of microbosh", cf: true do
    Dir.chdir deployments_path do
      existing_stemcells = run_bosh "stemcells", :ignore_failures => true
      if existing_stemcells.include?("bosh-stemcell")
        puts "Deleting existing stemcell bosh-stemcell"
        run_bosh "delete stemcell bosh-stemcell #{STEMCELL_VERSION}"
      end

      puts "Using existing stemcell on this machine: #{latest_stemcell_path}"
      run_bosh "upload stemcell #{latest_stemcell_path}"
    end

    Dir.chdir cf_release_path do
      existing_releases = run_bosh "releases", :ignore_failures => true
      if existing_releases.include?("bosh-release")
        puts "Deleting existing bosh-release"
        run_bosh "delete release bosh-release"
      end
      run_bosh "create release"
      run_bosh "upload release"
    end

    Dir.chdir deployments_path do
      run "#{deployments_aws_path}/generators/generator.rb '#{vpc_outfile_path}' '#{aws_configuration_template_path}'"
      FileUtils.cp("#{deployments_aws_path}/cf-aws-stub.yml", "cf-aws.yml")
      run_bosh "deployment cf-aws.yml"
      run_bosh "diff #{deployments_aws_path}/templates/cf-min-aws-vpc.yml.erb"
      run_bosh "deploy"
    end

    # We should also run some tests and make assertions against this deployment of CF (rather than just having
    # "not blowing up" as passing criteria for the test)
  end

  def cf_release_path
    @cf_release_path ||= begin
      path = File.join(BOSH_TMP_DIR, "spec", "cf-release")
      puts "Cloning CF-RELEASE"
      if !File.exist? path
        run "git clone git://github.com/cloudfoundry/cf-release.git '#{path}'"
      end
      run "cd '#{path}' && git checkout master && git reset --hard origin/master"
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
