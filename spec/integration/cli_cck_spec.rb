require 'spec_helper'
require 'cloud/dummy'

describe 'cli: cloudcheck' do
  include IntegrationExampleGroup

  let!(:dummy_cloud) { Bosh::Clouds::Dummy.new('dir' => current_sandbox.cloud_storage_dir) }

  before do
    target_and_login

    run_bosh('reset release', work_dir: TEST_RELEASE_DIR)
    run_bosh('create release --force', work_dir: TEST_RELEASE_DIR)
    run_bosh('upload release', work_dir: TEST_RELEASE_DIR)

    run_bosh("upload stemcell #{spec_asset('valid_stemcell.tgz')}")

    deployment_manifest = yaml_file('simple', Bosh::Spec::Deployments.simple_manifest)
    run_bosh("deployment #{deployment_manifest.path}")

    run_bosh('deploy')

    expect(run_bosh('cloudcheck --report')).to match(regexp('No problems found'))
  end

  it 'provides resolution options for unresponsive agents' do
    get_cids.each do |cid|
      begin
        Process.kill('INT', cid.to_i)
      rescue Errno::ESRCH
        # noop
      end
    end

    cloudcheck_response = run_bosh_cck_ignore_errors(3)
    expect(cloudcheck_response).to_not match(regexp('No problems found'))
    expect(cloudcheck_response).to match(regexp('3 unresponsive'))
    expect(cloudcheck_response).to match(regexp('1. Ignore problem
  2. Reboot VM
  3. Recreate VM using last known apply spec
  4. Delete VM reference (DANGEROUS!)'))
  end

  it 'provides resolution options for missing VMs' do
    dummy_cloud.delete_vm(get_cids.first)

   cloudcheck_response = run_bosh_cck_ignore_errors(1)
   expect(cloudcheck_response).to_not match(regexp('No problems found'))
   expect(cloudcheck_response).to match(regexp('1 missing'))
   expect(cloudcheck_response).to match(regexp('1. Ignore problem
  2. Recreate VM using last known apply spec
  3. Delete VM reference (DANGEROUS!)') )
  end

  def run_bosh_cck_ignore_errors(num_errors)
    resolution_selections = "1\n"*num_errors + "yes"
    output = `echo "#{resolution_selections}" | bosh -c #{BOSH_CONFIG} cloudcheck`
    if $?.exitstatus != 0
      puts output
    end
    output
  end

  def get_cids
    Dir[File.join(current_sandbox.agent_tmp_path, 'running_vms', '*')].map { |f| File.basename(f) }
  end
end
