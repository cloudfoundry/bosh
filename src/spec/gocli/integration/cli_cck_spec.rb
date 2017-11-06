require_relative '../spec_helper'

describe 'cli: cloudcheck', type: :integration do
  let(:manifest) {Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups}
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
      manifest['instance_groups'][0]['persistent_disk'] = 100
      manifest['instance_groups'][0]['instances'] = num_instances

      deploy_from_scratch(manifest_hash: manifest, cloud_config_hash: Bosh::Spec::NewDeployments.simple_cloud_config)

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
          instance_to_ignore =director.instances.select{|instance| instance.job_name == 'foobar' && instance.index == '1'}.first
          bosh_runner.run("ignore #{instance_to_ignore.job_name}/#{instance_to_ignore.id}", deployment_name: 'simple')
        end

        it 'does not scan ignored vms and their disks' do
          report_output= runner.run('cloud-check --report', deployment_name: 'simple', failure_expected: true)
          expect(report_output).to match(regexp('Scanning 3 VMs: 0 OK, 2 unresponsive, 0 missing, 0 unbound, 1 ignored'))
          expect(report_output).to match(regexp('Scanning 2 persistent disks: 2 OK, 0 missing, 0 inactive, 0 mount-info mismatch'))
          expect(report_output).to match(regexp('2 problem'))

          auto_output = runner.run('cloudcheck --auto', deployment_name: 'simple')
          expect(auto_output).to_not match(/Applying problem resolutions: VM for 'foobar\/[a-z0-9\-]+ \(1\)'/)
          expect(auto_output).to match(/Applying problem resolutions: VM for 'foobar\/[a-z0-9\-]+ \(0\)'/)
          expect(auto_output).to match(/Applying problem resolutions: VM for 'foobar\/[a-z0-9\-]+ \(2\)'/)
        end
      end

      it 'deletes VM reference when delete_reference resolution flag is set' do
        bosh_runner.run('cck --resolution non-matching-resolution1 --resolution delete_vm_reference --resolution non-matching-resolution2', deployment_name: 'simple')

        output = scrub_randoms(runner.run('cloud-check --report', deployment_name: 'simple', failure_expected: true))
        expect(output).to include("4  missing_vm  VM for 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (x)' missing.")
        expect(output).to include("5  missing_vm  VM for 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (x)' missing.")
        expect(output).to include("6  missing_vm  VM for 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (x)' missing.")
      end
    end

    context 'when deployment uses an old cloud config' do
      let(:initial_cloud_config) {
        cloud_config = Bosh::Spec::NewDeployments.simple_cloud_config_with_multiple_azs
        cloud_config['vm_types'][0]['cloud_properties']['stage'] = 'before'
        cloud_config
      }

      let(:new_cloud_config) do
        cloud_config = Bosh::Spec::NewDeployments.simple_cloud_config_with_multiple_azs
        cloud_config['azs'].pop
        cloud_config['networks'][0]['subnets'].pop
        cloud_config['vm_types'][0]['cloud_properties']['stage'] = 'after'
        cloud_config
      end

      let(:deployment_manifest) do
        manifest = Bosh::Spec::NewDeployments::simple_manifest_with_instance_groups
        manifest['instance_groups'][0]['azs'] = ['z1', 'z2']
        manifest['instance_groups'][0]['instances'] = 2
        manifest
      end

      it 'reuses the old config on update', hm: false do
        upload_cloud_config(cloud_config_hash: initial_cloud_config)
        create_and_upload_test_release
        upload_stemcell

        deploy_simple_manifest(manifest_hash: deployment_manifest)

        upload_cloud_config(cloud_config_hash: new_cloud_config)

        current_sandbox.cpi.vm_cids.each do |cid|
          current_sandbox.cpi.delete_vm(cid)
        end

        bosh_runner.run('cloud-check --auto', deployment_name: 'simple')

        expect_table('deployments', [{"cloud_config"=>"outdated", "name"=>"simple", "release_s"=>"bosh-release/0+dev.1", "stemcell_s"=>"ubuntu-stemcell/1", "team_s"=>""}])
        expect(current_sandbox.cpi.invocations_for_method('create_vm').last.inputs['cloud_properties']['stage']).to eq('before')
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

      it 'deletes disk reference when delete_disk_reference is set' do
        cloudcheck_response = scrub_randoms(bosh_runner.run('cck --resolution non-matching-resolution1 --resolution delete_disk_reference --resolution non-matching-resolution2', deployment_name: 'simple'))

        expect(cloudcheck_response).to_not match(regexp('0 problems'))
        expect(cloudcheck_response).to match(regexp('1 missing'))
        expect(cloudcheck_response).to match(regexp("Disk 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx' (foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx, 100M) is missing"))
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
      manifest['instance_groups'][0]['persistent_disk'] = 100
      deploy_from_scratch(manifest_hash: manifest, cloud_config_hash: Bosh::Spec::NewDeployments.simple_cloud_config)

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

  context 'when cloud config is updated after deploying' do
    with_reset_sandbox_before_each
    let(:cloud_config_hash) { Bosh::Spec::NewDeployments.simple_cloud_config }

    before do
      manifest['instance_groups'][0]['instances'] = 1
      manifest['instance_groups'][0]['networks'].first['static_ips'] = ['192.168.1.10']
      create_and_upload_test_release
      upload_stemcell
      upload_cloud_config(cloud_config_hash: cloud_config_hash)
      deploy_simple_manifest(manifest_hash: manifest)

      expect(runner.run('cloud-check --report', deployment_name: 'simple')).to match(regexp('0 problems'))
    end

    it 'recreates VMs with the non-updated cloud config' do
      current_sandbox.cpi.delete_vm(current_sandbox.cpi.vm_cids.first)
      cloud_config_hash['networks'].first['subnets'].first['static'] = ['192.168.1.20']
      upload_cloud_config(cloud_config_hash: cloud_config_hash)

      bosh_run_cck_with_resolution(1, 3)
      expect(director.vms.first.ips).to eq(['192.168.1.10'])
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

      manifest['instance_groups'][0]['persistent_disk'] = 100
      manifest['instance_groups'].first['properties'] = {'test_property' => '((test_property))'}
      deploy_from_scratch(manifest_hash: manifest, cloud_config_hash: Bosh::Spec::NewDeployments.simple_cloud_config, include_credentials: false, env: client_env)

      expect(runner.run('cloud-check --report', deployment_name: 'simple', env: client_env)).to match(regexp('0 problems'))
    end

    it 'resolves issues correctly and gets values from config server' do
      vm = director.instance('foobar', '0', env: client_env)

      template = vm.read_job_template('foobar', 'bin/foobar_ctl')
      expect(template).to include('test_property=cats are happy')

      current_sandbox.cpi.kill_agents

      config_server_helper.put_value(prepend_namespace('test_property'), 'smurfs are happy')

      recreate_vm_without_waiting_for_process = 3
      bosh_run_cck_with_resolution(3, recreate_vm_without_waiting_for_process, client_env)
      expect(runner.run('cloud-check --report', deployment_name: 'simple', env: client_env)).to match(regexp('0 problems'))

      vm = director.instance('foobar', '0', env: client_env)

      template = vm.read_job_template('foobar', 'bin/foobar_ctl')
      expect(template).to include('test_property=cats are happy')
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
