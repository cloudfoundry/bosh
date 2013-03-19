require "spec_helper"
require "bosh_agent/version"
require 'resolv'

describe "AWS" do
  STEMCELL_VERSION = Bosh::Agent::VERSION

  describe "microBOSH" do

    describe "deploying" do
      before do
        Dir.chdir(spec_tmp_path) do
          run_bosh "aws create '#{aws_configuration_template_path}'"
          run_bosh "aws bootstrap micro"
        end
      end

      it "should successfully deploy a CF release", cf: true do
        Dir.chdir(spec_tmp_path) do
          run "#{binstubs_path}/vmc bootstrap aws"
        end
      end
    end
  end
end
