require 'spec_helper'

describe 'global networking', type: :integration do
  with_reset_sandbox_before_each

  context 'when allocating static IPs' do
    before do
      target_and_login
      create_and_upload_test_release
      upload_stemcell
      upload_cloud_config(cloud_config_hash: cloud_config_hash)
    end

    let(:cloud_config_hash) do
      cloud_config_hash = Bosh::Spec::Deployments.simple_cloud_config
      # remove size from resource pools due to bug #94220432
      # where resource pools with specified size reserve extra IPs
      cloud_config_hash['resource_pools'].first.delete('size')

      cloud_config_hash['networks'].first['subnets'].first['static'] = ['192.168.1.10', '192.168.1.11']
      cloud_config_hash
    end

    let(:simple_manifest) do
      manifest_hash = Bosh::Spec::Deployments.simple_manifest
      manifest_hash['jobs'].first['instances'] = 1
      manifest_hash
    end

    let(:second_deployment_manifest) do
      manifest_hash = Bosh::Spec::Deployments.simple_manifest
      manifest_hash['jobs'].first['instances'] = 1
      manifest_hash['name'] = 'second_deployment'
      manifest_hash
    end

    def deploy_with_ip(manifest, ip, options={})
      deploy_with_ips(manifest, [ip], options)
    end

    def deploy_with_ips(manifest, ips, options={})
      manifest['jobs'].first['networks'].first['static_ips'] = ips
      manifest['jobs'].first['instances'] = ips.size
      options.merge!(manifest_hash: manifest)
      deploy_simple_manifest(options)
    end


    it 'deployments with shared manual network get next available IP from range' do
      deploy_simple_manifest(manifest_hash: simple_manifest)
      first_deployment_vms = director.vms
      expect(first_deployment_vms.size).to eq(1)
      expect(first_deployment_vms.first.ips).to eq('192.168.1.2')

      deploy_simple_manifest(manifest_hash: second_deployment_manifest)
      second_deployment_vms = director.vms('second_deployment')
      expect(second_deployment_vms.size).to eq(1)
      expect(second_deployment_vms.first.ips).to eq('192.168.1.3')
    end

    it 'deployments on the same network can not use the same IP' do
      deploy_with_ip(simple_manifest, '192.168.1.10')
      first_deployment_vms = director.vms
      expect(first_deployment_vms.size).to eq(1)
      expect(first_deployment_vms.first.ips).to eq('192.168.1.10')

      _, exit_code = deploy_with_ip(
        second_deployment_manifest,
        '192.168.1.10',
        {failure_expected: true, return_exit_code: true}
      )
      expect(exit_code).to_not eq(0)
    end

    it 'IPs used by one deployment can be used by another deployment after first deployment is deleted' do
      deploy_with_ip(simple_manifest, '192.168.1.10')
      first_deployment_vms = director.vms
      expect(first_deployment_vms.size).to eq(1)
      expect(first_deployment_vms.first.ips).to eq('192.168.1.10')

      bosh_runner.run('delete deployment simple')

      deploy_with_ip(second_deployment_manifest, '192.168.1.10')
      second_deployment_vms = director.vms('second_deployment')
      expect(second_deployment_vms.size).to eq(1)
      expect(second_deployment_vms.first.ips).to eq('192.168.1.10')
    end

    it 'IPs released by one deployment via scaling down can be used by another deployment' do
      deploy_with_ips(simple_manifest, ['192.168.1.10', '192.168.1.11'])
      first_deployment_vms = director.vms
      expect(first_deployment_vms.size).to eq(2)
      expect(first_deployment_vms.first.ips).to eq('192.168.1.10')
      expect(first_deployment_vms[1].ips).to eq('192.168.1.11')

      simple_manifest['jobs'].first['instances'] = 0
      simple_manifest['jobs'].first['networks'].first['static_ips'] = []


      current_sandbox.cpi.commands.pause_delete_vms
      deploy_simple_manifest(manifest_hash: simple_manifest, no_track: true)

      current_sandbox.cpi.commands.wait_for_delete_vms
      _, exit_code = deploy_with_ips(
        second_deployment_manifest,
        ['192.168.1.10', '192.168.1.11'],
        {failure_expected: true, return_exit_code: true}
      )
      expect(exit_code).to_not eq(0)

      current_sandbox.cpi.commands.unpause_delete_vms

      deploy_with_ips(second_deployment_manifest, ['192.168.1.10', '192.168.1.11'])
      second_deployment_vms = director.vms('second_deployment')
      expect(second_deployment_vms.size).to eq(2)
      expect(second_deployment_vms.first.ips).to eq('192.168.1.10')
      expect(second_deployment_vms[1].ips).to eq('192.168.1.11')
    end

    it 'IPs released by one deployment via changing IP can be used by another deployment' do
      deploy_with_ip(simple_manifest, '192.168.1.10')
      first_deployment_vms = director.vms
      expect(first_deployment_vms.size).to eq(1)
      expect(first_deployment_vms.first.ips).to eq('192.168.1.10')

      deploy_with_ip(simple_manifest, '192.168.1.11')
      first_deployment_vms = director.vms
      expect(first_deployment_vms.size).to eq(1)
      expect(first_deployment_vms.first.ips).to eq('192.168.1.11')

      deploy_with_ip(second_deployment_manifest, '192.168.1.10')
      second_deployment_vms = director.vms('second_deployment')
      expect(second_deployment_vms.size).to eq(1)
      expect(second_deployment_vms.first.ips).to eq('192.168.1.10')
    end

    it 'IP is still reserved when vm is recreated due to network changes other than IP address' do
      deploy_with_ip(simple_manifest, '192.168.1.10')
      first_deployment_vms = director.vms
      expect(first_deployment_vms.size).to eq(1)
      expect(first_deployment_vms.first.ips).to eq('192.168.1.10')

      cloud_config_hash['networks'].first['subnets'].first['gateway'] = '192.168.1.15'
      upload_cloud_config(cloud_config_hash: cloud_config_hash)
      deploy_with_ip(simple_manifest, '192.168.1.10')

      first_deployment_vms = director.vms
      expect(first_deployment_vms.size).to eq(1)
      expect(first_deployment_vms.first.ips).to eq('192.168.1.10')

      _, exit_code = deploy_with_ip(
        second_deployment_manifest,
        '192.168.1.10',
        {failure_expected: true, return_exit_code: true}
      )
      expect(exit_code).to_not eq(0)
    end

    it 'redeploys VM on new IP address when reserved list includes current IP address of VM' do
      deploy_simple_manifest(manifest_hash: simple_manifest)
      first_deployment_vms = director.vms
      expect(first_deployment_vms.size).to eq(1)
      expect(first_deployment_vms.first.ips).to eq('192.168.1.2')

      cloud_config_hash['networks'].first['subnets'].first['reserved'] = ['192.168.1.2']
      upload_cloud_config(cloud_config_hash: cloud_config_hash)

      deploy_simple_manifest(manifest_hash: simple_manifest)
      first_deployment_vms = director.vms
      expect(first_deployment_vms.size).to eq(1)
      expect(first_deployment_vms.first.ips).to eq('192.168.1.3')
    end

    it 'only recreates VMs that change when the list of static IPs changes' do
      cloud_config_hash['networks'].first['subnets'].first['static'] << '192.168.1.12'
      upload_cloud_config(cloud_config_hash: cloud_config_hash)

      deploy_with_ips(simple_manifest, ['192.168.1.10', '192.168.1.11'])
      original_first_instance = director.vms.find { |vm| vm.ips == '192.168.1.10'}
      original_second_instance = director.vms.find { |vm| vm.ips == '192.168.1.11'}

      deploy_with_ips(simple_manifest, ['192.168.1.10', '192.168.1.12'])
      new_first_instance = director.vms.find { |vm| vm.ips == '192.168.1.10'}
      new_second_instance = director.vms.find { |vm| vm.ips == '192.168.1.12'}

      expect(new_first_instance.cid).to eq(original_first_instance.cid)
      expect(new_second_instance.cid).to_not eq(original_second_instance.cid)
    end
  end

  context 'when allocating dynamic IPs' do
    before do
      target_and_login
      create_and_upload_test_release
      upload_stemcell
    end

    it 'reuses the compilation VMs IP (can deploy a job with 1 instance with only 1 IP available)' do
      cloud_config_hash = Bosh::Spec::NetworkingManifest.cloud_config(available_ips: 1)
      manifest_hash = Bosh::Spec::NetworkingManifest.deployment_manifest(name: 'my-deploy', instances: 1)

      upload_cloud_config(cloud_config_hash: cloud_config_hash)
      deploy_simple_manifest(manifest_hash: manifest_hash)

      expect(director.vms('my-deploy').map(&:ips).flatten).to eq(['192.168.1.2'])
    end

    it 'gives VMs the same IP on redeploy' do
      cloud_config_hash = Bosh::Spec::NetworkingManifest.cloud_config(available_ips: 5)
      manifest_hash = Bosh::Spec::NetworkingManifest.deployment_manifest(name: 'my-deploy', instances: 2)

      upload_cloud_config(cloud_config_hash: cloud_config_hash)
      deploy_simple_manifest(manifest_hash: manifest_hash)
      original_ips = director.vms('my-deploy').map(&:ips).flatten

      manifest_hash['jobs'].first['properties'].merge!('test_property' => 'new value') # force re-deploy
      output = deploy_simple_manifest(manifest_hash: manifest_hash)
      expect(output).to include('Started updating job foobar') # actually re-deployed
      new_ips = director.vms('my-deploy').map(&:ips).flatten

      expect(new_ips).to eq(original_ips)
    end

    it 'gives VMs the same IP on `deploy --recreate`' do
      cloud_config_hash = Bosh::Spec::NetworkingManifest.cloud_config(available_ips: 5)
      manifest_hash = Bosh::Spec::NetworkingManifest.deployment_manifest(name: 'my-deploy', instances: 2)

      upload_cloud_config(cloud_config_hash: cloud_config_hash)
      deploy_simple_manifest(manifest_hash: manifest_hash)
      original_ips = director.vms('my-deploy').map(&:ips).flatten
      original_cids = director.vms('my-deploy').map(&:cid)

      deploy_simple_manifest(manifest_hash: manifest_hash, recreate: true)
      new_ips = director.vms('my-deploy').map(&:ips).flatten
      new_cids = director.vms('my-deploy').map(&:cid)

      expect(new_cids).to_not match_array(original_cids)
      expect(new_ips).to match_array(original_ips)
    end

    it 'gives the correct error message when there are not enough IPs' do
      cloud_config_hash = Bosh::Spec::NetworkingManifest.cloud_config(available_ips: 2)
      manifest_hash = Bosh::Spec::NetworkingManifest.deployment_manifest(name: 'my-deploy', instances: 2)

      upload_cloud_config(cloud_config_hash: cloud_config_hash)
      deploy_simple_manifest(manifest_hash: manifest_hash)

      new_cloud_config_hash = Bosh::Spec::NetworkingManifest.cloud_config(available_ips: 1)
      upload_cloud_config(cloud_config_hash: new_cloud_config_hash)
      output, exit_code = deploy_simple_manifest(manifest_hash: manifest_hash, failure_expected: true, return_exit_status: true)

      expect(exit_code).not_to eq(0)
      expect(output).to include("asked for a dynamic IP but there were no more available")
    end

    it 'reuses IPs when one job is deleted and another created within a single deployment' do
      pending("https://www.pivotaltracker.com/story/show/98057020")
      cloud_config_hash = Bosh::Spec::NetworkingManifest.cloud_config(available_ips: 1)
      manifest_hash = Bosh::Spec::NetworkingManifest.deployment_manifest(name: 'my-deploy')
      manifest_hash['jobs'] = [Bosh::Spec::Deployments.simple_job(name: 'first-job', instances: 1)]

      upload_cloud_config(cloud_config_hash: cloud_config_hash)

      deploy_simple_manifest(manifest_hash: manifest_hash)
      expect(director.vms('my-deploy').map(&:job_name_index)).to eq(['first-job/0'])

      manifest_hash['jobs'] = [Bosh::Spec::Deployments.simple_job(name: 'second-job', instances: 1)]
      deploy_simple_manifest(manifest_hash: manifest_hash)
      expect(director.vms('my-deploy').map(&:job_name_index)).to eq(['second-job/0'])
    end

    it 'keeps IPs of a job when that job fails to deploy its VMs' do
      pending("https://www.pivotaltracker.com/story/show/98127770")
      cloud_config_hash = Bosh::Spec::NetworkingManifest.cloud_config(available_ips: 2)
      failing_deployment_manifest_hash = Bosh::Spec::NetworkingManifest.deployment_manifest(name: 'my-deploy', instances: 2)
      other_deployment_manifest_hash = Bosh::Spec::NetworkingManifest.deployment_manifest(name: 'my-other-deploy', instances: 1)
      upload_cloud_config(cloud_config_hash: cloud_config_hash)

      current_sandbox.cpi.commands.make_create_vm_always_fail
      _, exit_code = deploy_simple_manifest(manifest_hash: failing_deployment_manifest_hash, failure_expected: true, return_exit_status: true)
      expect(exit_code).not_to eq(0)

      current_sandbox.cpi.commands.allow_create_vm_to_succeed
      output, exit_code = deploy_simple_manifest(manifest_hash: other_deployment_manifest_hash, failure_expected: true, return_exit_status: true)

      # all IPs still reserved
      expect(exit_code).not_to eq(0)
      expect(output).to include('asked for a dynamic IP but there were no more available')
    end
  end
end
