require 'spec_helper'

describe 'migrated from', type: :integration do
  with_reset_sandbox_before_each

  before do
    target_and_login
    create_and_upload_test_release
    upload_stemcell
  end

  let(:cloud_config_hash_with_azs) do
    cloud_config_hash = Bosh::Spec::Deployments.simple_cloud_config
    cloud_config_hash['availability_zones'] = [
      { 'name' => 'my-az-1' },
      { 'name' => 'my-az-2' }
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
    job_spec['migrated_from'] = [{'name' => 'etcd_z1', 'az' => 'my-az-1'},{'name' => 'etcd_z2', 'az' => 'my-az-2'}]
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

  let(:etcd_z1_job) do
    Bosh::Spec::Deployments.simple_job(instances: 1, name: 'etcd_z1', persistent_disk_pool: 'fast_disks')
  end
  let(:etcd_z2_job) do
    Bosh::Spec::Deployments.simple_job(instances: 1, name: 'etcd_z2', persistent_disk_pool: 'fast_disks')
  end
  let(:etcd_job) do
    Bosh::Spec::Deployments.simple_job(instances: 2, name: 'etcd', persistent_disk_pool: 'fast_disks')
  end

  context 'when migrating to availability zones' do
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

    def migrate_legacy_etcd_z1_and_z2
      deploy_from_scratch(legacy: true, manifest_hash: legacy_manifest)
      original_vms = director.vms
      original_disks = current_sandbox.cpi.disk_cids
      expect(original_vms.map(&:job_name)).to match_array(['etcd_z1', 'etcd_z2'])

      upload_cloud_config(cloud_config_hash: cloud_config_hash_with_azs)
      deploy_simple_manifest(manifest_hash: manifest_with_azs)

      [original_vms, original_disks]
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

      it 'keeps VM, disk and IPs and updates AZs' do
        original_vms, original_disks = migrate_legacy_etcd_z1_and_z2

        new_vms = director.vms
        expect(new_vms.map(&:job_name)).to eq(['etcd','etcd'])

        expect(new_vms.map(&:ips)).to match_array(['192.168.1.10', '192.168.2.10'])
        expect(new_vms.map(&:cid)).to match_array(original_vms.map(&:cid))
        expect(new_vms.map(&:availability_zone)).to match_array(['my-az-1', 'my-az-2'])

        new_disks = current_sandbox.cpi.disk_cids
        expect(new_disks).to match_array(original_disks)
      end
    end

    context 'when using dynamic reservation without any other changes' do
      let(:etcd_z1_job) do
        Bosh::Spec::Deployments.simple_job(instances: 1, name: 'etcd_z1', persistent_disk_pool: 'fast_disks')
      end
      let(:etcd_z2_job) do
        Bosh::Spec::Deployments.simple_job(instances: 1, name: 'etcd_z2', persistent_disk_pool: 'fast_disks')
      end
      let(:etcd_job) do
        Bosh::Spec::Deployments.simple_job(instances: 2, name: 'etcd', persistent_disk_pool: 'fast_disks')
      end

      it 'keeps VM, disk and IPs and updates AZs' do
        original_vms, original_disks = migrate_legacy_etcd_z1_and_z2

        new_vms = director.vms
        expect(new_vms.map(&:job_name)).to eq(['etcd','etcd'])

        expect(new_vms.map(&:ips)).to match_array(original_vms.map(&:ips))
        expect(new_vms.map(&:cid)).to match_array(original_vms.map(&:cid))
        expect(new_vms.map(&:availability_zone)).to match_array(['my-az-1', 'my-az-2'])

        new_disks = current_sandbox.cpi.disk_cids
        expect(new_disks).to match_array(original_disks)
      end
    end

    context 'when templates of migrated jobs are different from desired job' do
      let(:etcd_job) do
        Bosh::Spec::Deployments.simple_job(instances: 2, name: 'etcd', persistent_disk_pool: 'fast_disks', templates: [{'name' => 'foobar_without_packages'}])
      end

      it 'updates job instances with new desired job templates keeping persistent disk' do
        original_vms, original_disks = migrate_legacy_etcd_z1_and_z2

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

    context 'when instance network configuration changed (from dynamic to static)' do
      let(:etcd_job) do
        Bosh::Spec::Deployments.simple_job(instances: 2, name: 'etcd', static_ips: ['192.168.1.10', '192.168.2.10'], persistent_disk_pool: 'fast_disks')
      end

      it 'recreates VM keeping persistent disk' do
        original_vms, original_disks = migrate_legacy_etcd_z1_and_z2

        new_vms = director.vms
        expect(new_vms.map(&:job_name)).to eq(['etcd','etcd'])

        expect(new_vms.map(&:ips)).to match_array(['192.168.1.10', '192.168.2.10'])
        expect(new_vms.map(&:cid)).not_to match_array(original_vms.map(&:cid))

        new_disks = current_sandbox.cpi.disk_cids
        expect(new_disks).to match_array(original_disks)
      end
    end

    context 'when instance resource pool configuration changed' do
      before do
        cloud_config_hash_with_azs['resource_pools'].first['cloud_properties'] = {
          'new-cloud-property-key' => 'new-cloud-property-value'
        }
      end

      it 'recreates VM keeping persistent disk' do
        original_vms, original_disks = migrate_legacy_etcd_z1_and_z2

        new_vms = director.vms
        expect(new_vms.map(&:job_name)).to eq(['etcd','etcd'])

        expect(new_vms.map(&:cid)).not_to match_array(original_vms.map(&:cid))

        new_disks = current_sandbox.cpi.disk_cids
        expect(new_disks).to match_array(original_disks)

        new_vms.each do |new_vm|
          expect(current_sandbox.cpi.read_cloud_properties(new_vm.cid)).to eq({
            'new-cloud-property-key' => 'new-cloud-property-value'
          })
        end
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
        original_vms, original_disks = migrate_legacy_etcd_z1_and_z2

        new_vms = director.vms
        expect(new_vms.size).to eq(3)
        expect(new_vms.map(&:job_name)).to eq(['etcd', 'etcd', 'etcd'])

        expect(new_vms.map(&:cid)).to include(*original_vms.map(&:cid))

        new_disks = current_sandbox.cpi.disk_cids
        expect(new_disks.size).to eq(3)
        expect(new_disks).to include(*original_disks)
      end
    end

    context 'when migrating without persistent disks' do
      let(:etcd_z1_job) do
        Bosh::Spec::Deployments.simple_job(instances: 2, name: 'etcd_z1')
      end
      let(:etcd_job) do
        Bosh::Spec::Deployments.simple_job(instances: 2, name: 'etcd')
      end

      it 'balances vms across azs' do
        manifest_with_azs = Bosh::Spec::Deployments.simple_manifest
        job_spec_z1_1 = etcd_z1_job
        job_spec_z1_1['availability_zones'] = ['my-az-1']
        job_spec_z1_1['networks'].first['name'] = cloud_config_hash_with_azs['networks'].first['name']
        manifest_with_azs['jobs'] = [etcd_z1_job]

        deploy_from_scratch(manifest_hash: manifest_with_azs, cloud_config_hash: cloud_config_hash_with_azs)

        original_vms = director.vms
        expect(original_vms.size).to eq(2)
        expect(original_vms.map(&:job_name)).to match_array(['etcd_z1', 'etcd_z1'])
        expect(original_vms.map(&:availability_zone)).to match_array(['my-az-1', 'my-az-1'])

        new_manifest_hash = Bosh::Spec::Deployments.simple_manifest
        job_spec = etcd_job
        job_spec['networks'].first['name'] = cloud_config_hash_with_azs['networks'].first['name']
        job_spec['availability_zones'] = ['my-az-1', 'my-az-2']
        job_spec['migrated_from'] = [{'name' => 'etcd_z1', 'az' => 'my-az-1'}]
        new_manifest_hash['jobs'] = [job_spec]

        deploy_simple_manifest(manifest_hash: new_manifest_hash)
        new_vms = director.vms
        expect(new_vms.size).to eq(2)
        expect(new_vms.map(&:job_name)).to match_array(['etcd', 'etcd'])
        expect(new_vms.map(&:availability_zone)).to match_array(['my-az-1', 'my-az-2'])
        vm_in_z1 = original_vms.find { |vm| vm.availability_zone == 'my-az-1' }
        expect(original_vms.map(&:cid)).to include(vm_in_z1.cid)
      end
    end
  end

  context 'when migrating with availability zones' do
    context 'when migrating into new job in different az' do
      it 'recreates VM and disk in new az' do
        original_manifest_with_azs = Bosh::Spec::Deployments.simple_manifest
        job_spec = etcd_z1_job
        job_spec['availability_zones'] = ['my-az-1']
        job_spec['networks'].first['name'] = cloud_config_hash_with_azs['networks'].first['name']
        original_manifest_with_azs['jobs'] = [job_spec]

        deploy_from_scratch(manifest_hash: original_manifest_with_azs, cloud_config_hash: cloud_config_hash_with_azs)
        original_vms = director.vms
        expect(original_vms.size).to eq(1)
        expect(original_vms.map(&:job_name)).to match_array(['etcd_z1'])
        expect(original_vms.map(&:availability_zone)).to match_array(['my-az-1'])
        original_disks = current_sandbox.cpi.disk_cids

        new_manifest_hash = original_manifest_with_azs
        job_spec = etcd_z2_job
        job_spec['networks'].first['name'] = cloud_config_hash_with_azs['networks'].first['name']
        job_spec['availability_zones'] = ['my-az-2']
        job_spec['migrated_from'] = [{'name' => 'etcd_z1'}]
        new_manifest_hash['jobs'] = [job_spec]

        deploy_simple_manifest(manifest_hash: new_manifest_hash)
        new_vms = director.vms
        expect(new_vms.size).to eq(1)
        expect(new_vms.map(&:job_name)).to match_array(['etcd_z2'])
        expect(new_vms.map(&:availability_zone)).to match_array(['my-az-2'])
        new_disks = current_sandbox.cpi.disk_cids
        expect(new_disks).to_not match_array(original_disks)
      end
    end

    context 'when migrating into existing job' do
      it 'preserves existing job instances and migrated job instances keeping disks' do
        manifest_with_azs = Bosh::Spec::Deployments.simple_manifest
        job_spec_1 = etcd_job
        job_spec_1['networks'].first['name'] = cloud_config_hash_with_azs['networks'].first['name']
        job_spec_1['instances'] = 1
        job_spec_1['availability_zones'] = ['my-az-1']
        job_spec_2 = etcd_z1_job
        job_spec_2['networks'].first['name'] = cloud_config_hash_with_azs['networks'].first['name']
        job_spec_2['instances'] = 1
        job_spec_2['availability_zones'] = ['my-az-2']
        manifest_with_azs['jobs'] = [job_spec_1, job_spec_2]

        deploy_from_scratch(manifest_hash: manifest_with_azs, cloud_config_hash: cloud_config_hash_with_azs)
        original_vms = director.vms
        expect(original_vms.size).to eq(2)
        expect(original_vms.map(&:job_name)).to match_array(['etcd_z1', 'etcd'])
        original_disks = current_sandbox.cpi.disk_cids

        job_spec_1['availability_zones'] = ['my-az-1', 'my-az-2']
        job_spec_1['migrated_from'] = [{'name' => 'etcd_z1'}]
        job_spec_1['networks'].first['name'] = cloud_config_hash_with_azs['networks'].first['name']
        job_spec_1['instances'] = 2
        manifest_with_azs['jobs'] = [job_spec_1]

        deploy_simple_manifest(manifest_hash: manifest_with_azs)
        new_vms = director.vms
        expect(new_vms.size).to eq(2)
        expect(new_vms.map(&:job_name)).to match_array(['etcd', 'etcd'])
        new_disks = current_sandbox.cpi.disk_cids
        expect(new_disks).to match_array(original_disks)
      end
    end
  end

  it 'updates dns records', dns: true do
    original_manifest_with_azs = Bosh::Spec::Deployments.simple_manifest
    job_spec = etcd_z1_job
    job_spec['availability_zones'] = ['my-az-1']
    job_spec['networks'].first['name'] = cloud_config_hash_with_azs['networks'].first['name']
    original_manifest_with_azs['jobs'] = [job_spec]

    deploy_from_scratch(manifest_hash: original_manifest_with_azs, cloud_config_hash: cloud_config_hash_with_azs)
    output = bosh_runner.run('vms --dns')
    expect(output).to include('0.etcd-z1.a.simple.bosh')
    expect(scrub_random_ids(output)).to include('xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx.etcd-z1.a.simple.bosh')

    new_manifest_hash = original_manifest_with_azs
    job_spec = etcd_job
    job_spec['instances'] = 1
    job_spec['networks'].first['name'] = cloud_config_hash_with_azs['networks'].first['name']
    job_spec['availability_zones'] = ['my-az-1']
    job_spec['migrated_from'] = [{'name' => 'etcd_z1'}]
    new_manifest_hash['jobs'] = [job_spec]

    deploy_simple_manifest(manifest_hash: new_manifest_hash)
    output = bosh_runner.run('vms --dns')
    expect(output).to include('0.etcd.a.simple.bosh')
    expect(scrub_random_ids(output)).to include('xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx.etcd.a.simple.bosh')
    expect(output).to_not include('0.etcd-z1.a.simple.bosh')
    expect(scrub_random_ids(output)).to_not include('xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx.etcd-z1.a.simple.bosh')
  end

  context 'when migrating job that was already migrated' do
    context 'when migrated_from is the same'
    context 'when migrated_from is not the same'
  end
end
