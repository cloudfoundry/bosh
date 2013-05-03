require 'spec_helper'

describe 'Bosh::Spec::IntegrationTest::CliUsage cloudcheck' do
  include IntegrationExampleGroup

  describe 'cloudcheck' do
    require 'cloud/dummy'
    let!(:dummy_cloud) do
      Bosh::Clouds::Dummy.new('dir' => current_sandbox.cloud_storage_dir)
    end

    before do
      run_bosh("target http://localhost:#{current_sandbox.director_port}")
      run_bosh('login admin admin')

      run_bosh('reset release', TEST_RELEASE_DIR)
      run_bosh('create release --force', TEST_RELEASE_DIR)
      run_bosh('upload release', TEST_RELEASE_DIR)

      run_bosh("upload stemcell #{spec_asset('valid_stemcell.tgz')}")

      deployment_manifest = yaml_file('simple', Bosh::Spec::Deployments.simple_manifest)
      run_bosh("deployment #{deployment_manifest.path}")

      run_bosh('deploy')

      run_bosh('cloudcheck --report').should =~ regexp('No problems found')
    end

    it 'supports resolutions for different kinds of problems' do
      #provides resolution options for unresponsive agents
      current_sandbox.stop_nats
      cloudcheck_response = run_bosh_cck_ignore_errors(3)
      cloudcheck_response.should_not =~ regexp('No problems found')
      cloudcheck_response.should =~ regexp('3 unresponsive')
      cloudcheck_response.should =~ regexp('1. Ignore problem
  2. Reboot VM
  3. Recreate VM using last known apply spec
  4. Delete VM reference (DANGEROUS!)')

      current_sandbox.start_nats

      # provides resolution options for missing VMs
      cid = File.basename(Dir[File.join(current_sandbox.agent_tmp_path, 'running_vms', '*')].first)
      dummy_cloud.delete_vm(cid)

      cloudcheck_response = run_bosh_cck_ignore_errors(1)
      cloudcheck_response.should_not =~ regexp('No problems found')
      cloudcheck_response.should =~ regexp('1 missing')
      cloudcheck_response.should =~ regexp('1. Ignore problem
  2. Recreate VM using last known apply spec
  3. Delete VM reference (DANGEROUS!)')

    end
  end
end
