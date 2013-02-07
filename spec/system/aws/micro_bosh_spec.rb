require File.expand_path(File.dirname(__FILE__) + "/../../spec_helper")

describe "AWS" do
  STEMCELL_AMI = "ami-42cf592b"
  it "should be able to launch a MicroBosh from existing stemcell" do
    Dir.chdir(micro_deployment_path) do
      run_bosh "aws generate micro_bosh '#{aws_configuration_template_path}' '#{vpc_outfile_path}'"
    end

    Dir.chdir(deployments_path) do
      puts "MICRO_BOSH.YML:"
      puts ERB.new(File.read("micro/micro_bosh.yml")).result

      puts ""
      run_bosh "micro deployment micro"
      run_bosh "micro deploy #{STEMCELL_AMI}"
      #
      #puts "DEPLOYMENT FINISHED!"
      #puts "Press enter to continue and cleanup your resources"
      #gets
    end
  end
end
