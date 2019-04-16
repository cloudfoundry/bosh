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

  context 'when allocating dynamic IPs' do
    before do
      create_and_upload_test_release
      upload_stemcell
    end

    # TODO: Remove test when done removing v1 manifest support
    xcontext 'using legacy network configuration (no cloud config)' do
      it 'gives the correct error message when there are not enough IPs for compilation (legacy)' do
        manifest_hash = Bosh::Spec::NetworkingManifest.legacy_deployment_manifest({
          name: 'my-deploy',
          instances: 1,
          available_ips: 1,
        })
        output = deploy_simple_manifest(manifest_hash: manifest_hash, failure_expected: true)
        expect(output).to match(/Failed to reserve IP for 'compilation-.*' for manual network 'a': no more available/)
      end

      it 'gives the correct error message when there are not enough IPs for instances' do
        # needs 1 extra IP for compilation
        new_manifest_hash = Bosh::Spec::NetworkingManifest.legacy_deployment_manifest(
          name: 'my-deploy',
          instances: 2,
          available_ips: 2,
        )

        output, exit_code = deploy_simple_manifest(
          manifest_hash: new_manifest_hash,
          failure_expected: true,
          return_exit_code: true,
        )

        expect(exit_code).not_to eq(0)
        expect(output).to match(/Failed to reserve IP for 'compilation-.*' for manual network 'a': no more available/)
      end

      it 'gives VMs the same IP on redeploy' do
        manifest_hash = Bosh::Spec::NetworkingManifest.legacy_deployment_manifest(
          name: 'my-deploy',
          instances: 2,
          available_ips: 5,
        )

        deploy_simple_manifest(manifest_hash: manifest_hash)
        original_ips = director.instances(deployment_name: 'my-deploy').map(&:ips).flatten

        manifest_hash['jobs'].first['properties']['test_property'] = 'new value' # force re-deploy
        output = deploy_simple_manifest(manifest_hash: manifest_hash)
        expect(output).to include('Updating instance foobar') # actually re-deployed
        expect(output).to include('Succeeded') # actually re-deployed
        new_ips = director.instances(deployment_name: 'my-deploy').map(&:ips).flatten

        expect(new_ips).to eq(original_ips)
      end

      it 'gives VMs the same IP on `deploy --recreate`', no_create_swap_delete: true do
        manifest_hash = Bosh::Spec::NetworkingManifest.legacy_deployment_manifest(
          name: 'my-deploy',
          instances: 2,
          available_ips: 5,
        )

        deploy_simple_manifest(manifest_hash: manifest_hash)
        instances = director.instances(deployment_name: 'my-deploy')
        original_ips = instances.map(&:ips).flatten
        original_cids = instances.map(&:vm_cid)

        deploy_simple_manifest(manifest_hash: manifest_hash, recreate: true)
        instances = director.instances(deployment_name: 'my-deploy')
        new_ips = instances.map(&:ips).flatten
        new_cids = instances.map(&:vm_cid)

        expect(new_cids).to_not match_array(original_cids)
        expect(new_ips).to match_array(original_ips)
      end

      it 'gives VMs new IPs on `deploy --recreate`', create_swap_delete: true do
        manifest_hash = Bosh::Spec::NetworkingManifest.legacy_deployment_manifest(
          name: 'my-deploy',
          instances: 2,
          available_ips: 5,
        )

        deploy_simple_manifest(manifest_hash: manifest_hash)
        instances = director.instances(deployment_name: 'my-deploy')
        original_ips = instances.map(&:ips).flatten
        original_cids = instances.map(&:vm_cid)

        deploy_simple_manifest(manifest_hash: manifest_hash, recreate: true)
        instances = director.instances(deployment_name: 'my-deploy')
        new_ips = instances.map(&:ips).flatten
        new_cids = instances.map(&:vm_cid)

        expect(new_cids).not_to match_array(original_cids)
        expect(new_ips).not_to match_array(original_ips)
      end

      it 'redeploys VM on new IP address when reserved list includes current IP address of VM' do
        manifest_hash = Bosh::Spec::NetworkingManifest.legacy_deployment_manifest(
          name: 'my-deploy',
          instances: 1,
          available_ips: 2,
        )

        deploy_simple_manifest(manifest_hash: manifest_hash)
        original_ips = director.instances(deployment_name: 'my-deploy').map(&:ips).flatten
        expect(original_ips).to eq(['192.168.1.2'])

        manifest_hash = Bosh::Spec::NetworkingManifest.legacy_deployment_manifest(
          name: 'my-deploy',
          instances: 1,
          available_ips: 2,
          shift_ip_range_by: 1,
        )

        deploy_simple_manifest(manifest_hash: manifest_hash)
        new_ips = director.instances(deployment_name: 'my-deploy').map(&:ips).flatten
        expect(new_ips).to eq(['192.168.1.3'])
      end
    end
  end
end
