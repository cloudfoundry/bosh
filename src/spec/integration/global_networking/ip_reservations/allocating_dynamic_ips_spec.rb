require 'spec_helper'

describe 'global networking', type: :integration do
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

    it 'gives the correct error message when there are not enough IPs for compilation' do
      cloud_config_hash = Bosh::Spec::NetworkingManifest.cloud_config(available_ips: 1)
      manifest_hash = Bosh::Spec::NetworkingManifest.deployment_manifest(name: 'my-deploy', instances: 1)

      upload_cloud_config(cloud_config_hash: cloud_config_hash)
      output = deploy_simple_manifest(manifest_hash: manifest_hash, failure_expected: true)
      expect(output).to match(/Failed to reserve IP for 'compilation-.*' for manual network 'a': no more available/)
    end

    it 'updates deployment when there is enough IPs for compilation' do
      cloud_config_hash = Bosh::Spec::NetworkingManifest.cloud_config(available_ips: 2)
      manifest_hash = Bosh::Spec::NetworkingManifest.deployment_manifest(name: 'my-deploy', instances: 1)

      upload_cloud_config(cloud_config_hash: cloud_config_hash)
      deploy_simple_manifest(manifest_hash: manifest_hash)

      update_release

      deploy_simple_manifest(manifest_hash: manifest_hash)
      expect(director.instances(deployment_name: 'my-deploy').map(&:ips).flatten).to eq(['192.168.1.2'])
    end

    it 'gives VMs the same IP on redeploy' do
      cloud_config_hash = Bosh::Spec::NetworkingManifest.cloud_config(available_ips: 5)
      manifest_hash = Bosh::Spec::NetworkingManifest.deployment_manifest(name: 'my-deploy', instances: 2)

      upload_cloud_config(cloud_config_hash: cloud_config_hash)
      deploy_simple_manifest(manifest_hash: manifest_hash)
      original_ips = director.instances(deployment_name: 'my-deploy').map(&:ips).flatten

      manifest_hash['instance_groups'].first['jobs'].first['properties'].merge!('test_property' => 'new value') # force re-deploy
      output = deploy_simple_manifest(manifest_hash: manifest_hash)
      expect(output).to include('Updating instance foobar') # actually re-deployed
      new_ips = director.instances(deployment_name: 'my-deploy').map(&:ips).flatten

      expect(new_ips).to eq(original_ips)
    end

    it 'gives VMs the same IP on `deploy --recreate`', no_create_swap_delete: true do
      cloud_config_hash = Bosh::Spec::NetworkingManifest.cloud_config(available_ips: 5)
      manifest_hash = Bosh::Spec::NetworkingManifest.deployment_manifest(name: 'my-deploy', instances: 2)

      upload_cloud_config(cloud_config_hash: cloud_config_hash)
      deploy_simple_manifest(manifest_hash: manifest_hash)
      original_ips = director.instances(deployment_name: 'my-deploy').map(&:ips).flatten
      original_cids = director.instances(deployment_name: 'my-deploy').map(&:vm_cid)

      deploy_simple_manifest(manifest_hash: manifest_hash, recreate: true)
      new_ips = director.instances(deployment_name: 'my-deploy').map(&:ips).flatten
      new_cids = director.instances(deployment_name: 'my-deploy').map(&:vm_cid)

      expect(new_cids).to_not match_array(original_cids)
      expect(new_ips).to match_array(original_ips)
    end

    it 'gives VMs different IPs on `deploy --recreate`', create_swap_delete: true do
      cloud_config_hash = Bosh::Spec::NetworkingManifest.cloud_config(available_ips: 5)
      manifest_hash = Bosh::Spec::NetworkingManifest.deployment_manifest(name: 'my-deploy', instances: 2)

      upload_cloud_config(cloud_config_hash: cloud_config_hash)
      deploy_simple_manifest(manifest_hash: manifest_hash)
      original_ips = director.instances(deployment_name: 'my-deploy').map(&:ips).flatten
      original_cids = director.instances(deployment_name: 'my-deploy').map(&:vm_cid)

      deploy_simple_manifest(manifest_hash: manifest_hash, recreate: true)
      new_ips = director.instances(deployment_name: 'my-deploy').map(&:ips).flatten
      new_cids = director.instances(deployment_name: 'my-deploy').map(&:vm_cid)

      expect(new_cids).to_not match_array(original_cids)
      expect(new_ips).not_to match_array(original_ips)
    end

    it 'gives the correct error message when there are not enough IPs for instances' do
      new_cloud_config_hash = Bosh::Spec::NetworkingManifest.cloud_config(available_ips: 1)
      manifest_hash = Bosh::Spec::NetworkingManifest.deployment_manifest(
        name: 'my-deploy',
        instances: 2,
        job: 'foobar_without_packages',
      )

      upload_cloud_config(cloud_config_hash: new_cloud_config_hash)
      output, exit_code = deploy_simple_manifest(manifest_hash: manifest_hash, failure_expected: true, return_exit_code: true)

      expect(exit_code).not_to eq(0)
      expect(output).to match(%r{Failed to reserve IP for 'foobar\/[a-z0-9\-]+ \(1\)' for manual network 'a': no more available})
    end

    it 'does not reuse IP if one job is deleted and another created within a single deployment' do
      # Until https://www.pivotaltracker.com/story/show/98057020 we cannot reuse the same IP
      # within single deployment

      cloud_config_hash = Bosh::Spec::NetworkingManifest.cloud_config(available_ips: 1)
      manifest_hash = Bosh::Spec::NetworkingManifest.deployment_manifest(name: 'my-deploy')
      manifest_hash['instance_groups'] = [Bosh::Spec::Deployments.simple_instance_group(
        name: 'first-instance-group',
        instances: 1,
        job_name: 'foobar_without_packages',
      )]

      upload_cloud_config(cloud_config_hash: cloud_config_hash)

      deploy_simple_manifest(manifest_hash: manifest_hash)

      expect_running_vms_with_names_and_count({ 'first-instance-group' => 1 }, { deployment_name: 'my-deploy' })

      manifest_hash['instance_groups'] = [
        Bosh::Spec::Deployments.simple_instance_group(name: 'second-instance-group', instances: 1),
      ]
      output = deploy_simple_manifest(manifest_hash: manifest_hash, failure_expected: true)
      expect(output).to include('no more available')
    end

    it 'keeps IPs of a job when that job fails to deploy its VMs' do
      cloud_config_hash = Bosh::Spec::NetworkingManifest.cloud_config(available_ips: 2)
      failing_deployment_manifest_hash = Bosh::Spec::NetworkingManifest.deployment_manifest(name: 'my-deploy', instances: 2)
      other_deployment_manifest_hash = Bosh::Spec::NetworkingManifest.deployment_manifest(name: 'my-other-deploy', instances: 1)
      upload_cloud_config(cloud_config_hash: cloud_config_hash)

      current_sandbox.cpi.commands.make_create_vm_always_fail
      _, exit_code = deploy_simple_manifest(
        manifest_hash: failing_deployment_manifest_hash,
        failure_expected: true,
        return_exit_code: true,
      )
      expect(exit_code).not_to eq(0)

      current_sandbox.cpi.commands.allow_create_vm_to_succeed
      output, exit_code = deploy_simple_manifest(
        manifest_hash: other_deployment_manifest_hash,
        failure_expected: true,
        return_exit_code: true,
      )

      # all IPs still reserved
      expect(exit_code).not_to eq(0)
      expect(output).to match(%r{Failed to reserve IP for 'foobar\/[a-z0-9\-]+ \(0\)' for manual network 'a': no more available})
    end

    it 'redeploys VM on new IP address when reserved list includes current IP address of VM' do
      cloud_config_hash = Bosh::Spec::NetworkingManifest.cloud_config(available_ips: 2)
      manifest_hash = Bosh::Spec::NetworkingManifest.deployment_manifest(name: 'my-deploy', instances: 1)
      upload_cloud_config(cloud_config_hash: cloud_config_hash)

      deploy_simple_manifest(manifest_hash: manifest_hash)
      original_ips = director.instances(deployment_name: 'my-deploy').map(&:ips).flatten
      expect(original_ips).to eq(['192.168.1.2'])

      new_cloud_config_hash = Bosh::Spec::NetworkingManifest.cloud_config(available_ips: 2, shift_ip_range_by: 1)
      upload_cloud_config(cloud_config_hash: new_cloud_config_hash)

      deploy_simple_manifest(manifest_hash: manifest_hash)
      new_ips = director.instances(deployment_name: 'my-deploy').map(&:ips).flatten
      expect(new_ips).to eq(['192.168.1.3'])
    end

    it 'can use IP that is no longer in reserved section' do
      cloud_config_hash = Bosh::Spec::NetworkingManifest.cloud_config(available_ips: 2, shift_ip_range_by: 1)
      upload_cloud_config(cloud_config_hash: cloud_config_hash)

      manifest_hash = Bosh::Spec::NetworkingManifest.deployment_manifest(name: 'my-deploy', instances: 1)
      deploy_simple_manifest(manifest_hash: manifest_hash)
      new_ips = director.instances(deployment_name: 'my-deploy').map(&:ips).flatten
      expect(new_ips).to eq(['192.168.1.3'])

      new_cloud_config_hash = Bosh::Spec::NetworkingManifest.cloud_config(available_ips: 2)
      upload_cloud_config(cloud_config_hash: new_cloud_config_hash)

      manifest_hash = Bosh::Spec::NetworkingManifest.deployment_manifest(name: 'my-deploy', instances: 2)
      deploy_simple_manifest(manifest_hash: manifest_hash)
      new_ips = director.instances(deployment_name: 'my-deploy').map(&:ips).flatten
      expect(new_ips).to match_array(['192.168.1.2', '192.168.1.3'])
    end

    # Skipping in create-swap-delete mode: we are currently not deleting orphaned VMs
    it 'releases IP when subnet range is changed to no longer include it', no_create_swap_delete: true do
      deploy_with_range('my-deploy', '192.168.1.0/24')
      expect(director.instances(deployment_name: 'my-deploy').map(&:ips).flatten).to eq(['192.168.1.2'])

      deploy_with_range('my-deploy', '192.168.2.0/24')
      expect(director.instances(deployment_name: 'my-deploy').map(&:ips).flatten).to eq(['192.168.2.2'])

      deploy_with_range('other-deploy', '192.168.1.0/24')
      expect(director.instances(deployment_name: 'other-deploy').map(&:ips).flatten).to eq(['192.168.1.2'])
    end

    it 'keeps IP when reservation is changed to static' do
      cloud_config_hash = Bosh::Spec::NetworkingManifest.cloud_config(available_ips: 2)
      upload_cloud_config(cloud_config_hash: cloud_config_hash)

      simple_manifest = Bosh::Spec::NetworkingManifest.deployment_manifest(instances: 1)
      deploy_simple_manifest(manifest_hash: simple_manifest)
      first_deploy_instances = director.instances
      expect(first_deploy_instances.size).to eq(1)
      expect(first_deploy_instances.first.ips).to eq(['192.168.1.2'])

      cloud_config_hash['networks'].first['subnets'].first['static'] = ['192.168.1.2']
      upload_cloud_config(cloud_config_hash: cloud_config_hash)

      deploy_with_ip(simple_manifest, '192.168.1.2')
      second_deploy_instances = director.instances
      expect(second_deploy_instances.size).to eq(1)

      expect(second_deploy_instances.first.ips).to eq(first_deploy_instances.first.ips)
      expect(second_deploy_instances.first.vm_cid).to eq(first_deploy_instances.first.vm_cid)
    end
  end
end
