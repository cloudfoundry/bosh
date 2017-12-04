require_relative '../../spec_helper'

describe 'migrating to cloud config', type: :integration do
  with_reset_sandbox_before_each

  before do
    create_and_upload_test_release
    upload_stemcell
  end

  let(:cloud_config_hash) do
    cloud_config_hash = Bosh::Spec::NewDeployments.simple_cloud_config
    cloud_config_hash['networks'].first['subnets'].first['static'] =  ['192.168.1.10', '192.168.1.11']
    cloud_config_hash
  end

  let(:simple_manifest) do
    manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
    manifest_hash['instance_groups'].first['instances'] = 1
    manifest_hash
  end

  let(:second_deployment_manifest) do
    manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
    manifest_hash['instance_groups'].first['instances'] = 1
    manifest_hash['name'] = 'second_deployment'
    manifest_hash
  end

  def deploy_with_ip(manifest, ip, options={})
    manifest['instance_groups'].first['networks'].first['static_ips'] = [ip]
    manifest['instance_groups'].first['instances'] = 1
    options.merge!(manifest_hash: manifest)
    deploy_simple_manifest(options)
  end

  context 'when we have legacy deployments deployed' do
    let(:legacy_manifest) do
      legacy_manifest = Bosh::Spec::Deployments.legacy_manifest
      legacy_manifest['jobs'].first['instances'] = 1
      legacy_manifest['resource_pools'].first.delete('size')
      legacy_manifest
    end

    it 'deployment after cloud config gets IP outside of range reserved by first deployment' do
      legacy_manifest['networks'].first['subnets'].first['range'] = '192.168.1.0/28'
      deploy_simple_manifest(manifest_hash: legacy_manifest)
      instances = director.instances
      expect(instances.size).to eq(1)
      expect(instances.first.ips).to eq(['192.168.1.2'])

      upload_cloud_config(cloud_config_hash: cloud_config_hash)

      deploy_simple_manifest(manifest_hash: second_deployment_manifest)
      instances = director.instances(deployment_name: 'second_deployment')
      expect(instances.size).to eq(1)
      expect(instances.first.ips).to eq(['192.168.1.16'])
    end

    it 'deployment after cloud config fails to get static IP in the range reserved by first deployment' do
      legacy_manifest['networks'].first['subnets'].first['range'] = '192.168.1.0/28'
      deploy_simple_manifest(manifest_hash: legacy_manifest)
      instances = director.instances
      expect(instances.size).to eq(1)
      expect(instances.first.ips).to eq(['192.168.1.2'])

      upload_cloud_config(cloud_config_hash: cloud_config_hash)

      _, exit_code = deploy_with_ip(
        second_deployment_manifest,
        '192.168.1.2',
        {failure_expected: true, return_exit_code: true}
      )
      expect(exit_code).to_not eq(0)
    end

    context 'when also adding azs (and no migrated from)' do
      it 'should not attempt to assign ips to new instances that obsolete instances hold' do
        deploy_simple_manifest(manifest_hash: legacy_manifest)
        expect(director.instances.map(&:ips).flatten).to eq(['192.168.1.2'])

        cloud_config_hash['azs'] = [{'name' => 'zone_1', 'cloud_properties' => {}}]
        cloud_config_hash['networks'].first['subnets'].first['azs'] = ['zone_1']
        cloud_config_hash['compilation']['az'] = 'zone_1'
        upload_cloud_config(cloud_config_hash: cloud_config_hash)

        simple_manifest['instance_groups'].first['azs'] = ['zone_1']
        deploy_simple_manifest(manifest_hash: simple_manifest)

        expect(director.instances.map(&:ips).flatten).to eq(['192.168.1.3'])
      end
    end

    context 'when using azs and migrated from' do
      let(:legacy_manifest) do
        {
          'name' => 'simple',
          'director_uuid' => 'deadbeef',
          'releases' => [{'name' => 'bosh-release', 'version' => '0.1-dev'}],
          'networks' => [
            {
              'name' => 'a',
              'subnets' => [
                {
                  'range' => '192.168.1.0/24',
                  'gateway' => '192.168.1.1',
                  'dns' => ['192.168.1.1', '192.168.1.2'],
                  'static' => ['192.168.1.10', '192.168.1.11', '192.168.1.12'],
                  'reserved' => [],
                  'cloud_properties' => {}
                }
              ]
            }
          ],

          'resource_pools' => [
            {'name' => 'a1', 'cloud_properties' => {}, 'stemcell' => {'name' => 'ubuntu-stemcell', 'version' => '1'}, 'env' => {'bosh' => {'password' => 'foobar'}}},
            {'name' => 'a2', 'cloud_properties' => {}, 'stemcell' => {'name' => 'ubuntu-stemcell', 'version' => '1'}, 'env' => {'bosh' => {'password' => 'foobar'}}}
          ],

          'update' => {'canaries' => 2, 'canary_watch_time' => 4000, 'max_in_flight' => 1, 'update_watch_time' => 20},
          'compilation' => {'workers' => 1, 'network' => 'a', 'cloud_properties' => { 'instance_type' => 'fake-instance-type' }},
          'jobs' => [
            {'name' => 'foobar_z1', 'templates' => [{'name' => 'foobar'}], 'resource_pool' => 'a1', 'instances' => 2, 'networks' => [{'name' => 'a', 'static_ips' => ['192.168.1.10', '192.168.1.11']}], 'properties' => {}},
            {'name' => 'foobar_z2', 'templates' => [{'name' => 'foobar'}], 'resource_pool' => 'a2', 'instances' => 1, 'networks' => [{'name' => 'a', 'static_ips' => ['192.168.1.12']}], 'properties' => {}}
          ]
        }
      end

      let(:cloud_config_hash) do
        {
          'azs' => [
            {'name' => 'z1'},
            {'name' => 'z2'}
          ],

          'networks' => [
            {
              'name' => 'a',
              'subnets' => [
                {
                  'azs' => ['z1', 'z2'],
                  'range' => '192.168.1.0/24',
                  'gateway' => '192.168.1.1',
                  'dns' => ['192.168.1.1', '192.168.1.2'],
                  'static' => ['192.168.1.10', '192.168.1.11', '192.168.1.12'],
                  'reserved' => [],
                  'cloud_properties' => {}
                }
              ]
            }
          ],


          'vm_types' => [
            {'name' => 'a1', 'cloud_properties' => {}}
          ],

          'compilation' => {'az' => 'z1', 'vm_type' => 'a1', 'workers' => 1, 'network' => 'a'}
        }
      end

      let(:second_deployment_manifest) do
        {
          'name' => 'simple',
          'director_uuid' => 'deadbeef',
          'releases' => [{'name' => 'bosh-release', 'version' => '0.1-dev'}],
          'stemcells' => [
            {'name' => 'ubuntu-stemcell', 'version' => '1', 'alias' => 'a_stemcell'}
          ],

          'update' => {'canaries' => 2, 'canary_watch_time' => 4000, 'max_in_flight' => 1, 'update_watch_time' => 20},
          'instance_groups' => [
            {
              'name' => 'foobar',
              'migrated_from' => [
                {'name' => 'foobar_z1', 'az' => 'z1'},
                {'name' => 'foobar_z2', 'az' => 'z2'},
              ],
              'azs' => ['z1', 'z2'],
              'jobs' => [{'name' => 'foobar'}],
              'vm_type' => 'a1',
              'stemcell' => 'a_stemcell',
              'instances' => 3,
              'networks' => [
                {'name' => 'a', 'static_ips' => ['192.168.1.10', '192.168.1.11', '192.168.1.12']}
              ],
              'properties' => {}
            }
          ]
        }
      end

      it 'correctly assigns static ips to existing instances' do
        deploy_simple_manifest(manifest_hash: legacy_manifest)
        upload_cloud_config(cloud_config_hash: cloud_config_hash)
        deploy_simple_manifest(manifest_hash: second_deployment_manifest)
      end
    end
  end
end
