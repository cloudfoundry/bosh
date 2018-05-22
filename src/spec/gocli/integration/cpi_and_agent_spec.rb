require 'spec_helper'

# Requests are properly sent in correct order between director, cpi and agent
describe 'CPI and Agent:', type: :integration do
  with_reset_sandbox_before_each

  let(:manifest_hash) { Bosh::Spec::NetworkingManifest.deployment_manifest(instances: 1) }
  fresh_deploy_invocations = []
  invocations = []

  before do
    manifest_hash['instance_groups'].first['persistent_disk_pool'] = Bosh::Spec::NewDeployments::DISK_TYPE['name']
    task_output = deploy_from_scratch(
      manifest_hash: manifest_hash,
      cloud_config_hash: Bosh::Spec::NewDeployments.simple_cloud_config,
    )

    fresh_deploy_invocations = get_invocations(task_output)
  end

  context 'on a fresh deploy with persistent disk' do
    it 'requests between BOSH Director, CPI and Agent are sent in correct order' do
      invocations = fresh_deploy_invocations

      # Compilation VM
      expect(invocations[0]).to be_cpi_call('info')
      expect(invocations[1]).to be_cpi_call('create_vm')
      compilation_vm_id = invocations[1].response
      expect(invocations[2]).to be_cpi_call('info')
      expect(invocations[3]).to be_cpi_call('set_vm_metadata')
      expect(invocations[4]).to be_agent_call('ping')
      expect(invocations[5]).to be_agent_call('update_settings')
      expect(invocations[6]).to be_agent_call('apply')
      expect(invocations[7]).to be_agent_call('get_state')
      expect(invocations[8]).to be_cpi_call('info')
      expect(invocations[9]).to be_cpi_call('set_vm_metadata')
      expect(invocations[10]).to be_agent_call('compile_package')
      expect(invocations[11]).to be_cpi_call('info')
      expect(invocations[12]).to be_cpi_call('delete_vm', match('vm_cid' => compilation_vm_id))

      # Compilation VM
      expect(invocations[13]).to be_cpi_call('info')
      expect(invocations[14]).to be_cpi_call('create_vm')
      compilation_vm_id = invocations[14].response
      expect(invocations[15]).to be_cpi_call('info')
      expect(invocations[16]).to be_cpi_call('set_vm_metadata')
      expect(invocations[17]).to be_agent_call('ping')
      expect(invocations[18]).to be_agent_call('update_settings')
      expect(invocations[19]).to be_agent_call('apply')
      expect(invocations[20]).to be_agent_call('get_state')
      expect(invocations[21]).to be_cpi_call('info')
      expect(invocations[22]).to be_cpi_call('set_vm_metadata')
      expect(invocations[23]).to be_agent_call('compile_package')
      expect(invocations[24]).to be_cpi_call('info')
      expect(invocations[25]).to be_cpi_call('delete_vm', match('vm_cid' => compilation_vm_id))

      # VM
      expect(invocations[26]).to be_cpi_call('info')
      expect(invocations[27]).to be_cpi_call('create_vm')
      vm_id = invocations[27].response
      expect(invocations[28]).to be_cpi_call('info')
      expect(invocations[29]).to be_cpi_call('set_vm_metadata')
      expect(invocations[30]).to be_agent_call('ping')
      expect(invocations[31]).to be_agent_call('update_settings')
      expect(invocations[32]).to be_agent_call('apply')
      expect(invocations[33]).to be_agent_call('get_state')
      expect(invocations[34]).to be_agent_call('prepare')
      expect(invocations[35]).to be_agent_call('drain')
      expect(invocations[36]).to be_agent_call('stop')
      expect(invocations[37]).to be_agent_call('run_script', match(['post-stop', {}]))
      expect(invocations[38]).to be_cpi_call('info')
      expect(invocations[39]).to be_cpi_call('info')
      expect(invocations[40]).to be_cpi_call('create_disk')
      disk_id = invocations[40].response
      expect(invocations[41]).to be_cpi_call('info')
      expect(invocations[42]).to be_cpi_call('attach_disk', match([vm_id, disk_id]))
      expect(invocations[43]).to be_cpi_call('info')
      expect(invocations[44]).to be_cpi_call('set_disk_metadata')
      expect(invocations[45]).to be_agent_call('ping')
      expect(invocations[46]).to be_agent_call('mount_disk')
      expect(invocations[47]).to be_agent_call('update_settings')
      expect(invocations[48]).to be_agent_call('apply')
      expect(invocations[49]).to be_agent_call('run_script', match(['pre-start', {}]))
      expect(invocations[50]).to be_agent_call('start')
      expect(invocations[51]).to be_agent_call('get_state')
      expect(invocations[52]).to be_agent_call('run_script', match(['post-start', {}]))

      expect(invocations.size).to eq(53)
    end
  end

  context 'on an update deployment with persistent disk' do
    it 'requests between BOSH Director, CPI and Agent are sent in correct order', no_create_swap_delete: true do
      manifest_hash['instance_groups'].first['env'] = { 'bosh' => { 'password' => 'foobar' } }
      task_output = deploy_simple_manifest(manifest_hash: manifest_hash)
      invocations = get_invocations(task_output)

      old_vm_id = fresh_deploy_invocations[1].response
      disk_id = fresh_deploy_invocations[40].response

      # Old VM
      expect(invocations[0]).to be_agent_call('get_state')
      expect(invocations[1]).to be_agent_call('drain')
      expect(invocations[2]).to be_agent_call('stop')
      expect(invocations[3]).to be_agent_call('run_script', match(['post-stop', {}]))
      expect(invocations[4]).to be_cpi_call('info')
      expect(invocations[5]).to be_cpi_call('snapshot_disk')
      expect(invocations[6]).to be_agent_call('list_disk')
      expect(invocations[7]).to be_agent_call('unmount_disk')
      expect(invocations[8]).to be_cpi_call('info')
      expect(invocations[9]).to be_cpi_call('detach_disk', match([old_vm_id, disk_id]))
      expect(invocations[10]).to be_cpi_call('info')
      expect(invocations[11]).to be_cpi_call('delete_vm', match([old_vm_id]))

      # New VM
      expect(invocations[12]).to be_cpi_call('info')
      expect(invocations[13]).to be_cpi_call('create_vm')
      new_vm_id = invocations[13].response
      expect(invocations[14]).to be_cpi_call('info')
      expect(invocations[15]).to be_cpi_call('set_vm_metadata')
      expect(invocations[16]).to be_agent_call('ping')
      expect(invocations[17]).to be_cpi_call('info')
      expect(invocations[18]).to be_cpi_call('attach_disk', match([new_vm_id, disk_id]))
      expect(invocations[19]).to be_cpi_call('info')
      expect(invocations[20]).to be_cpi_call('set_disk_metadata')
      expect(invocations[21]).to be_agent_call('ping')
      expect(invocations[22]).to be_agent_call('mount_disk')
      expect(invocations[23]).to be_agent_call('update_settings')
      expect(invocations[24]).to be_agent_call('apply')
      expect(invocations[25]).to be_agent_call('get_state')
      expect(invocations[26]).to be_agent_call('list_disk')
      expect(invocations[27]).to be_agent_call('apply')
      expect(invocations[28]).to be_agent_call('run_script', match(['pre-start', {}]))
      expect(invocations[29]).to be_agent_call('start')
      expect(invocations[30]).to be_agent_call('get_state')
      expect(invocations[31]).to be_agent_call('run_script', match(['post-start', {}]))

      expect(invocations.size).to eq(32)
    end

    context 'when create-swap-delete is enabled', create_swap_delete: true do
      it 'requests between BOSH Director, CPI and Agent are sent in correct order' do
        manifest_hash['update'] = manifest_hash['update'].merge('vm_strategy' => 'create-swap-delete')
        manifest_hash['instance_groups'].first['env'] = { 'bosh' => { 'password' => 'foobar' } }

        task_output = deploy_simple_manifest(manifest_hash: manifest_hash)
        invocations = get_invocations(task_output)

        old_vm_id = fresh_deploy_invocations[1].response
        disk_id = fresh_deploy_invocations[40].response

        # old vm
        expect(invocations[0]).to be_agent_call('get_state')

        # new vm
        expect(invocations[1]).to be_cpi_call('info')
        expect(invocations[2]).to be_cpi_call('create_vm')
        new_vm_id = invocations[2].response
        expect(invocations[3]).to be_cpi_call('info')
        expect(invocations[4]).to be_cpi_call('set_vm_metadata')
        expect(invocations[5]).to be_agent_call('ping')
        expect(invocations[6]).to be_agent_call('update_settings')
        expect(invocations[7]).to be_agent_call('apply')
        expect(invocations[8]).to be_agent_call('get_state')
        expect(invocations[9]).to be_agent_call('prepare')

        # old vm
        expect(invocations[10]).to be_agent_call('drain')
        expect(invocations[11]).to be_agent_call('stop')
        expect(invocations[12]).to be_agent_call('run_script', match(['post-stop', {}]))
        expect(invocations[13]).to be_cpi_call('info')
        expect(invocations[14]).to be_cpi_call('snapshot_disk')
        expect(invocations[15]).to be_agent_call('list_disk')
        expect(invocations[16]).to be_agent_call('unmount_disk')
        expect(invocations[17]).to be_cpi_call('info')
        expect(invocations[18]).to be_cpi_call('detach_disk', match([old_vm_id, disk_id]))

        # new vm
        expect(invocations[19]).to be_cpi_call('info')
        expect(invocations[20]).to be_cpi_call('attach_disk', match([new_vm_id, disk_id]))
        expect(invocations[21]).to be_cpi_call('info')
        expect(invocations[22]).to be_cpi_call('set_disk_metadata')
        expect(invocations[23]).to be_agent_call('ping')
        expect(invocations[24]).to be_agent_call('mount_disk')
        expect(invocations[25]).to be_agent_call('list_disk')
        expect(invocations[26]).to be_agent_call('apply')
        expect(invocations[27]).to be_agent_call('run_script', match(['pre-start', {}]))
        expect(invocations[28]).to be_agent_call('start')
        expect(invocations[29]).to be_agent_call('get_state')
        expect(invocations[30]).to be_agent_call('run_script', match(['post-start', {}]))

        expect(invocations.size).to eq(31)
      end
    end
  end
end
