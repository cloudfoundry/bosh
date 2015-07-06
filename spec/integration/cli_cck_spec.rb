require 'spec_helper'

describe 'cli: cloudcheck', type: :integration do
  with_reset_sandbox_before_each

  let(:runner) { bosh_runner_in_work_dir(ClientSandbox.test_release_dir) }

  before do
    target_and_login
    runner.run('reset release')
    runner.run('create release --force')
    runner.run('upload release')

    runner.run("upload stemcell #{spec_asset('valid_stemcell.tgz')}")

    cloud_config_manifest = yaml_file('cloud_manifest', Bosh::Spec::Deployments.simple_cloud_config)
    bosh_runner.run("update cloud-config #{cloud_config_manifest.path}")

    manifest = Bosh::Spec::Deployments.simple_manifest
    manifest['jobs'][0]['persistent_disk'] = 100
    deployment_manifest = yaml_file('deployment_manifest', manifest)

    runner.run("deployment #{deployment_manifest.path}")

    runner.run('deploy')

    expect(runner.run('cloudcheck --report')).to match(regexp('No problems found'))
  end

  it 'properly resurrects VMs with dead agents' do
    current_sandbox.cpi.kill_agents

    cloudcheck_response = bosh_run_cck_with_resolution(3)
    expect(cloudcheck_response).to_not match(regexp('No problems found'))
    expect(cloudcheck_response).to match(regexp('3 unresponsive'))
    expect(cloudcheck_response).to match(regexp('1. Skip for now
  2. Reboot VM
  3. Recreate VM
  4. Delete VM reference (forceful; may need to manually delete VM from the Cloud to avoid IP conflicts)'))

    recreate_vm = 3
    bosh_run_cck_with_resolution(3, recreate_vm)
    expect(runner.run('cloudcheck --report')).to match(regexp('No problems found'))
  end

  it 'properly delete VMs references for VMs with dead agents' do
    current_sandbox.cpi.kill_agents

    cloudcheck_response = bosh_run_cck_with_resolution(3)
    expect(cloudcheck_response).to_not match(regexp('No problems found'))
    expect(cloudcheck_response).to match(regexp('3 unresponsive'))
    expect(cloudcheck_response).to match(regexp('1. Skip for now
  2. Reboot VM
  3. Recreate VM
  4. Delete VM reference (forceful; may need to manually delete VM from the Cloud to avoid IP conflicts)'))

    delete_vm_reference = 4
    bosh_run_cck_with_resolution(3, delete_vm_reference)
    expect(runner.run('cloudcheck --report')).to match(regexp('No problems found'))
  end

  it 'provides resolution options for missing VMs' do
    current_sandbox.cpi.delete_vm(current_sandbox.cpi.vm_cids.first)

   cloudcheck_response = bosh_run_cck_with_resolution(1)
   expect(cloudcheck_response).to_not match(regexp('No problems found'))
   expect(cloudcheck_response).to match(regexp('1 missing'))
   expect(cloudcheck_response).to match(regexp('1. Skip for now
  2. Recreate VM
  3. Delete VM reference') )
  end

  it 'provides resolution options for missing disks' do
    current_sandbox.cpi.delete_disk(current_sandbox.cpi.disk_cids.first)
    cloudcheck_response = bosh_run_cck_with_resolution(1)
    expect(cloudcheck_response).to_not match(regexp('No problems found'))
    expect(cloudcheck_response).to match(regexp('1 missing'))
    expect(cloudcheck_response).to match(regexp('1. Skip for now
  2. Delete disk reference (DANGEROUS!)') )
  end

  it 'automatically recreates missing VMs with when cck --auto is used' do
    current_sandbox.cpi.vm_cids.each do |vm_cid|
      current_sandbox.cpi.delete_vm(vm_cid)
    end

    cloudcheck_response = bosh_run_cck_with_auto
    expect(cloudcheck_response).to match(regexp('missing.'))
    expect(cloudcheck_response).to match(regexp('Applying resolutions...'))
    expect(cloudcheck_response).to match(regexp('Cloudcheck is finished'))
    expect(cloudcheck_response).to_not match(regexp('No problems found'))
    expect(cloudcheck_response).to_not match(regexp('1. Skip for now
  2. Reboot VM
  3. Recreate VM using last known apply spec
  4. Delete VM reference (DANGEROUS!)'))

    expect(runner.run('cloudcheck --report')).to match(regexp('No problems found'))
  end

  def bosh_run_cck_with_resolution(num_errors, option=1)
    resolution_selections = "#{option}\n"*num_errors + "yes"
    output = `echo "#{resolution_selections}" | bosh -c #{ClientSandbox.bosh_config} cloudcheck`
    if $?.exitstatus != 0
      puts output
    end
    output
  end

  def bosh_run_cck_with_auto
    output = `bosh -c #{ClientSandbox.bosh_config} cloudcheck --auto`
    if $?.exitstatus != 0
      puts output
    end
    output
  end
end
