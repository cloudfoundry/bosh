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
        Dir.chdir deployments_path do
          existing_stemcells = run_bosh "stemcells", :ignore_failures => true
          unless existing_stemcells.include?("bosh-stemcell")
            run_bosh "upload stemcell #{latest_stemcell_path}", debug_on_fail: true
          end
        end

        Dir.chdir cf_release_path do
          run_bosh "create release"
          upload_result = run_bosh "upload release", :ignore_failures => true
          upload_result.should match(/Release has been created|This release version has already been uploaded/)
        end

        Dir.chdir deployments_path do
          run "#{deployments_aws_path}/generators/generator.rb '#{vpc_outfile_path}' '#{rds_outfile_path}'"
          FileUtils.cp("#{deployments_path}/cf-aws-stub.yml", "cf-aws.yml")

          # why are these necessary?
          run_bosh "target micro.#{ENV["BOSH_VPC_SUBDOMAIN"]}.cf-app.com"
          run_bosh "login admin admin"
          run_bosh "status"

          run_bosh "deployment cf-aws.yml"
          run_bosh "diff #{deployments_aws_path}/templates/cf-min-aws-vpc.yml.erb"
          run_bosh "deploy", debug_on_fail: true
        end
      end
    end

    def cf_release_path
      @cf_release_path ||= begin
        path = File.join(BOSH_TMP_DIR, "spec", "cf-release")
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
        run "rm -rf #{path}"
        run "git clone --recursive git@github.com:cloudfoundry/deployments-aws.git '#{path}'"
        path
      end
    end
  end
end
