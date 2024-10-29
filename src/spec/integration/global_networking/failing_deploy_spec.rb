require 'spec_helper'
require 'ipaddr'

def make_subnet_spec(range, static_ips, zone_names = nil)
  spec = {
    'range' => range,
    'gateway' => IPAddr.new(range).to_range.to_a[1].to_string,
    'dns' => ['8.8.8.8'],
    'static' => static_ips,
    'reserved' => [],
    'cloud_properties' => {},
  }
  spec['azs'] = zone_names if zone_names
  spec
end

describe 'failing deploy', type: :integration do
  with_reset_sandbox_before_each

  it 'keeps automatically assigned IP address when vm creation fails' do
    current_sandbox.cpi.commands.make_create_vm_always_fail

    first_manifest_hash = Bosh::Spec::DeploymentManifestHelper.deployment_manifest(
      name: 'first',
      instances: 1,
      job: 'foobar_without_packages',
      job_release: 'bosh-release',
    )
    deploy_from_scratch(manifest_hash: first_manifest_hash, failure_expected: true, legacy: false)

    failing_deploy_vm_ips = current_sandbox.cpi.invocations_for_method('create_vm').map do |invocation|
      invocation.inputs['networks']['a']['ip']
    end

    expect(failing_deploy_vm_ips).to eq(['192.168.1.2'])

    current_sandbox.cpi.commands.allow_create_vm_to_succeed

    second_manifest_hash = Bosh::Spec::DeploymentManifestHelper.deployment_manifest(
      name: 'second',
      instances: 1,
      job: 'foobar_without_packages',
      job_release: 'bosh-release',
    )
    deploy_simple_manifest(manifest_hash: second_manifest_hash)

    expect(director.instances(deployment_name: 'second').map(&:ips).flatten).to eq(['192.168.1.3'])

    deploy_simple_manifest(manifest_hash: first_manifest_hash)

    expect(director.instances(deployment_name: 'first').map(&:ips).flatten).to eq(['192.168.1.2'])
  end

  it 'keeps static IP address when vm creation fails' do
    current_sandbox.cpi.commands.make_create_vm_always_fail

    first_manifest_hash = Bosh::Spec::NetworkingManifest.deployment_manifest(
      name: 'first',
      instances: 1,
      job: 'foobar_without_packages',
      job_release: 'bosh-release',
      static_ips: ['192.168.1.10'],
    )
    deploy_from_scratch(
      manifest_hash: first_manifest_hash,
      cloud_config_hash: Bosh::Spec::DeploymentManifestHelper.simple_cloud_config,
      failure_expected: true,
    )

    failing_deploy_vm_ips = current_sandbox.cpi.invocations_for_method('create_vm').map do |invocation|
      invocation.inputs['networks']['a']['ip']
    end

    expect(failing_deploy_vm_ips).to eq(['192.168.1.10'])

    current_sandbox.cpi.commands.allow_create_vm_to_succeed

    second_manifest_hash = Bosh::Spec::NetworkingManifest.deployment_manifest(
      name: 'second',
      instances: 1,
      job: 'foobar_without_packages',
      job_release: 'bosh-release',
      static_ips: ['192.168.1.10'],
    )
    second_deploy_output = deploy_simple_manifest(manifest_hash: second_manifest_hash, failure_expected: true)
    expect(second_deploy_output).to match(%r{Failed to reserve IP '192.168.1.10' for instance 'foobar\/[a-z0-9\-]+ \(0\)':})
    expect(second_deploy_output).to match(%r{already reserved by instance 'foobar\/[a-z0-9\-]+' from deployment 'first'})

    deploy_simple_manifest(manifest_hash: first_manifest_hash)
    expect(director.instances(deployment_name: 'first').map(&:ips).flatten).to eq(['192.168.1.10'])
  end

  it 'releases unneeded IP addresses when deploy is no longer failing' do
    current_sandbox.cpi.commands.make_create_vm_always_fail

    manifest_hash = Bosh::Spec::NetworkingManifest.deployment_manifest(
      instances: 1,
      job: 'foobar_without_packages',
      job_release: 'bosh-release',
      static_ips: ['192.168.1.10'],
    )
    deploy_from_scratch(
      manifest_hash: manifest_hash,
      cloud_config_hash: Bosh::Spec::DeploymentManifestHelper.simple_cloud_config,
      failure_expected: true,
    )

    failing_deploy_vm_ips = current_sandbox.cpi.invocations_for_method('create_vm').map do |invocation|
      invocation.inputs['networks']['a']['ip']
    end

    expect(failing_deploy_vm_ips).to eq(['192.168.1.10'])

    current_sandbox.cpi.commands.allow_create_vm_to_succeed
    manifest_hash['instance_groups'].first['networks'].first.delete('static_ips')
    deploy_simple_manifest(manifest_hash: manifest_hash)

    expect(director.instances.map(&:ips).flatten).to eq(['192.168.1.2'])

    second_manifest_hash = Bosh::Spec::NetworkingManifest.deployment_manifest(
      name: 'second',
      instances: 1,
      job: 'foobar_without_packages',
      job_release: 'bosh-release',
      static_ips: ['192.168.1.10'],
    )
    deploy_simple_manifest(manifest_hash: second_manifest_hash)
    expect(director.instances(deployment_name: 'second').map(&:ips).flatten).to eq(['192.168.1.10'])
  end

  it 'releases IP when subsequent deploy does not need failing instance' do
    current_sandbox.cpi.commands.make_create_vm_always_fail

    manifest_hash = Bosh::Spec::NetworkingManifest.deployment_manifest(
      instances: 1,
      job: 'foobar_without_packages',
      job_release: 'bosh-release',
    )
    deploy_from_scratch(
      manifest_hash: manifest_hash,
      cloud_config_hash: Bosh::Spec::DeploymentManifestHelper.simple_cloud_config,
      failure_expected: true,
    )

    failing_deploy_vm_ips = current_sandbox.cpi.invocations_for_method('create_vm').map do |invocation|
      invocation.inputs['networks']['a']['ip']
    end

    expect(failing_deploy_vm_ips).to eq(['192.168.1.2'])

    current_sandbox.cpi.commands.allow_create_vm_to_succeed

    manifest_hash['instance_groups'] = [
      Bosh::Spec::DeploymentManifestHelper.simple_instance_group(name: 'second-instance-group', instances: 1),
    ]
    deploy_simple_manifest(manifest_hash: manifest_hash)
    # IPs are not released within single deployment
    # see https://www.pivotaltracker.com/story/show/98057020
    expect(director.instances.map(&:ips).flatten).to eq(['192.168.1.3'])
  end

  context 'create-swap-delete' do
    let(:manifest) do
      manifest = Bosh::Spec::DeploymentManifestHelper.simple_manifest_with_instance_groups(instances: 2)
      manifest['instance_groups'][0]['persistent_disk'] = 660
      manifest['update'] = manifest['update'].merge('vm_strategy' => 'create-swap-delete')
      manifest
    end

    before do
      deploy_from_scratch(manifest_hash: manifest, cloud_config_hash: cloud_config)
    end

    context 'given a failed create-swap-delete deploy' do
      before do
        current_sandbox.cpi.commands.make_detach_disk_to_raise_not_implemented
        deploy_simple_manifest(manifest_hash: manifest, recreate: true, failure_expected: true)

        current_sandbox.cpi.commands.allow_detach_disk_to_succeed
      end

      context 'manual network' do
        let(:cloud_config) do
          cloud_config = Bosh::Spec::DeploymentManifestHelper.simple_cloud_config
          cloud_config['networks'][0]['type'] = 'manual'
          cloud_config
        end

        context 'when we make a simple deploy again' do
          it 'reuses vms that were created in the failed deploy' do
            create_vm_invocations_after_recreate = current_sandbox.cpi.invocations_for_method('create_vm').count
            expect(create_vm_invocations_after_recreate).to be > 2

            deploy_simple_manifest(manifest_hash: manifest)

            create_vm_invocations_after_deploy = current_sandbox.cpi.invocations_for_method('create_vm').count
            expect(create_vm_invocations_after_deploy).to eq(create_vm_invocations_after_recreate)
            expect(director.instances(deployment_name: 'simple').map(&:ips).flatten)
              .to match_array(['192.168.1.4', '192.168.1.5'])
          end

          context 'starting with multiple networks' do
            let(:cloud_config) do
              cloud_config = Bosh::Spec::DeploymentManifestHelper.simple_cloud_config
              cloud_config['networks'] = networks_spec
              cloud_config
            end
            let(:networks_spec) do
              [
                {
                  'name' => 'a',
                  'type' => 'manual',
                  'subnets' => [
                    make_subnet_spec('192.168.1.0/24', ['192.168.1.10 - 192.168.1.14']),
                    make_subnet_spec('192.168.2.0/24', ['192.168.2.10 - 192.168.2.14']),
                  ],
                },
                {
                  'name' => 'b',
                  'type' => 'manual',
                  'subnets' => [
                    make_subnet_spec('10.10.1.0/24', ['10.10.1.10 - 10.10.1.14']),
                    make_subnet_spec('10.10.2.0/24', ['10.10.2.10 - 10.10.2.14']),
                  ],
                },
              ]
            end
            let(:manifest) do
              manifest = Bosh::Spec::DeploymentManifestHelper.simple_manifest_with_instance_groups(instances: 2)
              manifest['instance_groups'][0]['persistent_disk'] = 660
              manifest['instance_groups'][0]['networks'] = [
                { 'name' => 'a', 'default' => %w[dns gateway] },
                { 'name' => 'b' },
              ]
              manifest['update'] = manifest['update'].merge('vm_strategy' => 'create-swap-delete')
              manifest
            end

            context 'when we scale down the networks' do
              it 'results in a successful deployment with the smaller set of networks' do
                manifest['instance_groups'][0]['networks'] = [
                  { 'name' => 'a', 'default' => %w[dns gateway] },
                ]

                deploy_simple_manifest(manifest_hash: manifest)

                expect(director.instances(deployment_name: 'simple').map(&:ips).flatten)
                  .to match_array(['192.168.1.6', '192.168.1.7'])
              end
            end
          end
        end
      end

      context 'dynamic network' do
        let(:cloud_config) do
          cloud_config = Bosh::Spec::DeploymentManifestHelper.simple_cloud_config
          cloud_config['networks'][0]['type'] = 'dynamic'
          cloud_config
        end

        context 'when we make a simple deploy again' do
          it 'reuses vms that were created in the failed deploy' do
            create_vm_invocations_after_recreate = current_sandbox.cpi.invocations_for_method('create_vm').count
            expect(create_vm_invocations_after_recreate).to be > 2

            deploy_simple_manifest(manifest_hash: manifest)

            create_vm_invocations_after_deploy = current_sandbox.cpi.invocations_for_method('create_vm').count
            expect(create_vm_invocations_after_deploy).to eq(create_vm_invocations_after_recreate)
          end
        end
      end
    end
  end
end
