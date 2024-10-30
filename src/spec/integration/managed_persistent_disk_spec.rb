require 'spec_helper'

describe 'Managed persistent disk', type: :integration do
  with_reset_sandbox_before_each(dummy_cpi_api_version: 2)

  let(:cloud_config_hash) do
    hash = SharedSupport::DeploymentManifestHelper.simple_cloud_config
    hash['disk_types'] = [
      {
        'name' => 'my-disk',
        'disk_size' => 1024,
        'cloud_properties' => { 'type' => 'gp2' },
      },
      {
        'name' => 'my-bigger-disk',
        'disk_size' => 2048,
        'cloud_properties' => { 'type' => 'gp2' },
      }
    ]
    hash
  end

  let(:manifest_hash) do
    manifest = SharedSupport::DeploymentManifestHelper.simple_manifest_with_instance_groups
    manifest['instance_groups'][0]['persistent_disk_type'] = 'my-disk'
    manifest
  end

  before do
    upload_stemcell

    create_and_upload_test_release
    upload_cloud_config(cloud_config_hash: cloud_config_hash)
    deploy_simple_manifest(manifest_hash: manifest_hash)
  end

  it 'mounts a persistent disk at /store in the agent base dir' do
    agent_dir = current_sandbox.cpi.agent_dir_for_vm_cid(director.instances.first.vm_cid)
    # Dummy platform keeps track of mounted disks via mounts.json
    current_mounts = JSON.parse(File.read("#{agent_dir}/bosh/mounts.json"))
    expect(current_mounts.length).to eq(1)
    expect(current_mounts.first['MountDir']).to eq("#{agent_dir}/store")
  end

  context 'when the agent is restarted' do
    before do
      agent_id = /agent-base-dir-(.*)/.match(current_sandbox.cpi.agent_dir_for_vm_cid(director.instances.first.vm_cid))[1]
      director.instances.first.kill_agent
      current_sandbox.cpi.spawn_agent_process(agent_id)
      sleep 1
    end

    it 'does not remount the persistent disk' do
      agent_dir = current_sandbox.cpi.agent_dir_for_vm_cid(director.instances.first.vm_cid)
      current_mounts = JSON.parse(File.read("#{agent_dir}/bosh/mounts.json"))
      expect(current_mounts.length).to eq(1)
      expect(current_mounts.first['MountDir']).to eq("#{agent_dir}/store")
    end
  end

  context 'when the vm is restarted' do
    before do
      # This simulates mount points being wiped out by VM restart
      agent_dir = current_sandbox.cpi.agent_dir_for_vm_cid(director.instances.first.vm_cid)
      File.delete("#{agent_dir}/bosh/mounts.json")

      agent_id = /agent-base-dir-(.*)/.match(current_sandbox.cpi.agent_dir_for_vm_cid(director.instances.first.vm_cid))[1]
      director.instances.first.kill_agent
      current_sandbox.cpi.spawn_agent_process(agent_id)
      sleep 1
    end

    it 'remounts the persistent disk' do
      agent_dir = current_sandbox.cpi.agent_dir_for_vm_cid(director.instances.first.vm_cid)
      current_mounts = JSON.parse(File.read("#{agent_dir}/bosh/mounts.json"))
      expect(current_mounts.length).to eq(1)
      expect(current_mounts.first['MountDir']).to eq("#{agent_dir}/store")
    end
  end

  context 'when the disk size is increased' do
    it 'should migrate then remove the old disk' do
      agent_dir = current_sandbox.cpi.agent_dir_for_vm_cid(director.instances.first.vm_cid)
      initial_hints = JSON.parse(File.read("#{agent_dir}/bosh/persistent_disk_hints.json"))
      expect(initial_hints.length).to eq(1)

      manifest_hash['instance_groups'][0]['persistent_disk_type'] = 'my-bigger-disk'
      deploy_simple_manifest(manifest_hash: manifest_hash)

      agent_dir = current_sandbox.cpi.agent_dir_for_vm_cid(director.instances.first.vm_cid)
      current_hints = JSON.parse(File.read("#{agent_dir}/bosh/persistent_disk_hints.json"))
      expect(current_hints.length).to eq(1)
      expect(current_hints.keys[0]).to_not eq(initial_hints.keys[0])
    end
  end
end
