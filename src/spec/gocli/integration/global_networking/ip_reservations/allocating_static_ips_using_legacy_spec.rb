require 'spec_helper'

describe 'global networking', type: :integration do
  before do
    # pending doesn't work in before, but keeping it here so it's greppable
    # pending('cli2: #125442231: switch bosh vms to be per deployment like instances cmd')
  end

  with_reset_sandbox_before_each

  def deploy_with_ip(manifest, ip, options = {})
    deploy_with_ips(manifest, [ip], options)
  end

  def deploy_with_ips(manifest, ips, options = {})
    manifest['instance_groups'].first['networks'].first['static_ips'] = ips
    manifest['instance_groups'].first['instances'] = ips.size
    options[:manifest_hash] = manifest
    deploy_simple_manifest(options)
  end

  def deploy_legacy_with_ips(manifest, ips, options = {})
    manifest['jobs'].first['networks'].first['static_ips'] = ips
    manifest['jobs'].first['instances'] = ips.size
    options[:manifest_hash] = manifest
    deploy_simple_manifest(options)
  end

  def deploy_with_range(deployment_name, range)
    cloud_config_hash = Bosh::Spec::NetworkingManifest.cloud_config(available_ips: 2, range: range) # 1 for compilation
    upload_cloud_config(cloud_config_hash: cloud_config_hash)

    first_manifest_hash = Bosh::Spec::NetworkingManifest.deployment_manifest(name: deployment_name, instances: 1)
    deploy_simple_manifest(manifest_hash: first_manifest_hash)
  end

  def deploy_with_static_ip(deployment_name, ip, range)
    cloud_config_hash = Bosh::Spec::NetworkingManifest.cloud_config(available_ips: 2, range: range) # 1 for compilation
    cloud_config_hash['networks'].first['subnets'].first['static'] << ip
    upload_cloud_config(cloud_config_hash: cloud_config_hash)

    first_manifest_hash = Bosh::Spec::NetworkingManifest.deployment_manifest(name: deployment_name, instances: 1)
    deploy_with_ips(first_manifest_hash, [ip])
  end

  context 'when allocating static IPs' do
    before do
      create_and_upload_test_release
      upload_stemcell
    end

    let(:cloud_config_hash) do
      cloud_config_hash = Bosh::Spec::NewDeployments.simple_cloud_config
      cloud_config_hash['networks'].first['subnets'].first['static'] = ['192.168.1.10', '192.168.1.11']
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

    # TODO: Remove test when done removing v1 manifest support
    xcontext 'using legacy network configuration (no cloud config)' do
      it 'only recreates VMs that change when the list of static IPs changes' do
        manifest_hash = Bosh::Spec::NetworkingManifest.legacy_deployment_manifest(
          static_ips: ['192.168.1.10', '192.168.1.11', '192.168.1.12'],
          available_ips: 20,
        )

        deploy_legacy_with_ips(manifest_hash, ['192.168.1.10', '192.168.1.11'])
        original_first_instance = director.instances.find { |instance| instance.ips.include? '192.168.1.10' }
        original_second_instance = director.instances.find { |instance| instance.ips.include? '192.168.1.11' }

        deploy_legacy_with_ips(manifest_hash, ['192.168.1.10', '192.168.1.12'])
        new_first_instance = director.instances.find { |instance| instance.ips.include? '192.168.1.10' }
        new_second_instance = director.instances.find { |instance| instance.ips.include? '192.168.1.12' }

        expect(new_first_instance.vm_cid).to eq(original_first_instance.vm_cid)
        expect(new_second_instance.vm_cid).to_not eq(original_second_instance.vm_cid)
      end

      it 'does not release static IPs too early (cant swap job static IPs)' do
        manifest_hash = Bosh::Spec::NetworkingManifest.legacy_deployment_manifest(
          name: 'my-deploy',
          static_ips: ['192.168.1.10', '192.168.1.11'],
          available_ips: 20,
        )

        manifest_hash['jobs'] = [
          Bosh::Spec::Deployments.simple_job(name: 'first-job', static_ips: ['192.168.1.10'], instances: 1),
          Bosh::Spec::Deployments.simple_job(name: 'second-job', static_ips: ['192.168.1.11'], instances: 1),
        ]
        deploy_simple_manifest(manifest_hash: manifest_hash)

        manifest_hash['jobs'] = [
          Bosh::Spec::Deployments.simple_job(name: 'first-job', static_ips: ['192.168.1.11'], instances: 1),
          Bosh::Spec::Deployments.simple_job(name: 'second-job', static_ips: ['192.168.1.10'], instances: 1),
        ]
        output, exit_code = deploy_simple_manifest(manifest_hash: manifest_hash, failure_expected: true, return_exit_code: true)
        expect(exit_code).to_not eq(0)
        expect(output).to include("Failed to reserve IP '192.168.1.11' for 'a': already reserved")
      end
    end
  end
end
