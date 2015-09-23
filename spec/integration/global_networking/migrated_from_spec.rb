require 'spec_helper'

describe 'migrated from', type: :integration do
  with_reset_sandbox_before_each

  before do
    target_and_login
    create_and_upload_test_release
    upload_stemcell
  end

  context 'when migrating to availability zones' do
    let(:cloud_config_hash_with_azs) do
      cloud_config_hash = Bosh::Spec::Deployments.simple_cloud_config
      cloud_config_hash['availability_zones'] = [
        { 'name' => 'my-az-1'},
        { 'name' => 'my-az-2'}
      ]
      cloud_config_hash['networks'].first['subnets'] = [subnet_with_az1, subnet_with_az2]
      cloud_config_hash['disk_pools'] = [disk_pool_spec]

      cloud_config_hash
    end

    let(:subnet1) do
      {
        'range' => '192.168.1.0/24',
        'gateway' => '192.168.1.1',
        'dns' => ['192.168.1.1', '192.168.1.2'],
        'reserved' => [],
        'static' => ['192.168.1.10'],
        'cloud_properties' => {},
      }
    end

    let(:subnet_with_az1) do
      subnet1.merge('availability_zone' => 'my-az-1')
    end

    let(:subnet2) do
      {
        'range' => '192.168.2.0/24',
        'gateway' => '192.168.2.1',
        'dns' => ['192.168.2.1', '192.168.2.2'],
        'reserved' => [],
        'static' => ['192.168.2.10'],
        'cloud_properties' => {},
      }
    end

    let(:subnet_with_az2) do
      subnet2.merge('availability_zone' => 'my-az-2')
    end

    let(:manifest_with_azs) do
      manifest_hash = Bosh::Spec::Deployments.simple_manifest
      job_spec = Bosh::Spec::Deployments.simple_job(instances: 2, name: 'etcd', static_ips: ['192.168.1.10', '192.168.2.10'], persistent_disk_pool: 'fast_disks')
      job_spec['networks'].first['name'] = cloud_config_hash_with_azs['networks'].first['name']
      job_spec['availability_zones'] = ['my-az-1', 'my-az-2']
      job_spec['migrated_from'] = [
        {'name' => 'etcd_z1', 'az' => 'my-az-1'},
        {'name' => 'etcd_z2', 'az' => 'my-az-2'}
      ]
      manifest_hash['jobs'] = [job_spec]
      manifest_hash
    end

    let(:disk_pool_spec) do
      {
        'name' => 'fast_disks',
        'disk_size' => 1024,
        'cloud_properties' => {}
      }
    end

    let(:legacy_manifest) do
      legacy_manifest = Bosh::Spec::Deployments.legacy_manifest
      legacy_manifest['networks'].first['subnets'] = [subnet1, subnet2]
      legacy_manifest['disk_pools'] = [disk_pool_spec]
      legacy_manifest['jobs'] = [
        Bosh::Spec::Deployments.simple_job(instances: 1, name: 'etcd_z1', static_ips: ['192.168.1.10'], persistent_disk_pool: 'fast_disks'),
        Bosh::Spec::Deployments.simple_job(instances: 1, name: 'etcd_z2', static_ips: ['192.168.2.10'], persistent_disk_pool: 'fast_disks')
      ]
      legacy_manifest
    end

    it 'when VM has no changes (same network and resource pool configuration) it does not recreate VM and disk' do
      deploy_from_scratch(legacy: true, manifest_hash: legacy_manifest)
      original_vms = director.vms
      original_disks = current_sandbox.cpi.disk_cids
      expect(original_vms[0].job_name).to eq('etcd_z1')
      expect(original_vms[1].job_name).to eq('etcd_z2')

      upload_cloud_config(cloud_config_hash: cloud_config_hash_with_azs)
      deploy_simple_manifest(manifest_hash: manifest_with_azs)

      new_vms = director.vms
      expect(new_vms[0].job_name).to eq('etcd')
      expect(new_vms[1].job_name).to eq('etcd')

      expect(new_vms.map(&:ips)).to match_array(['192.168.1.10', '192.168.2.10'])
      expect(new_vms.map(&:cid)).to match_array(original_vms.map(&:cid))

      new_disks = current_sandbox.cpi.disk_cids
      expect(new_disks).to eq(original_disks)
    end

    context 'when migrating using dynamic networks' do
      it 'keeps VM ips' do

      end
    end

    context 'when templates of migrated jobs are different from desired job' do
      it 'updates job instances with new desired job templates keeping persistent disk' do

      end
    end

    context 'when instance network configuration changed' do
      it 'recreates VM keeping persistent disk' do

      end
    end

    context 'when instance resource pool configuration changed' do
      it 'recreates VM keeping persistent disk' do

      end
    end

    context 'when number of migrated instances is greater than number of instances in new job' do
      it 'deletes extra instances' do

      end
    end

    context 'when number of migrated instances is less than number of instances in new job' do
      it 'creates extra instances' do

      end
    end

    context 'when number of static IPs in new job less than required by migrated instances' do
      it 'fails' do

      end
    end
  end

  context 'when migrating into existing job' do
    context 'when number of migrated job instances exceed the number of job instances' do
      it 'preserves existing job instanced and deletes extra migrated job instances' do

      end
    end
  end

  context 'when migrating with availability zones' do

  end

  context 'when migrating job that was already migrated' do
    context 'when migrated_from is the same'
    context 'when migrated_from is not the same'
  end
end
