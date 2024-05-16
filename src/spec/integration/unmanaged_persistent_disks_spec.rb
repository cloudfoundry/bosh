require_relative '../spec_helper'

def upload_multidisk_release
  FileUtils.cp_r(MULTIDISK_RELEASE_TEMPLATE, ClientSandbox.multidisks_release_dir, preserve: true)
  bosh_runner.run_in_dir('create-release --force', ClientSandbox.multidisks_release_dir)
  bosh_runner.run_in_dir('upload-release', ClientSandbox.multidisks_release_dir)
end

describe 'multiple persistent disks', type: :integration do
  with_reset_sandbox_before_each(dummy_cpi_api_version: 2)

  let(:cloud_config_hash) do
    hash = Bosh::Spec::Deployments.simple_cloud_config
    hash['disk_types'] = [
      {
        'name' => 'low-performance-disk-type',
        'disk_size' => low_perf_disk_size,
        'cloud_properties' => {'type' => 'gp2'}
      },
      {
        'name' => 'high-performance-disk-type',
        'disk_size' => high_perf_disk_size,
        'cloud_properties' => {'type' => 'io1'}
      }
    ]
    hash
  end

  let(:high_perf_disk_size) { 4096 }
  let(:low_perf_disk_size) { 1024 }

  let(:manifest_hash) do
    {
      'name' => 'simple',
      'releases' =>[{'name' => 'bosh-release', 'version' => '0.1-dev'}],
      'update' => {
        'canaries' =>2,
        'canary_watch_time' =>4000,
        'max_in_flight' =>1,
        'update_watch_time' =>20
      },
      'instance_groups' => [instance_group],
      'stemcells' => [{
        'name' => 'ubuntu-stemcell',
        'version' => '1',
        'alias' => 'default'
      }],
    }
  end

  let(:instance_group) do
    {
      'name' => 'foobar',
      'jobs' => [
        {
          'name' => 'disk_using_job',
          'release' => 'bosh-release',
          'consumes' => {
            'slow-disk-link-name' => {'from' => 'low-iops-persistent-disk-name'},
            'fast-disk-link-name' => {'from' => 'high-iops-persistent-disk-name'},
          }
        }
      ],
      'vm_type' => 'a',
      'stemcell' => 'default',
      'instances' => 1,
      'networks' => [{'name' => 'a'}],
      'persistent_disks' => [low_iops_persistent_disk, high_iops_persistent_disk]
    }
  end

  let(:low_iops_persistent_disk) do
    {
      'type' => 'low-performance-disk-type',
      'name' => 'low-iops-persistent-disk-name'
    }
  end

  let(:high_iops_persistent_disk) do
    {
      'type' => 'high-performance-disk-type',
      'name' => 'high-iops-persistent-disk-name'
    }
  end

  let(:additional_persistent_disk) do
    {
      'type' => 'low-performance-disk-type',
      'name' => 'additional-persistent-disk-name'
    }
  end

  before do
    upload_multidisk_release
    upload_stemcell

    upload_cloud_config(cloud_config_hash: cloud_config_hash)
    @deploy_output = deploy_simple_manifest(manifest_hash: manifest_hash)
  end

  it 'should attach multiple persistent disks to the VM, add a disk, and delete a disk' do
    vm_cid = director.instances.first.vm_cid
    disk_infos = current_sandbox.cpi.attached_disk_infos(vm_cid)
    expect(disk_infos).to match([
      {
        'size' => 1024,
        'cloud_properties' => {'type' => 'gp2'},
        'vm_locality' => String,
        'disk_cid' => String,
        'device_path' => 'attached'
      },
      {
        'size' => 4096,
        'cloud_properties' => {'type' => 'io1'},
        'vm_locality' => String,
        'disk_cid' => String,
        'device_path' => 'attached'
      }
    ])

    original_disk_cids = disk_infos.map { |disk_info| disk_info['disk_cid'] }

    instance_group['persistent_disks'] = [low_iops_persistent_disk, high_iops_persistent_disk, additional_persistent_disk]
    deploy_simple_manifest(manifest_hash: manifest_hash)

    new_disk_infos = current_sandbox.cpi.attached_disk_infos(vm_cid)
    expect(new_disk_infos).to match([
      {
        'size' => 1024,
        'cloud_properties' => {'type' => 'gp2'},
        'vm_locality' => String,
        'disk_cid' => String,
        'device_path' => 'attached'
      },
      {
        'size' => 4096,
        'cloud_properties' => {'type' => 'io1'},
        'vm_locality' => String,
        'disk_cid' => String,
        'device_path' => 'attached'
      },
      {
        'size' => 1024,
        'cloud_properties' => {'type' => 'gp2'},
        'vm_locality' => String,
        'disk_cid' => String,
        'device_path' => 'attached'
      }
    ])

    additional_disk_cids = new_disk_infos.map { |disk_info| disk_info['disk_cid'] }
    expect(additional_disk_cids).to include(*original_disk_cids)

    instance_group['persistent_disks'] = [low_iops_persistent_disk, high_iops_persistent_disk]
    deploy_simple_manifest(manifest_hash: manifest_hash)

    down_scaled_disk_infos = current_sandbox.cpi.attached_disk_infos(vm_cid)
    expect(down_scaled_disk_infos).to match([
      {
        'size' => 1024,
        'cloud_properties' => {'type' => 'gp2'},
        'vm_locality' => String,
        'disk_cid' => String,
        'device_path' => 'attached'
      },
      {
        'size' => 4096,
        'cloud_properties' => {'type' => 'io1'},
        'vm_locality' => String,
        'disk_cid' => String,
        'device_path' => 'attached'
      }
    ])

    expect(down_scaled_disk_infos.map { |disk_info| disk_info['disk_cid'] }).to eq(original_disk_cids)
  end

  it 'provides links for the persistent disks' do
    instance = director.instances.first
    template_content = instance.read_job_template('disk_using_job', 'disknames.json')
    expect(JSON.parse(template_content)).to eq({
      'slow-disk' => {'name' => 'low-iops-persistent-disk-name'},
      'fast-disk' => {'name' => 'high-iops-persistent-disk-name'}
    })
  end

  it 'notifies the agent of the name and volume information' do
    agent_dir = current_sandbox.cpi.agent_dir_for_vm_cid(director.instances.first.vm_cid)

    disk_names = JSON.parse(File.read("#{agent_dir}/bosh/disk_associations.json"))
    expect(disk_names).to contain_exactly(
      'high-iops-persistent-disk-name', 'low-iops-persistent-disk-name'
    )
  end

  it 'retains the correct disks after recreating the vm' do
    bosh_runner.run("recreate disk_using_job", manifest_hash: manifest_hash, deployment_name: 'simple')

    agent_dir = current_sandbox.cpi.agent_dir_for_vm_cid(director.instances.first.vm_cid)

    disk_names = JSON.parse(File.read("#{agent_dir}/bosh/disk_associations.json"))
    expect(disk_names).to contain_exactly(
      'high-iops-persistent-disk-name', 'low-iops-persistent-disk-name'
    )
  end

  it 'does not mount anything' do
    agent_dir = current_sandbox.cpi.agent_dir_for_vm_cid(director.instances.first.vm_cid)

    expect(File.exist?("#{agent_dir}/bosh/mounts.json")).to eq(false)
  end

  it 'does not mount anything even when disk is formatted and mountable' do
    vm_cid = director.instances.first.vm_cid
    agent_dir = current_sandbox.cpi.agent_dir_for_vm_cid(vm_cid)
    first_disk_cid = current_sandbox.cpi.attached_disk_infos(vm_cid).first['disk_cid']
    File.open("#{agent_dir}/bosh/formatted_disks.json", 'w') { |f| f.write("[{\"DiskCid\":\"#{first_disk_cid}\"}]") }

    agent_id = /agent-base-dir-(.*)/.match(current_sandbox.cpi.agent_dir_for_vm_cid(vm_cid))[1]
    director.instances.first.kill_agent
    current_sandbox.cpi.spawn_agent_process(agent_id)
    agent_dir = current_sandbox.cpi.agent_dir_for_vm_cid(vm_cid)
    # Allow restarted agent process time to start
    sleep 1

    expect(File.exist?("#{agent_dir}/bosh/mounts.json")).to eq(false)
  end

  it 'maintains existing symlinks when new disks are added' do
    instance_group['persistent_disks'] = [low_iops_persistent_disk, high_iops_persistent_disk, additional_persistent_disk]
    manifest_hash['instance_groups'] = [instance_group]

    deploy_simple_manifest(manifest_hash: manifest_hash)

    agent_dir = current_sandbox.cpi.agent_dir_for_vm_cid(director.instances.first.vm_cid)

    disk_names = JSON.parse(File.read("#{agent_dir}/bosh/disk_associations.json"))
    expect(disk_names).to include(
      'high-iops-persistent-disk-name', 'low-iops-persistent-disk-name', 'additional-persistent-disk-name'
    )
  end

  it 'director should send add_persistent_disk action to agent' do
    agent_dir = current_sandbox.cpi.agent_dir_for_vm_cid(director.instances.first.vm_cid)

    disk_names = JSON.parse(File.read("#{agent_dir}/bosh/disk_associations.json"))
    expect(disk_names).to include(
      'high-iops-persistent-disk-name', 'low-iops-persistent-disk-name'
    )

    disk_hints = JSON.parse(File.read("#{agent_dir}/bosh/persistent_disk_hints.json"))
    expect(disk_hints.count).to eq(2)
    disk_hints_cids = disk_hints.keys

    attached_disks = current_sandbox.cpi.attached_disk_infos(director.instances.first.vm_cid)
    attached_disks_cids = attached_disks.collect { |d| d['disk_cid'] }
    expect(attached_disks_cids).to match_array(disk_hints_cids)
  end

  context 'when CPI is v1' do
    with_reset_sandbox_before_each(dummy_cpi_api_version: 1)

    before do
      upload_multidisk_release
      upload_stemcell

      upload_cloud_config(cloud_config_hash: cloud_config_hash)
      @deploy_output = deploy_simple_manifest(manifest_hash: manifest_hash)
    end

    it 'director should not send add_persistent_disk action to agent' do
      agent_dir = current_sandbox.cpi.agent_dir_for_vm_cid(director.instances.first.vm_cid)

      disk_names = JSON.parse(File.read("#{agent_dir}/bosh/disk_associations.json"))
      expect(disk_names).to include(
        'high-iops-persistent-disk-name', 'low-iops-persistent-disk-name'
      )

      v2_only_disk_settings_file = "#{agent_dir}/bosh/persistent_disk_hints.json"
      expect(File.exist?(v2_only_disk_settings_file)).to be_falsey
    end
  end
end
