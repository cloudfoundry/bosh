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
    cloud_config_hash = SharedSupport::DeploymentManifestHelper.cloud_config_with_subnet(available_ips: 2, range: range) # 1 for compilation
    upload_cloud_config(cloud_config_hash: cloud_config_hash)

    first_manifest_hash = SharedSupport::DeploymentManifestHelper.deployment_manifest(name: deployment_name, instances: 1)
    deploy_simple_manifest(manifest_hash: first_manifest_hash)
  end

  def deploy_with_static_ip(deployment_name, ip, range)
    cloud_config_hash = SharedSupport::DeploymentManifestHelper.cloud_config_with_subnet(available_ips: 2, range: range) # 1 for compilation
    cloud_config_hash['networks'].first['subnets'].first['static'] << ip
    upload_cloud_config(cloud_config_hash: cloud_config_hash)

    first_manifest_hash = SharedSupport::DeploymentManifestHelper.deployment_manifest(name: deployment_name, instances: 1)
    deploy_with_ips(first_manifest_hash, [ip])
  end

  context 'when allocating static IPs' do
    before do
      create_and_upload_test_release
      upload_stemcell
    end

    let(:cloud_config_hash) do
      cloud_config_hash = SharedSupport::DeploymentManifestHelper.simple_cloud_config
      cloud_config_hash['networks'].first['subnets'].first['static'] = ['192.168.1.10', '192.168.1.11']
      cloud_config_hash
    end

    let(:simple_manifest) do
      manifest_hash = SharedSupport::DeploymentManifestHelper.simple_manifest_with_instance_groups
      manifest_hash['instance_groups'].first['instances'] = 1
      manifest_hash
    end

    let(:second_deployment_manifest) do
      manifest_hash = SharedSupport::DeploymentManifestHelper.simple_manifest_with_instance_groups
      manifest_hash['instance_groups'].first['instances'] = 1
      manifest_hash['name'] = 'second_deployment'
      manifest_hash
    end

    it 'deployments with shared manual network get next available IP from range' do
      upload_cloud_config(cloud_config_hash: cloud_config_hash)

      deploy_simple_manifest(manifest_hash: simple_manifest)
      first_deployment_instances = director.instances
      expect(first_deployment_instances.size).to eq(1)
      expect(first_deployment_instances.first.ips).to eq(['192.168.1.2'])

      deploy_simple_manifest(manifest_hash: second_deployment_manifest)
      second_deployment_instances = director.instances(deployment_name: 'second_deployment')
      expect(second_deployment_instances.size).to eq(1)
      expect(second_deployment_instances.first.ips).to eq(['192.168.1.3'])
    end

    it 'deployments on the same network can not use the same IP' do
      upload_cloud_config(cloud_config_hash: cloud_config_hash)

      deploy_with_ip(simple_manifest, '192.168.1.10')
      first_deployment_instances = director.instances
      expect(first_deployment_instances.size).to eq(1)
      expect(first_deployment_instances.first.ips).to eq(['192.168.1.10'])

      _, exit_code = deploy_with_ip(
        second_deployment_manifest,
        '192.168.1.10',
        failure_expected: true, return_exit_code: true,
      )
      expect(exit_code).to_not eq(0)
    end

    it 'IPs used by a deployment can be used by another deployment once the deployment is deleted' do
      upload_cloud_config(cloud_config_hash: cloud_config_hash)

      deploy_with_ip(simple_manifest, '192.168.1.10')
      first_deployment_instances = director.instances
      expect(first_deployment_instances.size).to eq(1)
      expect(first_deployment_instances.first.ips).to eq(['192.168.1.10'])

      bosh_runner.run('delete-deployment', deployment_name: 'simple')

      deploy_with_ip(second_deployment_manifest, '192.168.1.10')
      second_deployment_instances = director.instances(deployment_name: 'second_deployment')
      expect(second_deployment_instances.size).to eq(1)
      expect(second_deployment_instances.first.ips).to eq(['192.168.1.10'])
    end

    it 'IPs are released after VMs are deleted' do
      upload_cloud_config(cloud_config_hash: cloud_config_hash)

      deploy_with_ip(simple_manifest, '192.168.1.10')
      first_deployment_instances = director.instances
      expect(first_deployment_instances.size).to eq(1)
      expect(first_deployment_instances.first.ips).to eq(['192.168.1.10'])

      current_sandbox.cpi.commands.pause_delete_vms
      output = bosh_runner.run('delete-deployment -d simple', no_track: true)
      delete_deployment_task = Bosh::Spec::OutputParser.new(output).task_id('*')
      current_sandbox.cpi.commands.wait_for_delete_vms

      begin
        # IP should be still reserved until vm is deleted
        _, exit_code = deploy_with_ip(
          second_deployment_manifest,
          '192.168.1.10',
          failure_expected: true, return_exit_code: true,
        )
        expect(exit_code).to_not eq(0)
      ensure
        current_sandbox.cpi.commands.unpause_delete_vms
        wait_for_task(delete_deployment_task)
      end
    end

    it 'IPs released by scaling down a deploymentcan be used by another deployment' do
      upload_cloud_config(cloud_config_hash: cloud_config_hash)

      deploy_with_ips(simple_manifest, ['192.168.1.10', '192.168.1.11'])
      first_deployment_instances = director.instances
      expect(first_deployment_instances.size).to eq(2)
      expect(first_deployment_instances.map(&:ips).flatten).to contain_exactly('192.168.1.10', '192.168.1.11')

      simple_manifest['instance_groups'].first['instances'] = 0
      simple_manifest['instance_groups'].first['networks'].first['static_ips'] = []

      current_sandbox.cpi.commands.pause_delete_vms
      output = deploy_simple_manifest(manifest_hash: simple_manifest, no_track: true)
      scale_down_task = Bosh::Spec::OutputParser.new(output).task_id('*')

      current_sandbox.cpi.commands.wait_for_delete_vms

      # IPs aren't released until the VM is actually deleted
      _, exit_code = deploy_with_ips(
        second_deployment_manifest,
        ['192.168.1.10', '192.168.1.11'],
        failure_expected: true, return_exit_code: true,
      )
      expect(exit_code).to_not eq(0)

      current_sandbox.cpi.commands.unpause_delete_vms

      bosh_runner.run("task #{scale_down_task}")

      deploy_with_ips(second_deployment_manifest, ['192.168.1.10', '192.168.1.11'])
      second_deployment_instances = director.instances(deployment_name: 'second_deployment')
      expect(second_deployment_instances.size).to eq(2)
      expect(second_deployment_instances.map(&:ips).flatten).to contain_exactly('192.168.1.10', '192.168.1.11')
    end

    it 'IPs released by one deployment via changing IP can be used by another deployment' do
      upload_cloud_config(cloud_config_hash: cloud_config_hash)

      deploy_with_ip(simple_manifest, '192.168.1.10')
      first_deployment_instances = director.instances
      expect(first_deployment_instances.size).to eq(1)
      expect(first_deployment_instances.first.ips).to eq(['192.168.1.10'])

      deploy_with_ip(simple_manifest, '192.168.1.11')
      first_deployment_instances = director.instances
      expect(first_deployment_instances.size).to eq(1)
      expect(first_deployment_instances.first.ips).to eq(['192.168.1.11'])

      deploy_with_ip(second_deployment_manifest, '192.168.1.10')
      second_deployment_instances = director.instances(deployment_name: 'second_deployment')
      expect(second_deployment_instances.size).to eq(1)
      expect(second_deployment_instances.first.ips).to eq(['192.168.1.10'])
    end

    it 'IP is still reserved when vm is recreated due to network changes other than IP address' do
      upload_cloud_config(cloud_config_hash: cloud_config_hash)

      deploy_with_ip(simple_manifest, '192.168.1.10')
      first_deployment_instances = director.instances
      expect(first_deployment_instances.size).to eq(1)
      expect(first_deployment_instances.first.ips).to eq(['192.168.1.10'])

      cloud_config_hash['networks'].first['subnets'].first['gateway'] = '192.168.1.15'
      upload_cloud_config(cloud_config_hash: cloud_config_hash)
      deploy_with_ip(simple_manifest, '192.168.1.10')

      first_deployment_instances = director.instances
      expect(first_deployment_instances.size).to eq(1)
      expect(first_deployment_instances.first.ips).to eq(['192.168.1.10'])

      _, exit_code = deploy_with_ip(
        second_deployment_manifest,
        '192.168.1.10',
        failure_expected: true, return_exit_code: true,
      )
      expect(exit_code).to_not eq(0)
    end

    it 'redeploys VM on new IP address when reserved list includes current IP address of VM' do
      upload_cloud_config(cloud_config_hash: cloud_config_hash)

      deploy_simple_manifest(manifest_hash: simple_manifest)
      first_deployment_instances = director.instances
      expect(first_deployment_instances.size).to eq(1)
      expect(first_deployment_instances.first.ips).to eq(['192.168.1.2'])

      cloud_config_hash['networks'].first['subnets'].first['reserved'] = ['192.168.1.2']
      upload_cloud_config(cloud_config_hash: cloud_config_hash)

      deploy_simple_manifest(manifest_hash: simple_manifest)
      first_deployment_instances = director.instances
      expect(first_deployment_instances.size).to eq(1)
      expect(first_deployment_instances.first.ips).to eq(['192.168.1.3'])
    end

    it 'reserved range can be specified as a cidr range' do
      subnet = cloud_config_hash['networks'].first['subnets'].first
      subnet['static'] = []
      subnet['reserved'] = ['192.168.1.1/28'] # 192.168.1.1-192.168.1.15
      upload_cloud_config(cloud_config_hash: cloud_config_hash)

      deploy_simple_manifest(manifest_hash: simple_manifest)

      first_deployment_instances = director.instances
      expect(first_deployment_instances.size).to eq(1)
      expect(first_deployment_instances.first.ips).to eq(['192.168.1.16'])
    end

    it 'only recreates VMs that change when the list of static IPs changes' do
      cloud_config_hash['networks'].first['subnets'].first['static'] << '192.168.1.12'
      upload_cloud_config(cloud_config_hash: cloud_config_hash)

      deploy_with_ips(simple_manifest, ['192.168.1.10', '192.168.1.11'])
      original_first_instance = director.instances.find { |instance| instance.ips.include? '192.168.1.10' }
      original_second_instance = director.instances.find { |instance| instance.ips.include? '192.168.1.11' }

      deploy_with_ips(simple_manifest, ['192.168.1.10', '192.168.1.12'])
      new_first_instance = director.instances.find { |instance| instance.ips.include? '192.168.1.10' }
      new_second_instance = director.instances.find { |instance| instance.ips.include? '192.168.1.12' }

      expect(new_first_instance.vm_cid).to eq(original_first_instance.vm_cid)
      expect(new_second_instance.vm_cid).to_not eq(original_second_instance.vm_cid)
    end

    it 'does not release static IPs too early (cant swap job static IPs)' do
      upload_cloud_config(cloud_config_hash: cloud_config_hash)
      manifest_hash = SharedSupport::DeploymentManifestHelper.deployment_manifest(name: 'my-deploy')

      manifest_hash['instance_groups'] = [
        SharedSupport::DeploymentManifestHelper.simple_instance_group(
          name: 'first-instance-group',
          static_ips: ['192.168.1.10'],
          instances: 1,
        ),
        SharedSupport::DeploymentManifestHelper.simple_instance_group(
          name: 'second-instance-group',
          static_ips: ['192.168.1.11'],
          instances: 1,
        ),
      ]
      deploy_simple_manifest(manifest_hash: manifest_hash)

      manifest_hash['instance_groups'] = [
        SharedSupport::DeploymentManifestHelper.simple_instance_group(
          name: 'first-instance-group',
          static_ips: ['192.168.1.11'],
          instances: 1,
        ),
        SharedSupport::DeploymentManifestHelper.simple_instance_group(
          name: 'second-instance-group',
          static_ips: ['192.168.1.10'],
          instances: 1,
        ),
      ]
      output, exit_code = deploy_simple_manifest(manifest_hash: manifest_hash, failure_expected: true, return_exit_code: true)
      expect(exit_code).to_not eq(0)

      instances = director.instances(deployment_name: 'my-deploy')
      expect(output).to include(
        "Failed to reserve IP '192.168.1.11' for instance " \
        "'first-instance-group/#{instances[0].id} (0)': already reserved by instance " \
        "'second-instance-group/#{instances[1].id}' from deployment 'my-deploy'",
      )
    end

    it 'keeps static IPs reserved when a job fails to deploy its VMs' do
      upload_cloud_config(cloud_config_hash: cloud_config_hash)
      failing_deployment_manifest_hash = SharedSupport::DeploymentManifestHelper.deployment_manifest(name: 'my-deploy', instances: 1)
      other_deployment_manifest_hash = SharedSupport::DeploymentManifestHelper.deployment_manifest(name: 'my-other-deploy', instances: 1)
      failing_deployment_manifest_hash['instance_groups'] = [
        SharedSupport::DeploymentManifestHelper.simple_instance_group(
          name: 'first-instance-group',
          static_ips: ['192.168.1.10'],
          instances: 1,
        ),
      ]

      other_deployment_manifest_hash['instance_groups'] = [
        SharedSupport::DeploymentManifestHelper.simple_instance_group(
          name: 'first-instance-group',
          static_ips: ['192.168.1.10'],
          instances: 1,
        ),
      ]
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
      expect(output).to match(%r{Failed to reserve IP '192.168.1.10' for instance 'first-instance-group\/[a-z0-9\-]+ \(0\)': already reserved by instance 'first-instance-group\/[a-z0-9\-]+' from deployment 'my-deploy'})
    end

    it 'releases IP when subnet range is changed to no longer include it' do
      deploy_with_static_ip('my-deploy', '192.168.1.2', '192.168.1.0/24')
      expect(director.instances(deployment_name: 'my-deploy').map(&:ips).flatten).to eq(['192.168.1.2'])

      deploy_with_static_ip('my-deploy', '192.168.2.2', '192.168.2.0/24')
      expect(director.instances(deployment_name: 'my-deploy').map(&:ips).flatten).to eq(['192.168.2.2'])

      deploy_with_static_ip('other-deploy', '192.168.1.2', '192.168.1.0/24')
      expect(director.instances(deployment_name: 'other-deploy').map(&:ips).flatten).to eq(['192.168.1.2'])
    end

    it 'keeps IP when reservation is changed to dynamic' do
      upload_cloud_config(cloud_config_hash: cloud_config_hash)

      deploy_with_ip(simple_manifest, '192.168.1.10')
      first_deploy_instances = director.instances
      expect(first_deploy_instances.size).to eq(1)
      expect(first_deploy_instances.first.ips).to eq(['192.168.1.10'])

      cloud_config_hash['networks'].first['subnets'].first.delete('static')
      upload_cloud_config(cloud_config_hash: cloud_config_hash)

      simple_manifest['instance_groups'].first['networks'].first.delete('static_ips')
      deploy_simple_manifest(manifest_hash: simple_manifest)
      second_deploy_instances = director.instances
      expect(second_deploy_instances.size).to eq(1)
      expect(second_deploy_instances.first.ips).to eq(['192.168.1.10'])

      expect(second_deploy_instances.first.vm_cid).to eq(first_deploy_instances.first.vm_cid)
    end

    it 'releases IP if reservation is changed to dynamic, but IP still belongs to static range' do
      upload_cloud_config(cloud_config_hash: cloud_config_hash)

      deploy_with_ip(simple_manifest, '192.168.1.10')
      first_deploy_instances = director.instances
      expect(first_deploy_instances.size).to eq(1)
      expect(first_deploy_instances.first.ips).to eq(['192.168.1.10'])

      simple_manifest['instance_groups'].first['networks'].first.delete('static_ips')
      deploy_simple_manifest(manifest_hash: simple_manifest)
      second_deploy_instances = director.instances
      expect(second_deploy_instances.size).to eq(1)
      expect(second_deploy_instances.first.ips).to eq(['192.168.1.2'])
    end
  end
end
