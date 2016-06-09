require 'spec_helper'

describe 'cli: cloudcheck', type: :integration do
  with_reset_sandbox_before_each

  let(:runner) { bosh_runner_in_work_dir(ClientSandbox.test_release_dir) }

  before do
    manifest = Bosh::Spec::Deployments.simple_manifest
    manifest['jobs'][0]['persistent_disk'] = 100
    deploy_from_scratch(manifest_hash: manifest)

    expect(runner.run('cloudcheck --report')).to match(regexp('No problems found'))
  end

  context 'deployment has unresponsive agents' do
    before {
      current_sandbox.cpi.kill_agents
    }

    it 'provides resolution options' do
      cloudcheck_response = scrub_random_ids(bosh_run_cck_with_resolution(3))
      expect(cloudcheck_response).to_not match(regexp('No problems found'))
      expect(cloudcheck_response).to match(regexp('3 unresponsive'))
      expect(cloudcheck_response).to match(regexp("1. Skip for now
  2. Reboot VM
  3. Recreate VM for 'foobar/0 (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)' without waiting for processes to start
  4. Recreate VM for 'foobar/0 (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)' and wait for processes to start
  5. Delete VM
  6. Delete VM reference (forceful; may need to manually delete VM from the Cloud to avoid IP conflicts)"))
    end

    it 'recreates unresponsive VMs without waiting for processes to start' do
      recreate_vm_without_waiting_for_process = 3
      bosh_run_cck_with_resolution(3, recreate_vm_without_waiting_for_process)
      expect(runner.run('cloudcheck --report')).to match(regexp('No problems found'))
    end

    it 'recreates unresponsive VMs and wait for processes to start' do
      recreate_vm_and_wait_for_processs = 4
      bosh_run_cck_with_resolution(3, recreate_vm_and_wait_for_processs)
      expect(runner.run('cloudcheck --report')).to match(regexp('No problems found'))
    end

    it 'deletes unresponsive VMs' do
      delete_vm = 5
      bosh_run_cck_with_resolution(3, delete_vm)
      expect(runner.run('cloudcheck --report')).to match(regexp('No problems found'))
    end

    it 'deletes VM reference' do
      delete_vm_reference = 6
      bosh_run_cck_with_resolution(3, delete_vm_reference)
      expect(runner.run('cloudcheck --report')).to match(regexp('No problems found'))
    end

    context 'when there is an ignored vm' do
      before do
        vm_to_ignore =director.vms.select{|vm| vm.job_name == 'foobar' && vm.index == '1'}.first
        bosh_runner.run("ignore instance #{vm_to_ignore.job_name}/#{vm_to_ignore.instance_uuid}")
      end

      it 'does not scan ignored vms and their disks' do
        report_output= runner.run('cloudcheck --report', failure_expected: true)
        expect(report_output).to match(regexp('Started scanning 3 vms > 0 OK, 2 unresponsive, 0 missing, 0 unbound, 1 ignored. Done'))
        expect(report_output).to match(regexp('Started scanning 2 persistent disks > 2 OK, 0 missing, 0 inactive, 0 mount-info mismatch. Done'))
        expect(report_output).to match(regexp('Found 2 problems'))

        auto_output = runner.run('cloudcheck --auto')
        expect(auto_output).to_not match(regexp('Started applying problem resolutions > foobar/1'))
        expect(auto_output).to match(regexp('Started applying problem resolutions > foobar/0'))
        expect(auto_output).to match(regexp('Started applying problem resolutions > foobar/2'))
      end
    end
  end

  context 'deployment has missing VMs' do
    before {
      current_sandbox.cpi.delete_vm(current_sandbox.cpi.vm_cids.first)
    }

    it 'provides resolution options' do
      cloudcheck_response = scrub_random_ids(bosh_run_cck_with_resolution(1))
      expect(cloudcheck_response).to_not match(regexp('No problems found'))
      expect(cloudcheck_response).to match(regexp('1 missing'))
      expect(cloudcheck_response).to match(%r(1\. Skip for now
  2\. Recreate VM for 'foobar\/\d \(xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx\)' without waiting for processes to start
  3\. Recreate VM for 'foobar\/\d \(xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx\)' and wait for processes to start
  4\. Delete VM reference))
    end

    it 'recreates missing VMs without waiting for processes to start' do
      recreate_vm_without_waiting_for_process = 2
      bosh_run_cck_with_resolution(1, recreate_vm_without_waiting_for_process)
      expect(runner.run('cloudcheck --report')).to match(regexp('No problems found'))
    end

    it 'recreates missing VMs and wait for processes to start' do
      recreate_vm_and_wait_for_processs = 3
      bosh_run_cck_with_resolution(1, recreate_vm_and_wait_for_processs)
      expect(runner.run('cloudcheck --report')).to match(regexp('No problems found'))
    end

    it 'deletes missing VM reference' do
      delete_vm_reference = 4
      bosh_run_cck_with_resolution(1, delete_vm_reference)
      expect(runner.run('cloudcheck --report')).to match(regexp('No problems found'))
    end
  end

  context 'deployment has missing disks' do
    before {
      current_sandbox.cpi.delete_disk(current_sandbox.cpi.disk_cids.first)
    }

    it 'provides resolution options' do
      cloudcheck_response = scrub_random_cids(scrub_random_ids(bosh_run_cck_with_resolution(1)))
      expect(cloudcheck_response).to_not match(regexp('No problems found'))
      expect(cloudcheck_response).to match(regexp('1 missing'))
      expect(cloudcheck_response).to match(regexp("Disk 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx' (foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx, 100M) is missing"))
      expect(cloudcheck_response).to match(regexp('1. Skip for now
  2. Delete disk reference (DANGEROUS!)') )
    end
  end

  it 'automatically recreates missing VMs when cck --auto is used' do
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
  4. Delete VM
  5. Delete VM reference (DANGEROUS!)'))

    expect(runner.run('cloudcheck --report')).to match(regexp('No problems found'))
  end

  def bosh_run_cck_with_resolution(num_errors, option=1)
    resolution_selections = "#{option}\n"*num_errors + "yes"
    output = `echo "#{resolution_selections}" | bosh -c #{ClientSandbox.bosh_config} cloudcheck`
    if $?.exitstatus != 0
      fail("Cloud check failed, output: #{output}")
    end
    output
  end

  def bosh_run_cck_with_auto
    output = `bosh -c #{ClientSandbox.bosh_config} cloudcheck --auto`
    if $?.exitstatus != 0
      fail("Cloud check failed, output: #{output}")
    end
    output
  end
end
