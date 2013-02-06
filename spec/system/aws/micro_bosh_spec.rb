require File.expand_path(File.dirname(__FILE__) + "/../../spec_helper")

describe "AWS" do
  STEMCELL_AMI = "ami-30d94f59"
  it "should be able to launch a MicroBosh from existing stemcell" do
    Dir.chdir(File.join(ASSETS_DIR, "aws", "deployments")) do
      FileUtils.rm_f("aws_registry.log")
      FileUtils.rm_f("bosh-deployments.yml")
      FileUtils.rm_f("micro/bosh_micro_deploy.log")

      puts "MICRO_BOSH.YML:"
      puts ERB.new(File.read("micro/micro_bosh.yml")).result

      puts ""
      run_bosh "micro deployment micro"
      run_bosh "micro deploy #{STEMCELL_AMI}"
    end
  end

  def run(cmd)
    system(cmd) || raise("Couldn't run '#{cmd}' from #{Dir.pwd}, failed with exit status #{$?}")
  end

  def run_bosh(cmd)
    run "bundle exec bosh -n --config #{bosh_config_path} #{cmd}"
  end
end
