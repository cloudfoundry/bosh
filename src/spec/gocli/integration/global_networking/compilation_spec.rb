require_relative '../../spec_helper'

describe 'global networking', type: :integration do
  include Bosh::Spec::BlockingDeployHelper
  with_reset_sandbox_before_each

  before do
    create_and_upload_test_release
    upload_stemcell
  end

  describe 'IP allocation without cloud config' do
    context 'when there are many compilation packages' do
      let(:cloud_config_hash) do
        cloud_config_hash = Bosh::Spec::Deployments.simple_cloud_config
        cloud_config_hash['compilation']['reuse_compilation_vms'] = false
        cloud_config_hash['compilation']['network'] = 'compilation'
        cloud_config_hash['compilation']['workers'] = 5
        cloud_config_hash['networks'] << {
          'name' => 'compilation',
          'subnets' => [
            'range' => '192.168.2.0/24',
            'gateway' => '192.168.2.1',
            'dns' => ['8.8.8.8'],
            'static' => [],
            'reserved' => [],
          ]
        }
        cloud_config_hash
      end

      it 'allocates new IP addresses without race conditions' do
        manifest_hash = Bosh::Spec::NetworkingManifest.deployment_manifest(manifest: Bosh::Spec::Deployments.legacy_manifest, legacy_job: true, instances: 1, template: 'job_with_many_packages')
        legacy_manifest_hash = manifest_hash.merge(cloud_config_hash)

        deploy_simple_manifest(manifest_hash: legacy_manifest_hash)

        compilation_vm_ips = current_sandbox.cpi.invocations_for_method('create_vm').map do |invocation|
          invocation.inputs['networks'].values.first['ip']
        end

        expect(compilation_vm_ips).to match_array(['192.168.2.2', '192.168.2.3', '192.168.2.4', '192.168.2.5', '192.168.2.6', '192.168.2.7', '192.168.2.8', '192.168.2.9', '192.168.2.10', '192.168.2.11', '192.168.1.2'])
      end
    end
  end

  context 'when compilation pool configuration contains az information' do

    let(:cloud_config_hash) do
      cloud_config_hash = Bosh::Spec::NewDeployments.simple_cloud_config
      cloud_config_hash['azs'] = [{
          'name' => 'z2',
          'cloud_properties' => {
            'az_section_config' => 'neato',
            'who_wins' => 'az_section'
          }
        }]

      cloud_config_hash['networks'].push({
          'name' => 'network_with_az',
          'type' => 'manual',
          'subnets' => [{
              'range' => '10.0.0.0/24',
              'gateway' => '10.0.0.1',
              'az' => 'z2',
            }]
        })

      cloud_config_hash['compilation']['cloud_properties'] = {
        'compilation_section_config' => 'blah',
        'who_wins' => 'compilation_section'
      }
      cloud_config_hash['compilation']['az'] = 'z2'
      cloud_config_hash['compilation']['network'] = 'network_with_az'

      cloud_config_hash
    end

    it 'should place the vm in the az with merged cloud properties and overrides specific cloud properties' do
      upload_cloud_config(cloud_config_hash: cloud_config_hash)

      manifest_hash = Bosh::Spec::NetworkingManifest.deployment_manifest(instances: 1)
      deploy_simple_manifest(manifest_hash: manifest_hash)

      create_vm_invocation = current_sandbox.cpi.invocations_for_method('create_vm')[0]

      expect(create_vm_invocation.inputs['cloud_properties']).to eq({
            'compilation_section_config' => 'blah',
            'az_section_config' => 'neato',
            'who_wins' => 'compilation_section'
          }
        )
    end

    context 'when availability zone does not match any of the deployment' do
      it 'raises a availability zone not found error' do
        cloud_config_hash['compilation']['az'] = 'non_existing_az'
        upload_cloud_config(cloud_config_hash: cloud_config_hash)

        manifest_hash = Bosh::Spec::NetworkingManifest.deployment_manifest(instances: 1)
        expect{
          deploy_simple_manifest(manifest_hash: manifest_hash)
        }.to raise_error(RuntimeError, /Compilation config references unknown az 'non_existing_az'. Known azs are: \[z2\]/)
      end
    end
  end

  context 'when creating vm for compilation fails' do
    before do
      current_sandbox.cpi.commands.make_create_vm_always_fail
    end

    it 'releases its IP for next deploy' do
      upload_cloud_config
      manifest_hash = Bosh::Spec::NetworkingManifest.deployment_manifest(instances: 1)
      deploy_simple_manifest(manifest_hash: manifest_hash, failure_expected: true)

      compilation_vm_ips = current_sandbox.cpi.invocations_for_method('create_vm').map do |invocation|
        invocation.inputs['networks']['a']['ip']
      end

      expect(compilation_vm_ips).to eq(['192.168.1.3']) # 192.168.1.2 is reserved for instance

      current_sandbox.cpi.commands.allow_create_vm_to_succeed
      manifest_hash = Bosh::Spec::NetworkingManifest.deployment_manifest(instances: 2)
      deploy_simple_manifest(manifest_hash: manifest_hash)
      expect(director.instances.map(&:ips).flatten).to contain_exactly('192.168.1.2', '192.168.1.3')
    end
  end

  context 'when compilation fails' do
    it 'releases its IP for next deploy' do
      upload_cloud_config
      failing_compilation_manifest = Bosh::Spec::NetworkingManifest.deployment_manifest(instances: 1, job: 'fails_with_too_much_output')
      deploy_simple_manifest(manifest_hash: failing_compilation_manifest, failure_expected: true)

      compilation_vm_ips = current_sandbox.cpi.invocations_for_method('create_vm').map do |invocation|
        invocation.inputs['networks']['a']['ip']
      end

      expect(compilation_vm_ips).to eq(['192.168.1.3']) # 192.168.1.2 is reserved for instance

      another_deployment_manifest = Bosh::Spec::NetworkingManifest.deployment_manifest(name: 'another', instances: 1)
      deploy_simple_manifest(manifest_hash: another_deployment_manifest)
      expect(director.instances(deployment_name: 'another').map(&:ips).flatten).to contain_exactly('192.168.1.3') # 192.168.1.2 is reserved by first deployment
    end
  end

  context 'when director fails to clean up compilation VM' do
    it 'releases its IP on subsequent deploy' do
      prepare_for_deploy

      with_blocking_deploy(skip_task_wait: true) do | blocking_task_id |
        compilation_vm_ips = current_sandbox.cpi.invocations_for_method('create_vm').map do |invocation|
          invocation.inputs['networks']['a']['ip']
        end

        expect(compilation_vm_ips).to eq(['192.168.1.3']) # 192.168.1.2 is reserved for instance

        current_sandbox.director_service.hard_stop
        current_sandbox.director_service.start(current_sandbox.director_config)
        bosh_runner.run("cancel-task #{blocking_task_id}")

        sleep 240

        deployment_manifest = Bosh::Spec::NetworkingManifest.deployment_manifest(name: 'blocking', instances: 2)
        deploy_simple_manifest(manifest_hash: deployment_manifest)
        expect(director.instances(deployment_name: 'blocking').map(&:ips).flatten).to contain_exactly('192.168.1.2', '192.168.1.4')

        deployment_manifest = Bosh::Spec::NetworkingManifest.deployment_manifest(name: 'blocking', instances: 3)
        deploy_simple_manifest(manifest_hash: deployment_manifest)
        expect(director.instances(deployment_name: 'blocking').map(&:ips).flatten).to contain_exactly('192.168.1.2', '192.168.1.3', '192.168.1.4')
      end
    end
  end

  context 'when vm_type is specified for compilation' do
    let(:cloud_config_hash) do
      cloud_config_hash = Bosh::Spec::NewDeployments.simple_cloud_config
      cloud_config_hash['vm_types'] = [{
          'name' => 'foo-compilation',
          'cloud_properties' => {
            'instance_type' => 'something',
          }
        }]

      cloud_config_hash['compilation']['vm_type'] = 'foo-compilation'

      cloud_config_hash
    end

    it 'should use the cloud_properties from the compilation vm_type' do
      upload_cloud_config(cloud_config_hash: cloud_config_hash)

      manifest_hash = Bosh::Spec::NetworkingManifest.deployment_manifest(instances: 1)

      instance_group_hash = manifest_hash['instance_groups'].first
      instance_group_hash['vm_type'] = 'foo-compilation'
      instance_group_hash['stemcell'] = 'default'
      deploy_simple_manifest(manifest_hash: manifest_hash)

      create_vm_invocation = current_sandbox.cpi.invocations_for_method('create_vm')[0]

      expect(create_vm_invocation.inputs['cloud_properties']).to eq({
        'instance_type' => 'something'
      })
    end
  end

  context 'when reuse_compilation_vms is set to true' do
    let(:manifest_hash) do
      legacy_manifest = Bosh::Spec::Deployments.legacy_manifest
      manifest_hash = Bosh::Spec::NetworkingManifest.deployment_manifest(manifest: legacy_manifest, instances: 1, template: 'job_with_many_packages', legacy_job: true)
      manifest_hash['jobs'].first['networks'].first.delete('static_ips')
      manifest_hash['jobs'] << {
        'name' => 'consul',
        'templates' => [{'name' => 'transitive_deps'}],
        'resource_pool' => 'b',
        'instances' => 1,
        'networks' => [{'name' => 'a'}],
      }
      manifest_hash['networks'].first['subnets'].first.delete('static')
      manifest_hash['networks'].first['subnets'].first['reserved'] = ['192.168.1.5-192.168.1.255'] # 3 available ips
      manifest_hash['compilation']['reuse_compilation_vms'] = true
      manifest_hash['compilation']['workers'] = 1
      manifest_hash
    end

    context 'when two jobs use two resource pools which refer to the same stemcell' do
      before do
        manifest_hash['resource_pools'] << {'name' => 'b', 'stemcell' => {'name' => 'ubuntu-stemcell', 'version' => '1'}}
      end

      it 'honors the worker property to limits the number of vms' do
        expect(manifest_hash['resource_pools'][0]['stemcell']).to eq(manifest_hash['resource_pools'][1]['stemcell'])
        deploy_simple_manifest(manifest_hash: manifest_hash)
        expect(current_sandbox.cpi.invocations_for_method('create_vm').count).to eq(3)
      end
    end

    context 'when two jobs use different resource pools which refer to different stemcells' do
      before do
        bosh_runner.run("upload-stemcell #{spec_asset('valid_stemcell_2.tgz')}")
        manifest_hash['resource_pools'] << {'name' => 'b', 'stemcell' => {'name' => 'centos-stemcell', 'version' => '2'}}
      end

      it 'honors the worker property to limits the number of vms' do
        expect(manifest_hash['resource_pools'][0]['stemcell']).to_not eq(manifest_hash['resource_pools'][1]['stemcell'])
        deploy_simple_manifest(manifest_hash: manifest_hash)
        expect(current_sandbox.cpi.invocations_for_method('create_vm').count).to eq(5)
      end
    end
  end
end
