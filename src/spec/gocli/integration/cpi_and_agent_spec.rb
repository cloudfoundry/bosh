require 'spec_helper'

# Requests are properly sent in correct order between director, cpi and agent
describe 'CPI and Agent:', type: :integration do
  with_reset_sandbox_before_each

  let(:manifest_hash) do
    manifest_hash = Bosh::Spec::NetworkingManifest.deployment_manifest(instances: 1)
    manifest_hash['instance_groups'].first['persistent_disk_pool'] = Bosh::Spec::NewDeployments::DISK_TYPE['name']
    manifest_hash
  end

  let!(:fresh_deploy_invocations) do
    task_output = deploy_from_scratch(
      manifest_hash: manifest_hash,
      cloud_config_hash: cloud_config_hash,
    )

    get_invocations(task_output)
  end

  let(:cloud_config_hash) do
    Bosh::Spec::NewDeployments.simple_cloud_config.merge(
      'disk_types' => [
        Bosh::Spec::NewDeployments::DISK_TYPE,
      ],
    )
  end

  let(:old_vm_id) do
    fresh_deploy_invocations.find_all { |i| i.method == 'create_vm' }.last.response
  end

  let(:disk_id) do
    fresh_deploy_invocations.find { |i| i.method == 'create_disk' }.response
  end

  context 'on a fresh deploy with persistent disk' do
    it 'requests between BOSH Director, CPI and Agent are sent in correct order' do
      invocations = Support::InvocationsHelper::InvocationIterator.new(fresh_deploy_invocations)

      expect(invocations.size).to eq(53)

      # Compilation VM
      expect(invocations.next).to be_cpi_call('info')
      create_compilation_vm1 = invocations.next
      expect(create_compilation_vm1).to be_cpi_call('create_vm')
      expect(invocations.next).to be_cpi_call('info')
      expect(invocations.next).to be_cpi_call('set_vm_metadata')
      expect(invocations.next).to be_agent_call('ping')
      expect(invocations.next).to be_agent_call('update_settings')
      expect(invocations.next).to be_agent_call('apply')
      expect(invocations.next).to be_agent_call('get_state')
      expect(invocations.next).to be_cpi_call('info')
      expect(invocations.next).to be_cpi_call('set_vm_metadata')
      expect(invocations.next).to be_agent_call('compile_package')
      expect(invocations.next).to be_cpi_call('info')
      expect(invocations.next).to be_cpi_call('delete_vm', match('vm_cid' => create_compilation_vm1.response))

      # Compilation VM
      expect(invocations.next).to be_cpi_call('info')
      create_compilation_vm2 = invocations.next
      expect(create_compilation_vm2).to be_cpi_call('create_vm')
      expect(invocations.next).to be_cpi_call('info')
      expect(invocations.next).to be_cpi_call('set_vm_metadata')
      expect(invocations.next).to be_agent_call('ping')
      expect(invocations.next).to be_agent_call('update_settings')
      expect(invocations.next).to be_agent_call('apply')
      expect(invocations.next).to be_agent_call('get_state')
      expect(invocations.next).to be_cpi_call('info')
      expect(invocations.next).to be_cpi_call('set_vm_metadata')
      expect(invocations.next).to be_agent_call('compile_package')
      expect(invocations.next).to be_cpi_call('info')
      expect(invocations.next).to be_cpi_call('delete_vm', match('vm_cid' => create_compilation_vm2.response))

      # VM
      expect(invocations.next).to be_cpi_call('info')
      create_vm = invocations.next
      expect(create_vm).to be_cpi_call('create_vm')
      expect(invocations.next).to be_cpi_call('info')
      expect(invocations.next).to be_cpi_call('set_vm_metadata')
      expect(invocations.next).to be_agent_call('ping')
      expect(invocations.next).to be_agent_call('update_settings')
      expect(invocations.next).to be_agent_call('apply')
      expect(invocations.next).to be_agent_call('get_state')
      expect(invocations.next).to be_agent_call('prepare')
      expect(invocations.next).to be_agent_call('drain')
      expect(invocations.next).to be_agent_call('stop')
      expect(invocations.next).to be_agent_call('run_script', match(['post-stop', {}]))
      expect(invocations.next).to be_cpi_call('info')
      expect(invocations.next).to be_cpi_call('info')
      create_disk = invocations.next
      expect(create_disk).to be_cpi_call('create_disk')
      expect(invocations.next).to be_cpi_call('info')
      expect(invocations.next).to be_cpi_call(
        'attach_disk',
        match(
          'vm_cid' => create_vm.response,
          'disk_id' => create_disk.response,
        ),
      )
      expect(invocations.next).to be_cpi_call('info')
      expect(invocations.next).to be_cpi_call('set_disk_metadata')
      expect(invocations.next).to be_agent_call('ping')
      expect(invocations.next).to be_agent_call('mount_disk')
      expect(invocations.next).to be_agent_call('update_settings')
      expect(invocations.next).to be_agent_call('apply')
      expect(invocations.next).to be_agent_call('run_script', match(['pre-start', {}]))
      expect(invocations.next).to be_agent_call('start')
      expect(invocations.next).to be_agent_call('get_state')
      expect(invocations.next).to be_agent_call('run_script', match(['post-start', {}]))
    end
  end

  context 'on an update deployment with persistent disk' do
    let(:updated_manifest_hash) do
      updated_manifest_hash = Bosh::Spec::NetworkingManifest.deployment_manifest(instances: 1)
      updated_manifest_hash['instance_groups'].first['persistent_disk_pool'] = Bosh::Spec::NewDeployments::DISK_TYPE['name']
      updated_manifest_hash['instance_groups'].first['env'] = { 'bosh' => { 'password' => 'foobar' } }
      updated_manifest_hash
    end

    it 'requests between BOSH Director, CPI and Agent are sent in correct order', no_create_swap_delete: true do
      task_output = deploy_simple_manifest(manifest_hash: updated_manifest_hash)
      invocations = Support::InvocationsHelper::InvocationIterator.new(get_invocations(task_output))

      expect(invocations.size).to eq(33)

      # Old VM
      expect(invocations.next).to be_agent_call('get_state')
      expect(invocations.next).to be_agent_call('drain')
      expect(invocations.next).to be_agent_call('stop')
      expect(invocations.next).to be_agent_call('run_script', match(['post-stop', {}]))
      expect(invocations.next).to be_cpi_call('info')
      expect(invocations.next).to be_cpi_call('snapshot_disk')
      expect(invocations.next).to be_agent_call('list_disk')
      expect(invocations.next).to be_agent_call('unmount_disk')
      expect(invocations.next).to be_agent_call('remove_persistent_disk')
      expect(invocations.next).to be_cpi_call('info')
      expect(invocations.next).to be_cpi_call(
        'detach_disk',
        match(
          'vm_cid' => old_vm_id,
          'disk_id' => disk_id,
        ),
      )
      expect(invocations.next).to be_cpi_call('info')
      expect(invocations.next).to be_cpi_call('delete_vm', match('vm_cid' => old_vm_id))

      # New VM
      expect(invocations.next).to be_cpi_call('info')
      create_vm = invocations.next
      expect(create_vm).to be_cpi_call('create_vm')
      expect(invocations.next).to be_cpi_call('info')
      expect(invocations.next).to be_cpi_call('set_vm_metadata')
      expect(invocations.next).to be_agent_call('ping')
      expect(invocations.next).to be_cpi_call('info')
      expect(invocations.next).to be_cpi_call(
        'attach_disk',
        match(
          'vm_cid' => create_vm.response,
          'disk_id' => disk_id,
        ),
      )
      expect(invocations.next).to be_cpi_call('info')
      expect(invocations.next).to be_cpi_call('set_disk_metadata')
      expect(invocations.next).to be_agent_call('ping')
      expect(invocations.next).to be_agent_call('mount_disk')
      expect(invocations.next).to be_agent_call('update_settings')
      expect(invocations.next).to be_agent_call('apply')
      expect(invocations.next).to be_agent_call('get_state')
      expect(invocations.next).to be_agent_call('list_disk')
      expect(invocations.next).to be_agent_call('apply')
      expect(invocations.next).to be_agent_call('run_script', match(['pre-start', {}]))
      expect(invocations.next).to be_agent_call('start')
      expect(invocations.next).to be_agent_call('get_state')
      expect(invocations.next).to be_agent_call('run_script', match(['post-start', {}]))
    end

    context 'when create-swap-delete is enabled', create_swap_delete: true do
      before do
        manifest_hash['update'] = manifest_hash['update'].merge('vm_strategy' => 'create-swap-delete')
        manifest_hash['instance_groups'].first['env'] = { 'bosh' => { 'password' => 'foobar' } }
      end

      it 'requests between BOSH Director, CPI and Agent are sent in correct order' do
        task_output = deploy_simple_manifest(manifest_hash: manifest_hash)
        invocations = Support::InvocationsHelper::InvocationIterator.new(get_invocations(task_output))

        # old vm
        expect(invocations.next).to be_agent_call('get_state')

        # new vm
        expect(invocations.next).to be_cpi_call('info')
        new_create_vm = invocations.next
        expect(new_create_vm).to be_cpi_call('create_vm')
        expect(invocations.next).to be_cpi_call('info')
        expect(invocations.next).to be_cpi_call('set_vm_metadata')
        expect(invocations.next).to be_agent_call('ping')
        expect(invocations.next).to be_agent_call('update_settings')
        expect(invocations.next).to be_agent_call('apply')
        expect(invocations.next).to be_agent_call('get_state')
        expect(invocations.next).to be_agent_call('prepare')

        # old vm
        expect(invocations.next).to be_agent_call('drain')
        expect(invocations.next).to be_agent_call('stop')
        expect(invocations.next).to be_agent_call('run_script', match(['post-stop', {}]))
        expect(invocations.next).to be_cpi_call('info')
        expect(invocations.next).to be_cpi_call('snapshot_disk')
        expect(invocations.next).to be_agent_call('list_disk')
        expect(invocations.next).to be_agent_call('unmount_disk')
        expect(invocations.next).to be_agent_call('remove_persistent_disk', match([disk_id]))
        expect(invocations.next).to be_cpi_call('info')
        expect(invocations.next).to be_cpi_call(
          'detach_disk',
          match(
            'vm_cid' => old_vm_id,
            'disk_id' => disk_id,
          ),
        )

        # new vm
        expect(invocations.next).to be_cpi_call('info')
        expect(invocations.next).to be_cpi_call(
          'attach_disk',
          match(
            'vm_cid' => new_create_vm.response,
            'disk_id' => disk_id,
          ),
        )
        expect(invocations.next).to be_cpi_call('info')
        expect(invocations.next).to be_cpi_call('set_disk_metadata')
        expect(invocations.next).to be_agent_call('ping')
        expect(invocations.next).to be_agent_call('mount_disk')
        expect(invocations.next).to be_agent_call('list_disk')
        expect(invocations.next).to be_agent_call('apply')
        expect(invocations.next).to be_agent_call('run_script', match(['pre-start', {}]))
        expect(invocations.next).to be_agent_call('start')
        expect(invocations.next).to be_agent_call('get_state')
        expect(invocations.next).to be_agent_call('run_script', match(['post-start', {}]))

        expect(invocations.size).to eq(32)
      end
    end
  end
end
