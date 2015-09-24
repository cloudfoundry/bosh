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
      job_spec = etcd_job
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
        etcd_z1_job,
        etcd_z2_job,
      ]
      legacy_manifest
    end

    let(:etcd_z1_job) do
      Bosh::Spec::Deployments.simple_job(instances: 1, name: 'etcd_z1', persistent_disk_pool: 'fast_disks')
    end
    let(:etcd_z2_job) do
      Bosh::Spec::Deployments.simple_job(instances: 1, name: 'etcd_z2', persistent_disk_pool: 'fast_disks')
    end
    let(:etcd_job) do
      Bosh::Spec::Deployments.simple_job(instances: 2, name: 'etcd', persistent_disk_pool: 'fast_disks')
    end

    context 'when using same static reservation' do
      let(:etcd_z1_job) do
        Bosh::Spec::Deployments.simple_job(instances: 1, name: 'etcd_z1', static_ips: ['192.168.1.10'], persistent_disk_pool: 'fast_disks')
      end
      let(:etcd_z2_job) do
        Bosh::Spec::Deployments.simple_job(instances: 1, name: 'etcd_z2', static_ips: ['192.168.2.10'], persistent_disk_pool: 'fast_disks')
      end
      let(:etcd_job) do
        Bosh::Spec::Deployments.simple_job(instances: 2, name: 'etcd', static_ips: ['192.168.1.10', '192.168.2.10'], persistent_disk_pool: 'fast_disks')
      end

      it 'keeps VM, disk and IPs' do
        deploy_from_scratch(legacy: true, manifest_hash: legacy_manifest)
        original_vms = director.vms
        original_disks = current_sandbox.cpi.disk_cids
        expect(original_vms.map(&:job_name)).to match_array(['etcd_z1', 'etcd_z2'])

        upload_cloud_config(cloud_config_hash: cloud_config_hash_with_azs)
        deploy_simple_manifest(manifest_hash: manifest_with_azs)

        new_vms = director.vms
        expect(new_vms.map(&:job_name)).to eq(['etcd'])

        expect(new_vms.map(&:ips)).to match_array(['192.168.1.10', '192.168.2.10'])
        expect(new_vms.map(&:cid)).to match_array(original_vms.map(&:cid))

        new_disks = current_sandbox.cpi.disk_cids
        expect(new_disks).to match_array(original_disks)
      end
    end

    context 'when templates of migrated jobs are different from desired job' do
      let(:etcd_job) do
        Bosh::Spec::Deployments.simple_job(instances: 2, name: 'etcd', persistent_disk_pool: 'fast_disks', templates: [{'name' => 'foobar_without_packages'}])
      end

      it 'updates job instances with new desired job templates keeping persistent disk' do
        deploy_from_scratch(legacy: true, manifest_hash: legacy_manifest)
        original_vms = director.vms
        original_disks = current_sandbox.cpi.disk_cids
        expect(original_vms.map(&:job_name)).to match_array(['etcd_z1', 'etcd_z2'])

        upload_cloud_config(cloud_config_hash: cloud_config_hash_with_azs)
        deploy_simple_manifest(manifest_hash: manifest_with_azs)

        new_vms = director.vms
        expect(new_vms.map(&:job_name)).to eq(['etcd', 'etcd'])

        expect(new_vms.map(&:cid)).to match_array(original_vms.map(&:cid))

        new_disks = current_sandbox.cpi.disk_cids
        expect(new_disks).to match_array(original_disks)

        new_vms.each do |new_vm|
          template = new_vm.read_job_template('foobar_without_packages', 'bin/foobar_ctl')
          expect(template).to include('job_name=etcd')
          expect(template).to include('templates=foobar_without_packages')
        end
      end
    end

    context 'when instance network configuration changed' do
      let(:etcd_job) do
        Bosh::Spec::Deployments.simple_job(instances: 2, name: 'etcd', static_ips: ['192.168.1.10', '192.168.2.10'], persistent_disk_pool: 'fast_disks')
      end
      it 'recreates VM keeping persistent disk' do
        deploy_from_scratch(legacy: true, manifest_hash: legacy_manifest)
        original_vms = director.vms
        original_disks = current_sandbox.cpi.disk_cids
        expect(original_vms.map(&:job_name)).to match_array(['etcd_z1', 'etcd_z2'])

        upload_cloud_config(cloud_config_hash: cloud_config_hash_with_azs)
        deploy_simple_manifest(manifest_hash: manifest_with_azs)

        new_vms = director.vms
        expect(new_vms.map(&:job_name)).to eq(['etcd','etcd'])

        expect(new_vms.map(&:ips)).to match_array(['192.168.1.10', '192.168.2.10'])
        expect(new_vms.map(&:cid)).not_to match_array(original_vms.map(&:cid))

        new_disks = current_sandbox.cpi.disk_cids
        expect(new_disks).to eq(original_disks)
      end
    end

    context 'when instance resource pool configuration changed' do
      it 'recreates VM keeping persistent disk' do

      end
    end

    context 'when number of migrated instances is greater than number of instances in new job' do
      let(:etcd_z1_job) do
        Bosh::Spec::Deployments.simple_job(instances: 2, name: 'etcd_z1', persistent_disk_pool: 'fast_disks')
      end

      it 'deletes extra instances' do
        deploy_from_scratch(legacy: true, manifest_hash: legacy_manifest)
        original_vms = director.vms
        original_disks = current_sandbox.cpi.disk_cids
        expect(original_vms.size).to eq(3)
        expect(original_disks.size).to eq(3)
        expect(original_vms.map(&:job_name)).to match_array(['etcd_z1', 'etcd_z1', 'etcd_z2'])

        upload_cloud_config(cloud_config_hash: cloud_config_hash_with_azs)
        deploy_simple_manifest(manifest_hash: manifest_with_azs)

        new_vms = director.vms
        expect(new_vms.size).to eq(2)
        expect(new_vms.map(&:job_name)).to eq(['etcd', 'etcd'])

        expect(original_vms.map(&:cid)).to include(*new_vms.map(&:cid))

        new_disks = current_sandbox.cpi.disk_cids
        expect(new_disks.size).to eq(2)
        expect(original_disks).to include(*new_disks)
      end
    end

    context 'when number of migrated instances is less than number of instances in new job' do
      let(:etcd_job) do
        Bosh::Spec::Deployments.simple_job(instances: 3, name: 'etcd', persistent_disk_pool: 'fast_disks')
      end

      it 'creates extra instances' do
        deploy_from_scratch(legacy: true, manifest_hash: legacy_manifest)
        original_vms = director.vms
        original_disks = current_sandbox.cpi.disk_cids
        expect(original_vms.size).to eq(2)
        expect(original_disks.size).to eq(2)
        expect(original_vms.map(&:job_name)).to match_array(['etcd_z1', 'etcd_z2'])

        upload_cloud_config(cloud_config_hash: cloud_config_hash_with_azs)
        deploy_simple_manifest(manifest_hash: manifest_with_azs)

        new_vms = director.vms
        expect(new_vms.size).to eq(3)
        expect(new_vms.map(&:job_name)).to eq(['etcd', 'etcd', 'etcd'])

        expect(new_vms.map(&:cid)).to include(*original_vms.map(&:cid))

        new_disks = current_sandbox.cpi.disk_cids
        expect(new_disks.size).to eq(3)
        expect(new_disks).to include(*original_disks)
      end
    end
  end

  context 'when migrating into existing job' do
    it 'preserves existing job instances and migrated job instances' do

    end
  end

  context 'when migrating with availability zones' do

  end

  context 'when migrating job that was already migrated' do
    context 'when migrated_from is the same'
    context 'when migrated_from is not the same'
  end
end
