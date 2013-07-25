require "spec_helper"

describe 'Bosh::Spec::IntegrationTest::HealthMonitor 2' do
  include IntegrationExampleGroup

  before do
    current_sandbox.start_healthmonitor

    release_filename    = File.join(TEST_RELEASE_DIR, "dev_releases", "bosh-release-0.1-dev.tgz")
    stemcell_filename   = spec_asset("valid_stemcell.tgz")
    deployment_hash = Bosh::Spec::Deployments.simple_manifest
    deployment_hash['jobs'][0]['name'] = "foobar_ng"
    deployment_hash['jobs'][0]['instances'] = 1
    deployment_hash['jobs'][0]['persistent_disk'] = 20480
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

  describe "resurrector" do
    it "does not resurrect stateful nodes by default" do
      original_cid = kill_job_agent('foobar_ng/0')
      foobar_ng_vm = wait_for_vm('foobar_ng/0')
      expect(foobar_ng_vm).to be_nil
    end

    it "resurrects stateful nodes when configured to" do
      current_sandbox.director_fix_stateful_nodes = true
      current_sandbox.reconfigure_director
      original_cid = kill_job_agent('foobar_ng/0')
      foobar_ng_vm = wait_for_vm('foobar_ng/0')
      expect(foobar_ng_vm[:cid]).to_not eq original_cid
    end
  end
end