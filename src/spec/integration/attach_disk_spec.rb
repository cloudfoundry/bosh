require 'spec_helper'

describe 'attach disk', type: :integration do
  with_reset_sandbox_before_each

  def assert_cpi_attach_disk_context(invocations_count)
    cpi_invocations = current_sandbox.cpi.invocations_for_method('attach_disk')

    expect(cpi_invocations.count).to eq(invocations_count)
    cpi_invocations.each do |attach_disk_invocation|
      expect(attach_disk_invocation.method_name).to eq('attach_disk')
      expect(attach_disk_invocation.context).to match({
                                                        'director_uuid' => kind_of(String),
                                                        'request_id' => kind_of(String),
                                                        'vm' => {
                                                          'stemcell' => {
                                                            'api_version' => 25
                                                          }
                                                        }
                                                      })
    end
  end

  let(:simple_manifest) do
    manifest_hash = Bosh::Spec::Deployments.simple_manifest_with_instance_groups
    manifest_hash['releases'].first['version'] = 'latest'
    manifest_hash['instance_groups'][0]['instances'] = 1
    manifest_hash['instance_groups'][0]['persistent_disk'] = 1000
    manifest_hash
  end

  let(:deployment_name) { simple_manifest['name'] }

  context 'deployment has disk that does not exist in an orphaned list attached to an instance' do

    before do
      bosh_runner.run("upload-stemcell #{asset_path('valid_stemcell_with_api_version.tgz')}")
      upload_cloud_config(cloud_config_hash: Bosh::Spec::Deployments.simple_cloud_config)
      create_and_upload_test_release

      deploy(manifest_hash: simple_manifest)
    end

    it 'attaches the disk to a hard stopped instance' do
      instance = director.instances.first

      bosh_runner.run("stop foobar/#{instance.id} --hard", deployment_name: deployment_name)
      bosh_runner.run("attach-disk foobar/#{instance.id} disk-cid-abc123", deployment_name: deployment_name)
      bosh_runner.run("start foobar/#{instance.id}", deployment_name: deployment_name)

      instance = director.instances.first

      expect(current_sandbox.cpi.disk_attached_to_vm?(instance.vm_cid, instance.disk_cids[0])).to eq(true)

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
      expect(instance.disk_cids[0]).to eq(first_disk_migration['ToDiskCid'])
      expect(current_sandbox.cpi.invocations_for_method('set_disk_metadata').last['inputs']['disk_cid']).to eq(instance.disk_cids[0])
      assert_cpi_attach_disk_context(3)
    end

    it 'attaches the disk to a soft stopped instance' do
      instance = director.instances.first

      bosh_runner.run("stop foobar/#{instance.id} --soft", deployment_name: deployment_name)
      bosh_runner.run("attach-disk foobar/#{instance.id} disk-cid-abc123", deployment_name: deployment_name)
      bosh_runner.run("start foobar/#{instance.id}", deployment_name: deployment_name)

      orphan_disk_output = bosh_runner.run('disks --orphaned')
      expect(cid_from(orphan_disk_output)).to eq(instance.disk_cids[0])

      instance = director.instances.first
      expect(current_sandbox.cpi.disk_attached_to_vm?(instance.vm_cid, instance.disk_cids[0])).to eq(true)

      agent_dir = current_sandbox.cpi.agent_dir_for_vm_cid(instance.vm_cid)
      disk_migrations = JSON.parse(File.read("#{agent_dir}/bosh/disk_migrations.json"))
      expect(disk_migrations.count).to eq(1)

      first_disk_migration = disk_migrations.first
      expect(first_disk_migration['FromDiskCid']).to eq('disk-cid-abc123')
      expect(instance.disk_cids[0]).to eq(first_disk_migration['ToDiskCid'])
      expect(current_sandbox.cpi.invocations_for_method('set_disk_metadata').last['inputs']['disk_cid']).to eq(instance.disk_cids[0])
      assert_cpi_attach_disk_context(3)
    end
  end

  context 'when deployment has an orphaned disk that was previously attached to an instance' do
    before do
      bosh_runner.run("upload-stemcell #{asset_path('valid_stemcell_with_api_version.tgz')}")

      manifest_hash = Bosh::Spec::Deployments.simple_manifest_with_instance_groups
      instance_group = Bosh::Spec::Deployments.simple_instance_group(persistent_disk_type: 'disk_a', instances: 1)
      manifest_hash['instance_groups'] = [instance_group]
      cloud_config = Bosh::Spec::Deployments.simple_cloud_config
      cloud_config['disk_types'] = [Bosh::Spec::Deployments.disk_type]
      upload_cloud_config(cloud_config_hash: Bosh::Spec::Deployments.simple_cloud_config)
      create_and_upload_test_release
      deploy(manifest_hash: simple_manifest)

      bosh_runner.run('delete-deployment', deployment_name: deployment_name)

      deploy(manifest_hash: simple_manifest)
      @instance = director.instances.first

      orphan_disk_output = bosh_runner.run('disks --orphaned')
      @orphan_disk_cid = cid_from(orphan_disk_output)
    end

    it 'attaches the orphaned disk to a hard stopped instance' do
      expect(@orphan_disk_cid).to_not be_nil
      expect(@instance).to_not be_nil

      bosh_runner.run("stop foobar/#{@instance.id} --hard", deployment_name: deployment_name)
      bosh_runner.run("attach-disk foobar/#{@instance.id} #{@orphan_disk_cid}", deployment_name: deployment_name)
      bosh_runner.run("start foobar/#{@instance.id}", deployment_name: deployment_name)

      started_instance = director.instances.first

      expect(current_sandbox.cpi.disk_attached_to_vm?(started_instance.vm_cid, @orphan_disk_cid)).to eq(true)
      expect(current_sandbox.cpi.invocations_for_method('set_disk_metadata').last['inputs']['disk_cid']).to eq(@orphan_disk_cid)

      assert_cpi_attach_disk_context(3)
    end

    it 'attaches the orphaned disk to a soft stopped instance' do
      expect(@orphan_disk_cid).to_not be_nil
      expect(@instance).to_not be_nil

      bosh_runner.run("stop foobar/#{@instance.id} --soft", deployment_name: deployment_name)
      bosh_runner.run("attach-disk foobar/#{@instance.id} #{@orphan_disk_cid}", deployment_name: deployment_name)
      bosh_runner.run("start foobar/#{@instance.id}", deployment_name: deployment_name)

      started_instance = director.instances.first

      expect(current_sandbox.cpi.disk_attached_to_vm?(started_instance.vm_cid, @orphan_disk_cid)).to eq(true)
      expect(current_sandbox.cpi.invocations_for_method('set_disk_metadata').last['inputs']['disk_cid']).to eq(@orphan_disk_cid)

      assert_cpi_attach_disk_context(3)
    end
  end
end
