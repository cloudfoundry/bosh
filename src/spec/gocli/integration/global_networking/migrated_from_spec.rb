require_relative '../../spec_helper'

describe 'migrated from', type: :integration do
  with_reset_sandbox_before_each

  let(:cloud_config_hash) do
    cloud_config_hash = Bosh::Spec::NewDeployments.simple_cloud_config
    cloud_config_hash['networks'].first['subnets'] = [subnet1, subnet2]
    cloud_config_hash['disk_types'] = [disk_type_spec]
    cloud_config_hash
  end

  let(:cloud_config_hash_with_azs) do
    cloud_config_hash = Bosh::Spec::NewDeployments.simple_cloud_config
    cloud_config_hash['azs'] = [
      {'name' => 'my-az-1'},
      {'name' => 'my-az-2'}
    ]
    cloud_config_hash['networks'].first['subnets'] = [subnet_with_az1, subnet_with_az2]
    cloud_config_hash['disk_types'] = [disk_type_spec]
    cloud_config_hash['compilation']['az'] = 'my-az-1'

    cloud_config_hash
  end

  let(:subnet1) do
    {
      'range' => '192.168.1.0/24',
      'gateway' => '192.168.1.1',
      'dns' => ['8.8.8.8'],
      'reserved' => [],
      'static' => ['192.168.1.10'],
      'cloud_properties' => {},
    }
  end

  let(:subnet_with_1_available_ip) do
    {
      'range' => '192.168.1.0/30', # 192.168.1.2 the only available
      'gateway' => '192.168.1.1',
      'dns' => ['8.8.8.8'],
      'reserved' => [],
      'static' => [],
      'cloud_properties' => {},
    }
  end

  let(:subnet_with_az1) do
    subnet1.merge('az' => 'my-az-1')
  end

  let(:subnet2) do
    {
      'range' => '192.168.2.0/24',
      'gateway' => '192.168.2.1',
      'dns' => ['8.8.8.8'],
      'reserved' => [],
      'static' => ['192.168.2.10'],
      'cloud_properties' => {},
    }
  end

  let(:subnet_with_az2) do
    subnet2.merge('az' => 'my-az-2')
  end

  let(:subnet3) do
    {
      'range' => '192.168.3.0/24',
      'gateway' => '192.168.3.1',
      'dns' => ['8.8.8.8'],
      'reserved' => [],
      'static' => ['192.168.3.10'],
      'cloud_properties' => {},
    }
  end

  let(:subnet_with_az3) do
    subnet3.merge('az' => 'my-az-3')
  end

  let(:manifest_with_azs) do
    manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
    instance_group_spec = etcd_instance_group
    instance_group_spec['networks'].first['name'] = cloud_config_hash_with_azs['networks'].first['name']
    instance_group_spec['azs'] = ['my-az-1', 'my-az-2']
    instance_group_spec['migrated_from'] = [{'name' => 'etcd_z1', 'az' => 'my-az-1'}, {'name' => 'etcd_z2', 'az' => 'my-az-2'}]
    manifest_hash['instance_groups'] = [instance_group_spec]
    manifest_hash
  end

  let(:disk_type_spec) do
    {
      'name' => 'fast_disks',
      'disk_size' => 1024,
      'cloud_properties' => {}
    }
  end

  let(:etcd_z1_instance_group) do
    Bosh::Spec::Deployments.simple_instance_group(instances: 1, name: 'etcd_z1', persistent_disk_pool: 'fast_disks')
  end
  let(:etcd_z2_instance_group) do
    Bosh::Spec::Deployments.simple_instance_group(instances: 1, name: 'etcd_z2', persistent_disk_pool: 'fast_disks')
  end
  let(:etcd_instance_group) do
    Bosh::Spec::NewDeployments.simple_instance_group(instances: 2, name: 'etcd', persistent_disk_type: 'fast_disks', env: {'bosh' => {'password' => 'foobar'}})
  end

  let(:manifest_with_etcd_z1_in_az1) do
    manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
    instance_group_spec =  Bosh::Spec::NewDeployments.simple_instance_group(instances: 1, name: 'etcd_z1', persistent_disk_type: 'fast_disks')
    instance_group_spec['azs'] = ['my-az-1']
    instance_group_spec['networks'].first['name'] = cloud_config_hash_with_azs['networks'].first['name']
    manifest_hash['instance_groups'] = [instance_group_spec]
    manifest_hash
  end

  let(:manifest_with_etcd_z2_in_az2_migrated_from_etcd_z1) do
    manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
    instance_group_spec = Bosh::Spec::NewDeployments.simple_instance_group(instances: 1, name: 'etcd_z2', persistent_disk_type: 'fast_disks')
    instance_group_spec['networks'].first['name'] = cloud_config_hash_with_azs['networks'].first['name']
    instance_group_spec['azs'] = ['my-az-2']
    instance_group_spec['migrated_from'] = [{'name' => 'etcd_z1'}]
    manifest_hash['instance_groups'] = [instance_group_spec]
    manifest_hash
  end

  let(:manifest_with_etcd_z1_in_az1_and_etcd_z2_in_az2) do
    manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
    instance_group_spec_1 = Bosh::Spec::NewDeployments.simple_instance_group(instances: 1, name: 'etcd_z1', persistent_disk_type: 'fast_disks')
    instance_group_spec_1['azs'] = ['my-az-1']
    instance_group_spec_1['networks'].first['name'] = cloud_config_hash_with_azs['networks'].first['name']
    instance_group_spec_2 = Bosh::Spec::NewDeployments.simple_instance_group(instances: 1, name: 'etcd_z2', persistent_disk_type: 'fast_disks')
    instance_group_spec_2['azs'] = ['my-az-2']
    instance_group_spec_2['networks'].first['name'] = cloud_config_hash_with_azs['networks'].first['name']
    manifest_hash['instance_groups'] = [instance_group_spec_1, instance_group_spec_2]
    manifest_hash
  end

  context 'when migrating to availability zones' do
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
        etcd_z1_instance_group,
        etcd_z2_instance_group,
      ]
      legacy_manifest
    end

    def migrate_legacy_etcd_z1_and_z2
      deploy_from_scratch(legacy: true, manifest_hash: legacy_manifest)
      original_instances = director.instances
      original_disks = current_sandbox.cpi.disk_cids
      expect(original_instances.map(&:job_name)).to match_array(['etcd_z1', 'etcd_z2'])

      upload_cloud_config(cloud_config_hash: cloud_config_hash_with_azs)
      deploy_simple_manifest(manifest_hash: manifest_with_azs)

      [original_instances, original_disks]
    end

    context 'when using same static reservation' do
      let(:etcd_z1_instance_group) do
        Bosh::Spec::Deployments.simple_instance_group(instances: 1, name: 'etcd_z1', static_ips: ['192.168.1.10'], persistent_disk_pool: 'fast_disks')
      end
      let(:etcd_z2_instance_group) do
        Bosh::Spec::Deployments.simple_instance_group(instances: 1, name: 'etcd_z2', static_ips: ['192.168.2.10'], persistent_disk_pool: 'fast_disks')
      end
      let(:etcd_instance_group) do
        Bosh::Spec::NewDeployments.simple_instance_group(instances: 2, name: 'etcd', static_ips: ['192.168.1.10', '192.168.2.10'], persistent_disk_type: 'fast_disks', env: {'bosh' => {'password' => 'foobar'}})
      end

      it 'keeps VM, disk and IPs and updates AZs' do
        original_instances, original_disks = migrate_legacy_etcd_z1_and_z2

        new_instances = director.instances
        expect(new_instances.map(&:job_name)).to eq(['etcd', 'etcd'])

        expect(new_instances.map(&:ips).flatten).to match_array(['192.168.1.10', '192.168.2.10'])
        expect(new_instances.map(&:vm_cid)).to match_array(original_instances.map(&:vm_cid))
        expect(new_instances.map(&:availability_zone)).to match_array(['my-az-1', 'my-az-2'])

        new_disks = current_sandbox.cpi.disk_cids
        expect(new_disks).to match_array(original_disks)
      end
    end

    context 'when using dynamic reservation without any other changes' do
      # make it use 2nd subnet for etcd_z2 instance
      let(:subnet1) { subnet_with_1_available_ip }
      let(:subnet_with_az1) { subnet_with_1_available_ip.merge('az' => 'my-az-1') }
      let(:etcd_z1_instance_group) do
        Bosh::Spec::Deployments.simple_instance_group(instances: 1, name: 'etcd_z1', persistent_disk_pool: 'fast_disks')
      end
      let(:etcd_z2_instance_group) do
        Bosh::Spec::Deployments.simple_instance_group(instances: 1, name: 'etcd_z2', persistent_disk_pool: 'fast_disks')
      end
      let(:etcd_instance_group) do
        Bosh::Spec::NewDeployments.simple_instance_group(instances: 2, name: 'etcd', persistent_disk_type: 'fast_disks', env: {'bosh' => {'password' => 'foobar'}})
      end

      it 'keeps VM, disk and IPs and updates AZs' do
        original_instances, original_disks = migrate_legacy_etcd_z1_and_z2

        new_instances = director.instances
        expect(new_instances.map(&:job_name)).to eq(['etcd', 'etcd'])

        expect(new_instances.map(&:ips)).to match_array(original_instances.map(&:ips))
        expect(new_instances.map(&:vm_cid)).to match_array(original_instances.map(&:vm_cid))
        expect(new_instances.map(&:availability_zone)).to match_array(['my-az-1', 'my-az-2'])

        new_disks = current_sandbox.cpi.disk_cids
        expect(new_disks).to match_array(original_disks)
      end
    end

    context 'when jobs of migrated instance_groups are different from desired job' do
      let(:etcd_instance_group) do
        Bosh::Spec::NewDeployments.simple_instance_group(instances: 2, name: 'etcd', persistent_disk_type: 'fast_disks', jobs: [{'name' => 'foobar_without_packages'}], env: {'bosh' => {'password' => 'foobar'}})
      end

      it 'updates job instances with new desired job templates keeping persistent disk' do
        _, original_disks = migrate_legacy_etcd_z1_and_z2

        new_instances = director.instances
        expect(new_instances.map(&:job_name)).to eq(['etcd', 'etcd'])

        new_disks = current_sandbox.cpi.disk_cids
        expect(new_disks).to match_array(original_disks)

        new_instances.each do |new_instance|
          template = new_instance.read_job_template('foobar_without_packages', 'bin/foobar_ctl')
          expect(template).to include('job_name=etcd')
          expect(template).to include('templates=foobar_without_packages')
        end
      end
    end

    context 'when instance network configuration changed (from dynamic to static)' do
      let(:etcd_instance_group) do
        Bosh::Spec::NewDeployments.simple_instance_group(instances: 2, name: 'etcd', static_ips: ['192.168.1.10', '192.168.2.10'], persistent_disk_type: 'fast_disks', env: {'bosh' => {'password' => 'foobar'}})
      end

      it 'recreates VM keeping persistent disk' do
        original_instances, original_disks = migrate_legacy_etcd_z1_and_z2

        new_instances = director.instances
        expect(new_instances.map(&:job_name)).to eq(['etcd', 'etcd'])

        expect(new_instances.map(&:ips).flatten).to match_array(['192.168.1.10', '192.168.2.10'])
        expect(new_instances.map(&:vm_cid)).not_to match_array(original_instances.map(&:vm_cid))

        new_disks = current_sandbox.cpi.disk_cids
        expect(new_disks).to match_array(original_disks)
      end
    end

    context 'when instance vm type configuration changed' do
      before do
        cloud_config_hash_with_azs['vm_types'].first['cloud_properties'] = {
          'new-cloud-property-key' => 'new-cloud-property-value'
        }
      end

      it 'recreates VM keeping persistent disk' do
        original_instances, original_disks = migrate_legacy_etcd_z1_and_z2

        new_instances = director.instances
        expect(new_instances.map(&:job_name)).to eq(['etcd', 'etcd'])

        expect(new_instances.map(&:vm_cid)).not_to match_array(original_instances.map(&:vm_cid))

        new_disks = current_sandbox.cpi.disk_cids
        expect(new_disks).to match_array(original_disks)

        new_instances.each do |new_instance|
          expect(current_sandbox.cpi.read_cloud_properties(new_instance.vm_cid)).to eq({
            'new-cloud-property-key' => 'new-cloud-property-value'
          })
        end
      end
    end

    context 'when the number of original instances is greater than the number of new instances' do
      let(:etcd_z1_instance_group) do
        Bosh::Spec::Deployments.simple_instance_group(instances: 2, name: 'etcd_z1', persistent_disk_pool: 'fast_disks')
      end
      # make it use 2nd subnet for 2nd instance
      let(:subnet1) { subnet_with_1_available_ip }

      it 'deletes extra instances' do
        deploy_from_scratch(legacy: true, manifest_hash: legacy_manifest)
        original_instances = director.instances
        original_disks = current_sandbox.cpi.disk_cids
        expect(original_instances.size).to eq(3)
        expect(original_disks.size).to eq(3)
        expect(original_instances.map(&:job_name)).to match_array(['etcd_z1', 'etcd_z1', 'etcd_z2'])

        upload_cloud_config(cloud_config_hash: cloud_config_hash_with_azs)
        deploy_simple_manifest(manifest_hash: manifest_with_azs)

        new_instances = director.instances
        expect(new_instances.size).to eq(2)
        expect(new_instances.map(&:job_name)).to eq(['etcd', 'etcd'])

        expect(original_instances.map(&:vm_cid)).to include(*new_instances.map(&:vm_cid))

        new_disks = current_sandbox.cpi.disk_cids
        expect(new_disks.size).to eq(3)
        expect(original_disks).to include(*new_disks)
      end
    end

    context 'when the number of original instances is less than the number of new instances' do
      let(:etcd_instance_group) do
        Bosh::Spec::NewDeployments.simple_instance_group(instances: 3, name: 'etcd', persistent_disk_type: 'fast_disks', env: {'bosh' => {'password' => 'foobar'}})
      end
      # make it use 2nd subnet for etcd_z2 instance
      let(:subnet1) { subnet_with_1_available_ip }
      # make room for 3rd instance in my-az-1
      let(:subnet_with_az1) do
        subnet1.merge('range' => '192.168.1.0/24', 'az' => 'my-az-1')
      end

      it 'creates one extra instance and recreate one of old instances due to netmask change' do
        original_instances, original_disks = migrate_legacy_etcd_z1_and_z2

        new_instances = director.instances
        expect(new_instances.size).to eq(3)
        expect(new_instances.map(&:job_name)).to eq(['etcd', 'etcd', 'etcd'])
        expect((new_instances.map(&:vm_cid) & original_instances.map(&:vm_cid)).size).to eq 1

        new_disks = current_sandbox.cpi.disk_cids
        expect(new_disks.size).to eq(3)
        expect(new_disks).to include(*original_disks)
      end
    end

    context 'when migrating without persistent disks' do
      let(:etcd_z1_instance_group) { Bosh::Spec::NewDeployments.simple_instance_group(instances: 2, name: 'etcd_z1', env: {'bosh' => {'password' => 'foobar'}}) }
      let(:etcd_instance_group) { Bosh::Spec::NewDeployments.simple_instance_group(instances: 2, name: 'etcd', env: {'bosh' => {'password' => 'foobar'}}) }

      it 'balances vms across azs' do
        manifest_with_azs = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
        instance_group_spec_z1_1 = etcd_z1_instance_group
        instance_group_spec_z1_1['azs'] = ['my-az-1']
        instance_group_spec_z1_1['networks'].first['name'] = cloud_config_hash_with_azs['networks'].first['name']
        manifest_with_azs['instance_groups'] = [etcd_z1_instance_group]

        deploy_from_scratch(manifest_hash: manifest_with_azs, cloud_config_hash: cloud_config_hash_with_azs)

        original_instances = director.instances
        expect(original_instances.size).to eq(2)
        expect(original_instances.map(&:job_name)).to match_array(['etcd_z1', 'etcd_z1'])
        expect(original_instances.map(&:availability_zone)).to match_array(['my-az-1', 'my-az-1'])

        new_manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
        instance_group_spec = etcd_instance_group
        instance_group_spec['networks'].first['name'] = cloud_config_hash_with_azs['networks'].first['name']
        instance_group_spec['azs'] = ['my-az-1', 'my-az-2']
        instance_group_spec['migrated_from'] = [{'name' => 'etcd_z1', 'az' => 'my-az-1'}]
        new_manifest_hash['instance_groups'] = [instance_group_spec]

        deploy_simple_manifest(manifest_hash: new_manifest_hash)
        new_instances = director.instances
        expect(new_instances.size).to eq(2)
        expect(new_instances.map(&:job_name)).to match_array(['etcd', 'etcd'])
        expect(new_instances.map(&:availability_zone)).to match_array(['my-az-1', 'my-az-2'])
        instance_in_z1 = original_instances.find { |instance| instance.availability_zone == 'my-az-1' }
        expect(original_instances.map(&:vm_cid)).to include(instance_in_z1.vm_cid)
      end
    end

    context 'when deployment fails' do
      it 'job instances should have migrated names, indexes, bootstrap and az' do
        deploy_from_scratch(legacy: true, manifest_hash: legacy_manifest)
        current_sandbox.cpi.commands.make_create_vm_always_fail

        manifest = manifest_with_azs

        # this is done until our bosh instances will show all instances
        # even those that don't have vms
        failing_instance_group_spec = Bosh::Spec::NewDeployments.simple_instance_group(instances: 1, name: 'failing', env: {'bosh' => {'password' => 'foobar'}})
        failing_instance_group_spec['azs'] = ['my-az-1']
        manifest['instance_groups'].unshift(failing_instance_group_spec)

        upload_cloud_config(cloud_config_hash: cloud_config_hash_with_azs)
        deploy_simple_manifest(manifest_hash: manifest, failure_expected: true)

        new_instances = director.instances
        puts new_instances.map(&:inspect)
        etcd_instance_1 = new_instances.find { |vm| vm.job_name == 'etcd' && vm.index == '0' }
        expect(etcd_instance_1).to_not be_nil
        expect(etcd_instance_1.bootstrap).to be_truthy
        expect(etcd_instance_1.availability_zone).to eq('my-az-1')

        etcd_instance_2 = new_instances.find { |vm| vm.job_name == 'etcd' && vm.index == '1' }
        expect(etcd_instance_2).to_not be_nil
        expect(etcd_instance_2.bootstrap).to be_falsey
        expect(etcd_instance_2.availability_zone).to eq('my-az-2')
      end
    end
  end

  context 'when migrating without azs' do
    let(:job1) { Bosh::Spec::NewDeployments.simple_instance_group(instances: 2, name: 'job1') }
    let(:job2) { Bosh::Spec::NewDeployments.simple_instance_group(instances: 2, name: 'job2') }

    let(:manifest_1) do
      manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
      instance_group_spec = job1
      instance_group_spec['networks'].first['name'] = cloud_config_hash['networks'].first['name']
      manifest_hash['instance_groups'] = [instance_group_spec]
      manifest_hash
    end

    let(:manifest_2) do
      manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
      instance_group_spec = job2
      instance_group_spec['networks'].first['name'] = cloud_config_hash['networks'].first['name']
      instance_group_spec['migrated_from'] = [{'name' => 'job1'}]
      manifest_hash['instance_groups'] = [instance_group_spec]
      manifest_hash
    end

    it 'succeeds' do
      deploy_from_scratch(manifest_hash: manifest_1, cloud_config_hash: cloud_config_hash)
      deploy_from_scratch(manifest_hash: manifest_2, cloud_config_hash: cloud_config_hash)
      expect(director.instances.size).to eq(2)
    end
  end

  context 'when migrating with azs' do
    context 'when migrating into new job in different az' do
      it 'recreates VM and disk in new az' do
        deploy_from_scratch(manifest_hash: manifest_with_etcd_z1_in_az1, cloud_config_hash: cloud_config_hash_with_azs)
        original_instances = director.instances
        expect(original_instances.size).to eq(1)
        expect(original_instances.map(&:job_name)).to match_array(['etcd_z1'])
        expect(original_instances.map(&:availability_zone)).to match_array(['my-az-1'])
        original_disks = current_sandbox.cpi.disk_cids

        deploy_simple_manifest(manifest_hash: manifest_with_etcd_z2_in_az2_migrated_from_etcd_z1)
        new_instances = director.instances
        expect(new_instances.size).to eq(1)
        expect(new_instances.map(&:job_name)).to match_array(['etcd_z2'])
        expect(new_instances.map(&:availability_zone)).to match_array(['my-az-2'])
        new_disks = current_sandbox.cpi.disk_cids
        expect(new_disks).to_not match_array(original_disks)
      end
    end

    context 'when migrating into existing job' do
      it 'preserves existing job instances and migrated job instances keeping disks' do
        manifest_with_azs = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
        instance_group_spec_1 = Bosh::Spec::NewDeployments.simple_instance_group(instances: 2, name: 'etcd')
        instance_group_spec_1['networks'].first['name'] = cloud_config_hash_with_azs['networks'].first['name']
        instance_group_spec_1['instances'] = 1
        instance_group_spec_1['azs'] = ['my-az-1']
        instance_group_spec_2 = Bosh::Spec::NewDeployments.simple_instance_group(instances: 1, name: 'etcd_z1')
        instance_group_spec_2['networks'].first['name'] = cloud_config_hash_with_azs['networks'].first['name']
        instance_group_spec_2['instances'] = 1
        instance_group_spec_2['azs'] = ['my-az-2']
        manifest_with_azs['instance_groups'] = [instance_group_spec_1, instance_group_spec_2]

        deploy_from_scratch(manifest_hash: manifest_with_azs, cloud_config_hash: cloud_config_hash_with_azs)
        original_instances = director.instances
        expect(original_instances.size).to eq(2)
        expect(original_instances.map(&:job_name)).to match_array(['etcd_z1', 'etcd'])
        original_disks = current_sandbox.cpi.disk_cids

        instance_group_spec_1['azs'] = ['my-az-1', 'my-az-2']
        instance_group_spec_1['migrated_from'] = [{'name' => 'etcd_z1'}]
        instance_group_spec_1['networks'].first['name'] = cloud_config_hash_with_azs['networks'].first['name']
        instance_group_spec_1['instances'] = 2
        manifest_with_azs['instance_groups'] = [instance_group_spec_1]

        deploy_simple_manifest(manifest_hash: manifest_with_azs)
        new_instances = director.instances
        expect(new_instances.size).to eq(2)
        expect(new_instances.map(&:job_name)).to match_array(['etcd', 'etcd'])
        new_disks = current_sandbox.cpi.disk_cids
        expect(new_disks).to match_array(original_disks)
      end

      it 'assigns indexes correctly' do
        manifest_with_azs = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
        db1_instance_group_spec = Bosh::Spec::NewDeployments.simple_instance_group(instances: 1, name: 'db_z1', persistent_disk_type: 'fast_disks')
        db1_instance_group_spec['networks'].first['name'] = cloud_config_hash_with_azs['networks'].first['name']
        db1_instance_group_spec['instances'] = 1
        db1_instance_group_spec['azs'] = ['my-az-1']
        db2_instance_group_spec = Bosh::Spec::NewDeployments.simple_instance_group(instances: 1, name: 'db_z2', persistent_disk_type: 'fast_disks')
        db2_instance_group_spec['networks'].first['name'] = cloud_config_hash_with_azs['networks'].first['name']
        db2_instance_group_spec['instances'] = 1
        db2_instance_group_spec['azs'] = ['my-az-2']
        db3_instance_group_spec = Bosh::Spec::NewDeployments.simple_instance_group(instances: 1, name: 'db_z3', persistent_disk_type: 'fast_disks')
        db3_instance_group_spec['networks'].first['name'] = cloud_config_hash_with_azs['networks'].first['name']
        db3_instance_group_spec['instances'] = 2
        db3_instance_group_spec['azs'] = ['my-az-3']
        manifest_with_azs['instance_groups'] = [db1_instance_group_spec, db2_instance_group_spec, db3_instance_group_spec]

        cloud_config_hash = cloud_config_hash_with_azs
        cloud_config_hash['azs'] = [
          {'name' => 'my-az-1'},
          {'name' => 'my-az-2'},
          {'name' => 'my-az-3'}
        ]
        cloud_config_hash['networks'].first['subnets'] = [subnet_with_az1, subnet_with_az2, subnet_with_az3]

        deploy_from_scratch(manifest_hash: manifest_with_azs, cloud_config_hash: cloud_config_hash)

        new_manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
        db_instance_group_spec = Bosh::Spec::NewDeployments.simple_instance_group(instances: 4, name: 'db')
        db_instance_group_spec['instances'] = 4
        db_instance_group_spec['networks'].first['name'] = cloud_config_hash_with_azs['networks'].first['name']
        db_instance_group_spec['azs'] = ['my-az-1', 'my-az-2', 'my-az-3']
        db_instance_group_spec['migrated_from'] = [{'name' => 'db_z2', 'az' => 'my-az-2'}, {'name' => 'db_z3', 'az' => 'my-az-3'}]
        new_manifest_hash['instance_groups'] = [db1_instance_group_spec, db_instance_group_spec]

        deploy_simple_manifest(manifest_hash: new_manifest_hash)

        db_instances = director.instances.select { |i| i.job_name =='db' }
        expect(db_instances.map(&:index)).to match_array(['0', '1', '2', '3'])
      end
    end
  end

  it 'updates dns records' do
    original_manifest_with_azs = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
    instance_group_spec =  Bosh::Spec::NewDeployments.simple_instance_group(instances: 1, name: 'etcd_z1', persistent_disk_type: 'fast_disks')
    instance_group_spec['azs'] = ['my-az-1']
    instance_group_spec['networks'].first['name'] = cloud_config_hash_with_azs['networks'].first['name']
    original_manifest_with_azs['instance_groups'] = [instance_group_spec]

    deploy_from_scratch(manifest_hash: original_manifest_with_azs, cloud_config_hash: cloud_config_hash_with_azs)
    output = scrub_random_ids(table(bosh_runner.run('vms --dns', json: true)))
    dns_records = output[0]['dns_a_records'].split("\n")
    expect(dns_records).to include('0.etcd-z1.a.simple.bosh')
    expect(dns_records).to include('xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx.etcd-z1.a.simple.bosh')

    new_manifest_hash = original_manifest_with_azs
    instance_group_spec = etcd_instance_group
    instance_group_spec['instances'] = 1
    instance_group_spec['networks'].first['name'] = cloud_config_hash_with_azs['networks'].first['name']
    instance_group_spec['azs'] = ['my-az-1']
    instance_group_spec['migrated_from'] = [{'name' => 'etcd_z1'}]
    new_manifest_hash['instance_groups'] = [instance_group_spec]

    deploy_simple_manifest(manifest_hash: new_manifest_hash)
    output = scrub_random_ids(table(bosh_runner.run('vms --dns', json: true)))
    dns_records = output[0]['dns_a_records'].split("\n")
    expect(dns_records).to include('0.etcd.a.simple.bosh')
    expect(dns_records).to include('xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx.etcd.a.simple.bosh')
    expect(dns_records).to include('0.etcd-z1.a.simple.bosh')
    expect(dns_records).to include('xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx.etcd-z1.a.simple.bosh')
  end

  context 'when migrating job that does not exist in previous deployment' do
    let(:manifest_with_unknown_migrated_from_job) do
      new_manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
      instance_group_spec = etcd_instance_group
      instance_group_spec['instances'] = 1
      instance_group_spec['networks'].first['name'] = cloud_config_hash_with_azs['networks'].first['name']
      instance_group_spec['azs'] = ['my-az-1']
      instance_group_spec['migrated_from'] = [{'name' => 'unknown_job'}]
      new_manifest_hash['instance_groups'] = [instance_group_spec]
      new_manifest_hash
    end

    it 'successfully deploys' do
      deploy_from_scratch(manifest_hash: manifest_with_etcd_z1_in_az1, cloud_config_hash: cloud_config_hash_with_azs)
      original_instances = director.instances
      expect(original_instances.size).to eq(1)
      expect(original_instances.map(&:job_name)).to match_array(['etcd_z1'])

      deploy_simple_manifest(manifest_hash: manifest_with_unknown_migrated_from_job)
      new_instances = director.instances
      expect(new_instances.size).to eq(1)
      expect(new_instances.map(&:job_name)).to match_array(['etcd'])
      expect(new_instances.map(&:vm_cid)).to_not match_array(original_instances.map(&:vm_cid))
    end
  end

  describe 'bootstrap' do
    context 'when migrated_from has several bootstrap instances' do
      it 'picks only one bootstrap instance' do
        deploy_from_scratch(manifest_hash: manifest_with_etcd_z1_in_az1_and_etcd_z2_in_az2, cloud_config_hash: cloud_config_hash_with_azs)
        original_instances = director.instances
        expect(original_instances.select(&:bootstrap).size).to eq(2)

        deploy_simple_manifest(manifest_hash: manifest_with_azs)

        new_instances = director.instances
        expect(new_instances.select(&:bootstrap).size).to eq(1)
      end
    end
  end

  describe 'rendered job templates' do
    it 'has new name, index, bootstrap and az' do
      deploy_from_scratch(manifest_hash: manifest_with_etcd_z1_in_az1_and_etcd_z2_in_az2, cloud_config_hash: cloud_config_hash_with_azs)

      etcd_z1_instance = director.instance('etcd_z1', '0')
      template = etcd_z1_instance.read_job_template('foobar', 'bin/foobar_ctl')
      expect(template).to include('az=my-az-1')
      expect(template).to include('job_name=etcd_z1')
      expect(template).to include('index=0')
      expect(template).to include('bootstrap=true')

      etcd_z2_instance = director.instance('etcd_z2', '0')
      template = etcd_z2_instance.read_job_template('foobar', 'bin/foobar_ctl')
      expect(template).to include('az=my-az-2')
      expect(template).to include('job_name=etcd_z2')
      expect(template).to include('index=0')
      expect(template).to include('bootstrap=true')

      deploy_simple_manifest(manifest_hash: manifest_with_azs)

      new_instance = director.instances
      etcd_instance_1 = new_instance.find { |instance| instance.job_name == 'etcd' && instance.index == '0' }
      template = etcd_instance_1.read_job_template('foobar', 'bin/foobar_ctl')
      expect(template).to include('az=my-az-1')
      expect(template).to include('job_name=etcd')
      expect(template).to include('index=0')
      expect(template).to include('bootstrap=true')

      etcd_instance_2 = new_instance.find { |instance| instance.job_name == 'etcd' && instance.index == '1' }
      template = etcd_instance_2.read_job_template('foobar', 'bin/foobar_ctl')
      expect(template).to include('az=my-az-2')
      expect(template).to include('job_name=etcd')
      expect(template).to include('index=1')
      expect(template).to include('bootstrap=false')
    end
  end
end
