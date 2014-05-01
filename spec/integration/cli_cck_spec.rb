require 'spec_helper'

describe 'cli: cloudcheck', type: :integration do
  with_reset_sandbox_before_each

  before do
    target_and_login

    runner = bosh_runner_in_work_dir(TEST_RELEASE_DIR)
    runner.run('reset release')
    runner.run('create release --force')
    runner.run('upload release')

    runner.run("upload stemcell #{spec_asset('valid_stemcell.tgz')}")

    deployment_manifest = yaml_file('simple', Bosh::Spec::Deployments.simple_manifest)
    runner.run("deployment #{deployment_manifest.path}")

    runner.run('deploy')

    expect(runner.run('cloudcheck --report')).to match(regexp('No problems found'))
  end

  it 'provides resolution options for unresponsive agents' do
    current_sandbox.cpi.kill_agents

    cloudcheck_response = bosh_run_cck_ignore_errors(3)
    expect(cloudcheck_response).to_not match(regexp('No problems found'))
    expect(cloudcheck_response).to match(regexp('3 unresponsive'))
    expect(cloudcheck_response).to match(regexp('1. Ignore problem
  2. Reboot VM
  3. Recreate VM using last known apply spec
  4. Delete VM reference (DANGEROUS!)'))
  end

  it 'provides resolution options for missing VMs' do
    current_sandbox.cpi.delete_vm(current_sandbox.cpi.vm_cids.first)

   cloudcheck_response = bosh_run_cck_ignore_errors(1)
   expect(cloudcheck_response).to_not match(regexp('No problems found'))
   expect(cloudcheck_response).to match(regexp('1 missing'))
   expect(cloudcheck_response).to match(regexp('1. Ignore problem
  2. Recreate VM using last known apply spec
  3. Delete VM reference (DANGEROUS!)') )
  end

  def bosh_run_cck_ignore_errors(num_errors)
    resolution_selections = "1\n"*num_errors + "yes"
    output = `echo "#{resolution_selections}" | bosh -c #{BOSH_CONFIG} cloudcheck`
    if $?.exitstatus != 0
      puts output
    end
    output
  end
end
