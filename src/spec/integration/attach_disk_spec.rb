require 'spec_helper'

describe 'attach disk', type: :integration do
  with_reset_sandbox_before_each

  context 'deployment has disk that does not exist in an orphaned list attached to an instance' do

    let(:simple_manifest) do
      manifest_hash = Bosh::Spec::Deployments.simple_manifest
      manifest_hash['releases'].first['version'] = 'latest'
      manifest_hash['jobs'][0]['instances'] = 1
      manifest_hash['jobs'][0]['persistent_disk'] = 1000
      manifest_hash
    end

    before do
      deploy_from_scratch(manifest_hash: simple_manifest)
    end

    it 'attaches the disk to a hard stopped instance' do
      instance = director.instances.first

      bosh_runner.run("stop foobar #{instance.id} --hard")
      bosh_runner.run("attach disk foobar #{instance.id} disk-cid-abc123")
      bosh_runner.run("start foobar #{instance.id}")

      instance = director.instances.first

      expect(current_sandbox.cpi.disk_attached_to_vm?(instance.vm_cid, instance.disk_cid)).to eq(true)

      agent_dir = current_sandbox.cpi.agent_dir_for_vm_cid(instance.vm_cid)

      # Director has no way of knowing the size of the disk attached in this case,
      # it was just a random disk in the IAAS (it was not an orphaned disk w size info).
      # Therefore, director assumes the disk is size 1 and the subsequent start will cause
      # the attached disk to be migrated to a disk with the size declared in the manifest.
      disk_migrations = JSON.parse(File.read("#{agent_dir}/bosh/disk_migrations.json"))
      expect(disk_migrations.count).to eq(1)
      first_disk_migration = disk_migrations.first

      # disk_migrations.json example: "[{'FromDiskCid': 'foo-cid', 'ToDiskCid': 'bar-cid'}]"
      expect(first_disk_migration['FromDiskCid']).to eq('disk-cid-abc123')
      expect(instance.disk_cid).to eq(first_disk_migration['ToDiskCid'])
      expect(current_sandbox.cpi.invocations_for_method('set_disk_metadata').last['inputs']['disk_cid']).to eq(instance.disk_cid)
    end

    it 'attaches the disk to a soft stopped instance' do
      instance = director.instances.first

      bosh_runner.run("stop foobar #{instance.id} --soft")
      bosh_runner.run("attach disk foobar #{instance.id} disk-cid-abc123")
      bosh_runner.run("start foobar #{instance.id}")

      orphan_disk_output = bosh_runner.run('disks --orphaned')
      expect(cid_from(orphan_disk_output)).to eq(instance.disk_cid)

      instance = director.instances.first
      expect(current_sandbox.cpi.disk_attached_to_vm?(instance.vm_cid, instance.disk_cid)).to eq(true)

      agent_dir = current_sandbox.cpi.agent_dir_for_vm_cid(instance.vm_cid)
      disk_migrations = JSON.parse(File.read("#{agent_dir}/bosh/disk_migrations.json"))
      expect(disk_migrations.count).to eq(1)

      first_disk_migration = disk_migrations.first
      expect(first_disk_migration['FromDiskCid']).to eq('disk-cid-abc123')
      expect(instance.disk_cid).to eq(first_disk_migration['ToDiskCid'])
      expect(current_sandbox.cpi.invocations_for_method('set_disk_metadata').last['inputs']['disk_cid']).to eq(instance.disk_cid)
    end
  end

  context 'deployment has disk that exists in an orphaned list not attached to an instance' do
    before do
      manifest_hash = Bosh::Spec::Deployments.simple_manifest
      deployment_job = Bosh::Spec::Deployments.simple_job(persistent_disk_pool: 'disk_a', instances: 1)
      manifest_hash['jobs'] = [deployment_job]
      cloud_config = Bosh::Spec::Deployments.simple_cloud_config
      cloud_config['disk_pools'] = [Bosh::Spec::Deployments.disk_pool]
      deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)

      bosh_runner.run('delete deployment simple')

      deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)
      @instance = director.instances.first

      orphan_disk_output = bosh_runner.run('disks --orphaned')
      @orphan_disk_cid = cid_from(orphan_disk_output)
    end

    it 'attaches the orphaned disk to a hard stopped instance' do
      expect(@orphan_disk_cid).to_not be_nil
      expect(@instance).to_not be_nil

      bosh_runner.run("stop foobar #{@instance.id} --hard")
      bosh_runner.run("attach disk foobar #{@instance.id} #{@orphan_disk_cid}")
      bosh_runner.run("start foobar #{@instance.id}")

      started_instance = director.instances.first

      expect(current_sandbox.cpi.disk_attached_to_vm?(started_instance.vm_cid, @orphan_disk_cid)).to eq(true)
      expect(current_sandbox.cpi.invocations_for_method('set_disk_metadata').last['inputs']['disk_cid']).to eq(started_instance.disk_cid)
    end

    it 'attaches the orphaned disk to a soft stopped instance' do
      expect(@orphan_disk_cid).to_not be_nil
      expect(@instance).to_not be_nil

      bosh_runner.run("stop foobar #{@instance.id} --soft")
      bosh_runner.run("attach disk foobar #{@instance.id} #{@orphan_disk_cid}")
      bosh_runner.run("start foobar #{@instance.id}")

      started_instance = director.instances.first

      expect(current_sandbox.cpi.disk_attached_to_vm?(started_instance.vm_cid, @orphan_disk_cid)).to eq(true)
      expect(current_sandbox.cpi.invocations_for_method('set_disk_metadata').last['inputs']['disk_cid']).to eq(started_instance.disk_cid)
    end
  end
end
