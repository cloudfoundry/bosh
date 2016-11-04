require_relative '../spec_helper'

describe 'cli: cloudcheck', type: :integration do
  let(:manifest) {Bosh::Spec::Deployments.simple_manifest}
  let(:director_name) {current_sandbox.director_name}
  let(:deployment_name) {manifest['name']}
  let(:runner) { bosh_runner_in_work_dir(ClientSandbox.test_release_dir) }

  def prepend_namespace(key)
    "/#{director_name}/#{deployment_name}/#{key}"
  end

  context 'with dns enabled' do
    with_reset_sandbox_before_each

    let(:num_instances) { 3 }


    before do
      manifest['jobs'][0]['persistent_disk'] = 100
      manifest['jobs'][0]['instances'] = num_instances

      deploy_from_scratch(manifest_hash: manifest)

      expect(runner.run('cloud-check --report', deployment_name: 'simple')).to match(regexp('0 problems'))
    end

    context 'deployment has unresponsive agents' do
      before {
        current_sandbox.cpi.kill_agents
      }

      it 'provides resolution options' do
        cloudcheck_response = scrub_text_random_ids(bosh_run_cck_with_resolution(3))
        expect(cloudcheck_response).to_not match(regexp('0 problems'))
        expect(cloudcheck_response).to match(regexp('3 unresponsive'))
        expect(cloudcheck_response).to match(regexp("1: Skip for now
2: Reboot VM
3: Recreate VM without waiting for processes to start
4: Recreate VM and wait for processes to start
5: Delete VM
6: Delete VM reference (forceful; may need to manually delete VM from the Cloud to avoid IP conflicts)"))
      end

      it 'recreates unresponsive VMs without waiting for processes to start' do
        recreate_vm_without_waiting_for_process = 3
        bosh_run_cck_with_resolution(num_instances, recreate_vm_without_waiting_for_process)
        expect(runner.run('cloud-check --report', deployment_name: 'simple')).to match(regexp('0 problems'))
      end

      it 'recreates unresponsive VMs and wait for processes to start' do
        recreate_vm_and_wait_for_processs = 4
        bosh_run_cck_with_resolution(3, recreate_vm_and_wait_for_processs)
        expect(runner.run('cloud-check --report', deployment_name: 'simple')).to match(regexp('0 problems'))
      end

      it 'deletes unresponsive VMs' do
        delete_vm = 5
        bosh_run_cck_with_resolution(num_instances, delete_vm)
        output = scrub_randoms(runner.run('cloud-check --report', deployment_name: 'simple', failure_expected: true))
        expect(output).to include("4  missing_vm  VM for 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (x)' missing.")
        expect(output).to include("5  missing_vm  VM for 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (x)' missing.")
        expect(output).to include("6  missing_vm  VM for 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (x)' missing.")
      end

      it 'deletes VM reference' do
        delete_vm_reference = 6
        bosh_run_cck_with_resolution(3, delete_vm_reference)
        output = scrub_randoms(runner.run('cloud-check --report', deployment_name: 'simple', failure_expected: true))
        expect(output).to include("4  missing_vm  VM for 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (x)' missing.")
        expect(output).to include("5  missing_vm  VM for 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (x)' missing.")
        expect(output).to include("6  missing_vm  VM for 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (x)' missing.")
      end

      context 'when there is an ignored vm' do
        before do
          pending('cli2: #125441581 backport ignore/uningnore-instance commands')
          vm_to_ignore =director.vms.select{|vm| vm.job_name == 'foobar' && vm.index == '1'}.first
          bosh_runner.run("ignore-instance #{vm_to_ignore.job_name}/#{vm_to_ignore.instance_uuid}", deployment_name: 'simple')
        end

        it 'does not scan ignored vms and their disks' do
          report_output= runner.run('cloud-check --report', deployment_name: 'simple', failure_expected: true)
          expect(report_output).to match(regexp('Started scanning 3 vms > 0 OK, 2 unresponsive, 0 missing, 0 unbound, 1 ignored. Done'))
          expect(report_output).to match(regexp('Started scanning 2 persistent disks > 2 OK, 0 missing, 0 inactive, 0 mount-info mismatch. Done'))
          expect(report_output).to match(regexp('Found 2 problems'))

          auto_output = runner.run('cloudcheck --auto')
          expect(auto_output).to_not match(/Started applying problem resolutions > VM for 'foobar\/[a-z0-9\-]+ \(1\)'/)
          expect(auto_output).to match(/Started applying problem resolutions > VM for 'foobar\/[a-z0-9\-]+ \(0\)'/)
          expect(auto_output).to match(/Started applying problem resolutions > VM for 'foobar\/[a-z0-9\-]+ \(2\)'/)
        end
      end
    end

    context 'deployment has missing VMs' do
      before {
        current_sandbox.cpi.delete_vm(current_sandbox.cpi.vm_cids.first)
      }

      it 'provides resolution options' do
        cloudcheck_response = scrub_text_random_ids(bosh_run_cck_with_resolution(1))
        expect(cloudcheck_response).to_not match(regexp('0 problems'))
        expect(cloudcheck_response).to match(regexp('1 missing'))
        expect(cloudcheck_response).to match(%r(1: Skip for now
2: Recreate VM without waiting for processes to start
3: Recreate VM and wait for processes to start
4: Delete VM reference))
      end

      it 'recreates missing VMs without waiting for processes to start' do
        recreate_vm_without_waiting_for_process = 2
        bosh_run_cck_with_resolution(1, recreate_vm_without_waiting_for_process)
        expect(runner.run('cloud-check --report', deployment_name: 'simple')).to match(regexp('0 problems'))
      end

      it 'recreates missing VMs and wait for processes to start' do
        recreate_vm_and_wait_for_processs = 3
        bosh_run_cck_with_resolution(1, recreate_vm_and_wait_for_processs)
        expect(runner.run('cloud-check --report', deployment_name: 'simple')).to match(regexp('0 problems'))
      end

      it 'deletes missing VM reference' do
        delete_vm_reference = 4
        expect(scrub_randoms(runner.run('cloud-check --report', deployment_name: 'simple', failure_expected: true))).to match_output %(
1  missing_vm  VM for 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (x)' with cloud ID 'xxx' missing.
        )
        bosh_run_cck_with_resolution(1, delete_vm_reference)
        output = scrub_randoms(runner.run('cloud-check --report', deployment_name: 'simple', failure_expected: true))
        expect(output).to include("missing_vm  VM for 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (x)' missing.")
        expect(output).to include('1 problems')
      end
    end

    context 'deployment has missing disks' do
      before {
        current_sandbox.cpi.delete_disk(current_sandbox.cpi.disk_cids.first)
      }

      it 'provides resolution options' do
        cloudcheck_response = scrub_randoms(bosh_run_cck_with_resolution(1))
        expect(cloudcheck_response).to_not match(regexp('0 problems'))
        expect(cloudcheck_response).to match(regexp('1 missing'))
        expect(cloudcheck_response).to match(regexp("Disk 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx' (foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx, 100M) is missing"))
        expect(cloudcheck_response).to match(regexp('1: Skip for now
2: Delete disk reference (DANGEROUS!)'))
      end
    end

    it 'automatically recreates missing VMs when cck --auto is used' do
      current_sandbox.cpi.vm_cids.each do |vm_cid|
        current_sandbox.cpi.delete_vm(vm_cid)
      end

      cloudcheck_response = bosh_runner.run('cloud-check --auto', deployment_name: 'simple')
      expect(cloudcheck_response).to match(regexp('missing.'))
      expect(cloudcheck_response).to match(regexp('Applying problem resolutions'))
      expect(cloudcheck_response).to match(regexp('Succeeded'))
      expect(cloudcheck_response).to_not match(regexp('0 problems'))
      expect(cloudcheck_response).to_not match(regexp('1: Skip for now
2: Reboot VM
3: Recreate VM using last known apply spec
4: Delete VM
5: Delete VM reference (DANGEROUS!)'))

      expect(runner.run('cloud-check --report', deployment_name: 'simple')).to match(regexp('0 problems'))
    end
  end

  context 'with dns disabled' do
    with_reset_sandbox_before_each(dns_enabled: false)

    before do
      manifest['jobs'][0]['persistent_disk'] = 100
      deploy_from_scratch(manifest_hash: manifest)

      expect(runner.run('cloud-check --report', deployment_name: 'simple')).to match(regexp('0 problems'))
    end

    context 'deployment has unresponsive agents' do
      before {
        current_sandbox.cpi.kill_agents
      }

      it 'recreates unresponsive VMs without waiting for processes to start' do
        recreate_vm_without_waiting_for_process = 3
        bosh_run_cck_with_resolution(3, recreate_vm_without_waiting_for_process)
        expect(runner.run('cloud-check --report', deployment_name: 'simple')).to match(regexp('0 problems'))
      end
    end
  end

  context 'with config server enabled' do
    with_reset_sandbox_before_each(config_server_enabled: true, user_authentication: 'uaa', uaa_encryption: 'asymmetric')

    let (:config_server_helper) { Bosh::Spec::ConfigServerHelper.new(current_sandbox, logger) }
    let(:client_env) { {'BOSH_LOG_LEVEL' => 'debug', 'BOSH_CLIENT' => 'test', 'BOSH_CLIENT_SECRET' => 'secret'} }

    before do
      pending('cli2: #131927867 gocli drops the context path from director.info.auth uaa url')
      bosh_runner.run('log-out')

      config_server_helper.put_value(prepend_namespace('test_property'), 'cats are happy')

      manifest['jobs'][0]['persistent_disk'] = 100
      manifest['jobs'].first['properties'] = {'test_property' => '((test_property))'}
      deploy_from_scratch(manifest_hash: manifest, include_credentials: false, env: client_env)

      expect(runner.run('cloud-check --report', deployment_name: 'simple', env: client_env)).to match(regexp('0 problems'))
    end

    it 'resolves issues correctly and gets values from config server' do
      vm = director.vm('foobar', '0', env: client_env)

      template = vm.read_job_template('foobar', 'bin/foobar_ctl')
      expect(template).to include('test_property=cats are happy')

      current_sandbox.cpi.kill_agents

      config_server_helper.put_value(prepend_namespace('test_property'), 'smurfs are happy')

      recreate_vm_without_waiting_for_process = 3
      bosh_run_cck_with_resolution(3, recreate_vm_without_waiting_for_process, client_env)
      expect(runner.run('cloud-check --report', deployment_name: 'simple', env: client_env)).to match(regexp('0 problems'))

      vm = director.vm('foobar', '0', env: client_env)

      template = vm.read_job_template('foobar', 'bin/foobar_ctl')
      expect(template).to include('test_property=smurfs are happy')
    end
  end

  def bosh_run_cck_with_resolution(num_errors, option=1, env={})
    env.each do |key, value|
      ENV[key] = value
    end

    output = ''
    bosh_runner.run_interactively('cck', deployment_name: 'simple') do |runner|
      (1..num_errors).each do
        expect(runner).to have_output 'Skip for now'

        runner.send_keys option.to_s
      end

      expect(runner).to have_output 'Continue?'
      runner.send_keys 'y'

      expect(runner).to have_output 'Succeeded'
      output = runner.output
    end
    output
  end

  def scrub_text_random_ids(text)
    text.gsub /[0-9a-f]{8}-[0-9a-f-]{27}/, "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  end

  def scrub_text_disk_ids(text)
    text.gsub /[0-9a-z]{32}/, "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
  end

  def scrub_randoms(text)
    scrub_vm_cid(scrub_index(scrub_text_disk_ids(scrub_text_random_ids(text))))
  end

  def scrub_vm_cid(text)
    text.gsub /'\d+'/, "'xxx'"
  end

  def scrub_index(text)
    text.gsub /\(\d+\)/, "(x)"
  end
end
