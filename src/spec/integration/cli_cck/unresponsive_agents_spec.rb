require 'spec_helper'

describe 'cli: cloudcheck', type: :integration do
  let(:manifest) { Bosh::Spec::Deployments.simple_manifest_with_instance_groups }
  let(:director_name) { current_sandbox.director_name }
  let(:deployment_name) { manifest['name'] }
  let(:runner) { bosh_runner_in_work_dir(ClientSandbox.test_release_dir) }

  def prepend_namespace(key)
    "/#{director_name}/#{deployment_name}/#{key}"
  end

  context 'with dns disabled' do
    with_reset_sandbox_before_each(dns_enabled: false)

    before do
      manifest['instance_groups'][0]['persistent_disk'] = 100
      manifest['tags'] = { 'deployment-tag' => 'deployment-value' }
      upload_runtime_config(runtime_config_hash: { 'tags' => { 'runtime-tag' => 'runtime-value' },
                                                   'addons' => [
                                                     'name' => 'ubiquitious',
                                                     'jobs' => [],
                                                   ] })
      deploy_from_scratch(manifest_hash: manifest, cloud_config_hash: Bosh::Spec::Deployments.simple_cloud_config)

      expect(runner.run('cloud-check --report', deployment_name: 'simple')).to match(regexp('0 problems'))
    end

    context 'deployment has unresponsive agents' do
      before do
        current_sandbox.cpi.kill_agents
      end

      it 'recreates unresponsive VMs without waiting for processes to start' do
        recreate_vm_without_waiting_for_process = 3
        bosh_run_cck_with_resolution(3, recreate_vm_without_waiting_for_process)
        expect(runner.run('cloud-check --report', deployment_name: 'simple')).to match(regexp('0 problems'))

        invocations = current_sandbox.cpi.invocations
        set_vm_metadata_invocations = invocations.select { |i| i.method_name == 'set_vm_metadata' }
        expect(set_vm_metadata_invocations.length).to eq 10
        expect(set_vm_metadata_invocations.map { |i| i.inputs['metadata'] }).to all(
          include(
            'runtime-tag' => 'runtime-value',
            'deployment-tag' => 'deployment-value',
            'deployment' => 'simple',
          ),
        )
      end
    end
  end

  context 'with dns enabled' do
    with_reset_sandbox_before_each

    let(:num_instances) { 3 } # sum of all instances in :manifest

    before do
      bosh_runner.run("upload-stemcell #{spec_asset('valid_stemcell_with_api_version.tgz')}")
      upload_cloud_config(cloud_config_hash: Bosh::Spec::Deployments.simple_cloud_config)
      create_and_upload_links_release

      manifest['instance_groups'][0] = Bosh::Spec::Deployments.simple_instance_group(
        name: 'foobar',
        jobs: [
          {
            'name' => 'backup_database',
            'release' => 'bosh-release',
            'provides' => { 'backup_db' => { 'as' => 'link_alias' } },
          },
          {
            'name' => 'database',
            'release' => 'bosh-release',
            'provides' => { 'db' => { 'as' => 'db2' } },
          },
        ],
        instances: num_instances,
        persistent_disk: 100,
      )
      manifest['releases'][0] = {
        'name' => 'bosh-release',
        'version' => 'latest',
      }

      deploy(manifest_hash: manifest)

      expect(runner.run('cloud-check --report', deployment_name: 'simple')).to match(regexp('0 problems'))
    end

    context 'deployment has unresponsive agents' do
      before do
        current_sandbox.cpi.kill_agents
      end

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

      it 'recreates with identical config' do
        recreate_vm_without_waiting_for_process = 3
        bosh_run_cck_with_resolution(num_instances, recreate_vm_without_waiting_for_process)
        output = deploy(manifest_hash: manifest)
        expect(output).to_not match(regexp('Updating instance'))
      end

      it 'recreates unresponsive VMs and wait for processes to start' do
        recreate_vm_and_wait_for_process = 4
        bosh_run_cck_with_resolution(num_instances, recreate_vm_and_wait_for_process)
        expect(runner.run('cloud-check --report', deployment_name: 'simple')).to match(regexp('0 problems'))
      end

      it 'recreates with identical config and waits' do
        recreate_vm_and_wait_for_process = 4
        cloudcheck_response = scrub_text_random_ids(bosh_run_cck_with_resolution(num_instances, recreate_vm_and_wait_for_process))
        expect(cloudcheck_response).to match(regexp('3 unresponsive'))
        output = deploy(manifest_hash: manifest)
        expect(output).to_not match(regexp('Updating instance'))
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
        bosh_run_cck_with_resolution(num_instances, delete_vm_reference)
        output = scrub_randoms(runner.run('cloud-check --report', deployment_name: 'simple', failure_expected: true))
        expect(output).to include("4  missing_vm  VM for 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (x)' missing.")
        expect(output).to include("5  missing_vm  VM for 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (x)' missing.")
        expect(output).to include("6  missing_vm  VM for 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (x)' missing.")
      end

      context 'when there is an ignored vm' do
        before do
          instance_to_ignore = director.instances.select do |instance|
            instance.instance_group_name == 'foobar' && instance.index == '1'
          end.first
          bosh_runner.run("ignore #{instance_to_ignore.instance_group_name}/#{instance_to_ignore.id}", deployment_name: 'simple')
        end

        it 'does not scan ignored vms and their disks' do
          report_output = runner.run('cloud-check --report', deployment_name: 'simple', failure_expected: true)
          expect(report_output).to match(regexp('Scanning 3 VMs: 0 OK, 2 unresponsive, 0 missing, 0 unbound, 1 ignored'))
          expect(report_output).to match(
            regexp('Scanning 2 persistent disks: 2 OK, 0 missing, 0 inactive, 0 mount-info mismatch'),
          )
          expect(report_output).to match(regexp('2 problem'))

          auto_output = runner.run('cloudcheck --auto', deployment_name: 'simple')
          expect(auto_output).to_not match(%r{Applying problem resolutions: VM for 'foobar\/[a-z0-9\-]+ \(1\)'})
          expect(auto_output).to match(%r{Applying problem resolutions: VM for 'foobar\/[a-z0-9\-]+ \(0\)'})
          expect(auto_output).to match(%r{Applying problem resolutions: VM for 'foobar\/[a-z0-9\-]+ \(2\)'})
        end
      end

      it 'deletes VM reference when delete_reference resolution flag is set' do
        bosh_runner.run(
          'cck --resolution non-matching-resolution1 --resolution delete_vm_reference --resolution non-matching-resolution2',
          deployment_name: 'simple',
        )

        output = scrub_randoms(runner.run('cloud-check --report', deployment_name: 'simple', failure_expected: true))
        expect(output).to include("4  missing_vm  VM for 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (x)' missing.")
        expect(output).to include("5  missing_vm  VM for 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (x)' missing.")
        expect(output).to include("6  missing_vm  VM for 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (x)' missing.")
      end
    end
  end

  def bosh_run_cck_with_resolution(num_errors, option = 1)
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
    text.gsub(/[0-9a-f]{8}-[0-9a-f-]{27}/, 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx')
  end

  def scrub_text_disk_ids(text)
    text.gsub(/[0-9a-z]{32}/, 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx')
  end

  def scrub_randoms(text)
    scrub_vm_cid(scrub_index(scrub_text_disk_ids(scrub_text_random_ids(text))))
  end

  def scrub_vm_cid(text)
    text.gsub(/'\d+'/, "'xxx'")
  end

  def scrub_index(text)
    text.gsub(/\(\d+\)/, '(x)')
  end
end
