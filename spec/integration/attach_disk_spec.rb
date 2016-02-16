require 'spec_helper'

describe 'attach disk', type: :integration do
  with_reset_sandbox_before_each

  it 'Attaches a disk to a hard stopped instance' do
    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    manifest_hash['releases'].first['version'] = 'latest'
    manifest_hash['jobs'][0]['instances'] = 1
    manifest_hash['jobs'][0]['persistent_disk'] = 1000
    deploy_from_scratch(manifest_hash: manifest_hash)

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
  end
end
