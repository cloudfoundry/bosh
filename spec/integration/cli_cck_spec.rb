require 'spec_helper'

describe 'cli: cloudcheck', type: :integration do
  with_reset_sandbox_before_each

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
    current_sandbox.cpi.kill_agents

    cloudcheck_response = run_bosh_cck_ignore_errors(3)
    expect(cloudcheck_response).to_not match(regexp('No problems found'))
    expect(cloudcheck_response).to match(regexp('3 unresponsive'))
    expect(cloudcheck_response).to match(regexp('1. Ignore problem
  2. Reboot VM
  3. Recreate VM using last known apply spec
  4. Delete VM reference (DANGEROUS!)'))
  end

  it 'provides resolution options for missing VMs' do
    current_sandbox.cpi.delete_vm(current_sandbox.cpi.vm_cids.first)

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
end
