require "spec_helper"

describe Bosh::Spec::IntegrationTest::HealthMonitor do
  include IntegrationExampleGroup

  before do
    current_sandbox.start_healthmonitor

    release_filename    = File.join(TEST_RELEASE_DIR, "dev_releases", "bosh-release-0.1-dev.tgz")
    stemcell_filename   = spec_asset("valid_stemcell.tgz")
    deployment_hash = Bosh::Spec::Deployments.simple_manifest
    deployment_hash['jobs'][0]['instances'] = 1
    deployment_manifest = yaml_file('simple', deployment_hash)

    Dir.chdir(TEST_RELEASE_DIR) do
      run_bosh("create release --with-tarball", Dir.pwd)
    end

    run_bosh("target http://localhost:#{current_sandbox.director_port}")
    run_bosh("deployment #{deployment_manifest.path}")
    run_bosh("login admin admin")
    run_bosh("upload stemcell #{stemcell_filename}")
    run_bosh("upload release #{release_filename}")

    run_bosh("deploy")
  end

  it "HM can be queried for stats" do
    varz_json = RestClient.get("http://admin:admin@localhost:#{current_sandbox.hm_port}/varz")
    varz = Yajl::Parser.parse(varz_json)

    varz["deployments_count"].should == 1
    varz["agents_count"].should_not == 0
  end

  describe "resurrector" do
    it "resurrects stateless nodes" do
      original_cid = kill_job_agent('foobar/0')
      foobar_vm = wait_for_vm('foobar/0')
      expect(foobar_vm[:cid]).to_not eq original_cid
    end

    it "does not resurrect stateless nodes when paused" do
      run_bosh("vm resurrection foobar 0 off")
      original_cid = kill_job_agent('foobar/0')
      foobar_vm = wait_for_vm('foobar/0')
      expect(foobar_vm).to be_nil
    end
  end
end
