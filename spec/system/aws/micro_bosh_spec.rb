require "spec_helper"
require "bosh_agent/version"
require 'resolv'

describe "AWS" do
  STEMCELL_VERSION = Bosh::Agent::VERSION

  describe "microBOSH" do
    describe "acceptance tests:" do
      before do
        Dir.chdir(spec_tmp_path) do
          run_bosh "aws create '#{aws_configuration_template_path}'"
          run_bosh "aws bootstrap micro"
        end
      end

      it "should pass BATs" do
        run_bosh "upload stemcell #{latest_stemcell_path}", debug_on_fail: true

        FileUtils.mkdir_p bat_deployment_path

        Dir.chdir(bat_deployment_path) do
          st_version = stemcell_version(latest_stemcell_path)
          run_bosh "aws generate bat_manifest '#{vpc_outfile_path}' '#{route53_outfile_path}' '#{st_version}'"
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
    end

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
