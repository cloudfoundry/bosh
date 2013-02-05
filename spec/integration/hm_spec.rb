require "spec_helper"

describe Bosh::Spec::IntegrationTest::HealthMonitor do

  def deploy
    assets_dir          = File.dirname(spec_asset("foo"))
    release_filename    = spec_asset("test_release/dev_releases/bosh-release-0.1-dev.tgz")
    stemcell_filename   = spec_asset("valid_stemcell.tgz")
    deployment_manifest = yaml_file("simple", Bosh::Spec::Deployments.simple_manifest)

    Dir.chdir(File.join(assets_dir, "test_release")) do
      run_bosh("create release --with-tarball", Dir.pwd)
    end

    run_bosh("target http://localhost:57523")
    run_bosh("deployment #{deployment_manifest.path}")
    run_bosh("login admin admin")
    run_bosh("upload stemcell #{stemcell_filename}")
    run_bosh("upload release #{release_filename}")

    run_bosh("deploy")
  end

  it "HM can be queried for stats" do
    deploy

    varz_json = RestClient.get("http://admin:admin@localhost:25932/varz")
    varz = Yajl::Parser.parse(varz_json)

    varz["deployments_count"].should == 1
    varz["agents_count"].should == 3
  end

end
