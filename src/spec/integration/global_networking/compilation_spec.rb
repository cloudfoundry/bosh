require_relative '../../spec_helper'

describe 'global networking', type: :integration do
  with_reset_sandbox_before_each

  before do
    create_and_upload_test_release
    upload_stemcell
  end

  context 'when compilation pool configuration contains az information' do

    let(:cloud_config_hash) do
      cloud_config_hash = Bosh::Spec::Deployments.simple_cloud_config
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
      current_sandbox.cpi.commands.make_set_vm_metadata_always_fail
    end

    it 'releases its IP for next deploy' do
      upload_cloud_config
      manifest_hash = Bosh::Spec::NetworkingManifest.deployment_manifest(instances: 1)
      deploy_simple_manifest(manifest_hash: manifest_hash, failure_expected: true)

      compilation_vm_ips = current_sandbox.cpi.invocations_for_method('create_vm').map do |invocation|
        invocation.inputs['networks']['a']['ip']
      end

      expect(compilation_vm_ips).to eq(['192.168.1.3']) # 192.168.1.2 is reserved for instance

      current_sandbox.cpi.commands.allow_set_vm_metadata_to_succeed
      manifest_hash = Bosh::Spec::NetworkingManifest.deployment_manifest(instances: 2)
      deploy_simple_manifest(manifest_hash: manifest_hash)

      expect(director.instances.map(&:ips).flatten).to contain_exactly('192.168.1.2', '192.168.1.3')
    end
  end

  context 'when compilation fails' do
    it 'releases its IP for next deploy' do
      upload_cloud_config
      failing_compilation_manifest = Bosh::Spec::NetworkingManifest.deployment_manifest(
        instances: 1,
        job: 'fails_with_too_much_output',
        job_release: 'bosh-release',
      )
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
      cloud_config_hash = Bosh::Spec::Deployments.simple_cloud_config
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
        'instance_type' => 'something',
      })
    end
  end
end
