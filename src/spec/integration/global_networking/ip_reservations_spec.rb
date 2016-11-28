require 'spec_helper'

describe 'global networking', type: :integration do
  with_reset_sandbox_before_each

  def deploy_with_ip(manifest, ip, options={})
    deploy_with_ips(manifest, [ip], options)
  end

  def deploy_with_ips(manifest, ips, options={})
    manifest['jobs'].first['networks'].first['static_ips'] = ips
    manifest['jobs'].first['instances'] = ips.size
    options.merge!(manifest_hash: manifest)
    deploy_simple_manifest(options)
  end

  context 'when allocating static IPs' do
    before do
      target_and_login
      create_and_upload_test_release
      upload_stemcell
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

    it 'deployments with shared manual network get next available IP from range' do
      upload_cloud_config(cloud_config_hash: cloud_config_hash)

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

    it 'IPs used by one deployment can be used by another deployment after first deployment is deleted' do
      upload_cloud_config(cloud_config_hash: cloud_config_hash)

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

    it 'IPs are released after VMs are deleted' do
      upload_cloud_config(cloud_config_hash: cloud_config_hash)

      deploy_with_ip(simple_manifest, '192.168.1.10')
      first_deployment_vms = director.vms
      expect(first_deployment_vms.size).to eq(1)
      expect(first_deployment_vms.first.ips).to eq('192.168.1.10')

      current_sandbox.cpi.commands.pause_delete_vms
      output = bosh_runner.run('--no-track delete deployment simple')
      delete_deployment_task = Bosh::Spec::OutputParser.new(output).task_id('running')
      current_sandbox.cpi.commands.wait_for_delete_vms

      begin
        # IP should be still reserved until vm is deleted
        _, exit_code = deploy_with_ip(
          second_deployment_manifest,
          '192.168.1.10',
          {failure_expected: true, return_exit_code: true}
        )
        expect(exit_code).to_not eq(0)
      ensure
        current_sandbox.cpi.commands.unpause_delete_vms
        Bosh::Spec::DeployHelper.wait_for_task(delete_deployment_task)
      end
    end

    it 'IPs released by one deployment via scaling down can be used by another deployment' do
      upload_cloud_config(cloud_config_hash: cloud_config_hash)

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

      # IPs aren't released until the VM is actually deleted
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
      upload_cloud_config(cloud_config_hash: cloud_config_hash)

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
      upload_cloud_config(cloud_config_hash: cloud_config_hash)

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
      upload_cloud_config(cloud_config_hash: cloud_config_hash)

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

    it 'does not release static IPs too early (cant swap job static IPs)' do
      upload_cloud_config(cloud_config_hash: cloud_config_hash)
      manifest_hash = Bosh::Spec::NetworkingManifest.deployment_manifest(name: 'my-deploy')

      manifest_hash['jobs'] = [
        Bosh::Spec::Deployments.simple_job(name: 'first-job', static_ips: ['192.168.1.10'], instances: 1),
        Bosh::Spec::Deployments.simple_job(name: 'second-job', static_ips: ['192.168.1.11'], instances: 1)
      ]
      deploy_simple_manifest(manifest_hash: manifest_hash)

      manifest_hash['jobs'] = [
        Bosh::Spec::Deployments.simple_job(name: 'first-job', static_ips: ['192.168.1.11'], instances: 1),
        Bosh::Spec::Deployments.simple_job(name: 'second-job', static_ips: ['192.168.1.10'], instances: 1)
      ]
      output, exit_code = deploy_simple_manifest(manifest_hash: manifest_hash, failure_expected: true, return_exit_code: true)
      expect(exit_code).to_not eq(0)

      vms = director.vms
      expect(output).to include("Failed to reserve IP '192.168.1.11' for instance 'first-job/#{vms[0].instance_uuid} (0)': already reserved by instance 'second-job/#{vms[1].instance_uuid}' from deployment 'my-deploy'")
    end

    it 'keeps static IPs reserved when a job fails to deploy its VMs' do
      upload_cloud_config(cloud_config_hash: cloud_config_hash)
      failing_deployment_manifest_hash = Bosh::Spec::NetworkingManifest.deployment_manifest(name: 'my-deploy', instances: 1)
      other_deployment_manifest_hash = Bosh::Spec::NetworkingManifest.deployment_manifest(name: 'my-other-deploy', instances: 1)
      failing_deployment_manifest_hash['jobs'] = [
        Bosh::Spec::Deployments.simple_job(name: 'first-job', static_ips: ['192.168.1.10'], instances: 1)
      ]

      other_deployment_manifest_hash['jobs'] = [
        Bosh::Spec::Deployments.simple_job(name: 'first-job', static_ips: ['192.168.1.10'], instances: 1)
      ]
      current_sandbox.cpi.commands.make_create_vm_always_fail
      _, exit_code = deploy_simple_manifest(manifest_hash: failing_deployment_manifest_hash, failure_expected: true, return_exit_code: true)
      expect(exit_code).not_to eq(0)

      current_sandbox.cpi.commands.allow_create_vm_to_succeed
      output, exit_code = deploy_simple_manifest(manifest_hash: other_deployment_manifest_hash, failure_expected: true, return_exit_code: true)

      # all IPs still reserved
      expect(exit_code).not_to eq(0)
      expect(output).to match(/Failed to reserve IP '192.168.1.10' for instance 'first-job\/[a-z0-9\-]+ \(0\)': already reserved by instance 'first-job\/[a-z0-9\-]+' from deployment 'my-deploy'/)
    end

    def deploy_with_static_ip(deployment_name, ip, range)
      cloud_config_hash = Bosh::Spec::NetworkingManifest.cloud_config(available_ips: 2, range: range) # 1 for compilation
      cloud_config_hash['networks'].first['subnets'].first['static'] << ip
      upload_cloud_config(cloud_config_hash: cloud_config_hash)

      first_manifest_hash = Bosh::Spec::NetworkingManifest.deployment_manifest(name: deployment_name, instances: 1)
      deploy_with_ips(first_manifest_hash, [ip])
    end

    it 'releases IP when subnet range is changed to no longer include it' do
      deploy_with_static_ip('my-deploy', '192.168.1.2', '192.168.1.0/24')
      expect(director.vms('my-deploy').map(&:ips).flatten).to eq(['192.168.1.2'])

      deploy_with_static_ip('my-deploy', '192.168.2.2', '192.168.2.0/24')
      expect(director.vms('my-deploy').map(&:ips).flatten).to eq(['192.168.2.2'])

      deploy_with_static_ip('other-deploy', '192.168.1.2', '192.168.1.0/24')
      expect(director.vms('other-deploy').map(&:ips).flatten).to eq(['192.168.1.2'])
    end

    context 'using legacy network configuration (no cloud config)' do
      it 'only recreates VMs that change when the list of static IPs changes' do
        manifest_hash = Bosh::Spec::NetworkingManifest.legacy_deployment_manifest(
          static_ips: ['192.168.1.10','192.168.1.11','192.168.1.12'],
          available_ips: 20
        )

        deploy_with_ips(manifest_hash, ['192.168.1.10', '192.168.1.11'])
        original_first_instance = director.vms.find { |vm| vm.ips == '192.168.1.10'}
        original_second_instance = director.vms.find { |vm| vm.ips == '192.168.1.11'}

        deploy_with_ips(manifest_hash, ['192.168.1.10', '192.168.1.12'])
        new_first_instance = director.vms.find { |vm| vm.ips == '192.168.1.10'}
        new_second_instance = director.vms.find { |vm| vm.ips == '192.168.1.12'}

        expect(new_first_instance.cid).to eq(original_first_instance.cid)
        expect(new_second_instance.cid).to_not eq(original_second_instance.cid)
      end

      it 'does not release static IPs too early (cant swap job static IPs)' do
        manifest_hash = Bosh::Spec::NetworkingManifest.legacy_deployment_manifest(
          name: 'my-deploy',
          static_ips: ['192.168.1.10','192.168.1.11'],
          available_ips: 20
        )

        manifest_hash['jobs'] = [
          Bosh::Spec::Deployments.simple_job(name: 'first-job', static_ips: ['192.168.1.10'], instances: 1),
          Bosh::Spec::Deployments.simple_job(name: 'second-job', static_ips: ['192.168.1.11'], instances: 1)
        ]
        deploy_simple_manifest(manifest_hash: manifest_hash)

        manifest_hash['jobs'] = [
          Bosh::Spec::Deployments.simple_job(name: 'first-job', static_ips: ['192.168.1.11'], instances: 1),
          Bosh::Spec::Deployments.simple_job(name: 'second-job', static_ips: ['192.168.1.10'], instances: 1)
        ]
        output, exit_code = deploy_simple_manifest(manifest_hash: manifest_hash, failure_expected: true, return_exit_code: true)
        expect(exit_code).to_not eq(0)
        expect(output).to include("Failed to reserve IP '192.168.1.11' for 'a': already reserved")
      end
    end

    it 'keeps IP when reservation is changed to dynamic' do
      upload_cloud_config(cloud_config_hash: cloud_config_hash)

      deploy_with_ip(simple_manifest, '192.168.1.10')
      first_deploy_vms = director.vms
      expect(first_deploy_vms.size).to eq(1)
      expect(first_deploy_vms.first.ips).to eq('192.168.1.10')

      cloud_config_hash['networks'].first['subnets'].first.delete('static')
      upload_cloud_config(cloud_config_hash: cloud_config_hash)

      simple_manifest['jobs'].first['networks'].first.delete('static_ips')
      deploy_simple_manifest(manifest_hash: simple_manifest)
      second_deploy_vms = director.vms
      expect(second_deploy_vms.size).to eq(1)
      expect(second_deploy_vms.first.ips).to eq('192.168.1.10')

      expect(second_deploy_vms.first.cid).to eq(first_deploy_vms.first.cid)
    end

    it 'releases IP if reservation is changed to dynamic, but IP still belongs to static range' do
      upload_cloud_config(cloud_config_hash: cloud_config_hash)

      deploy_with_ip(simple_manifest, '192.168.1.10')
      first_deploy_vms = director.vms
      expect(first_deploy_vms.size).to eq(1)
      expect(first_deploy_vms.first.ips).to eq('192.168.1.10')

      simple_manifest['jobs'].first['networks'].first.delete('static_ips')
      deploy_simple_manifest(manifest_hash: simple_manifest)
      second_deploy_vms = director.vms
      expect(second_deploy_vms.size).to eq(1)
      expect(second_deploy_vms.first.ips).to eq('192.168.1.2')
    end
  end

  context 'when allocating dynamic IPs' do
    before do
      target_and_login
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
      expect(output).to include('Started updating instance foobar') # actually re-deployed
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

    it 'gives the correct error message when there are not enough IPs for instances' do
      new_cloud_config_hash = Bosh::Spec::NetworkingManifest.cloud_config(available_ips: 1)
      manifest_hash = Bosh::Spec::NetworkingManifest.deployment_manifest(name: 'my-deploy', instances: 2, template: 'foobar_without_packages')

      upload_cloud_config(cloud_config_hash: new_cloud_config_hash)
      output, exit_code = deploy_simple_manifest(manifest_hash: manifest_hash, failure_expected: true, return_exit_code: true)

      expect(exit_code).not_to eq(0)
      expect(output).to match(/Failed to reserve IP for 'foobar\/[a-z0-9\-]+ \(1\)' for manual network 'a': no more available/)
    end

    it 'does not reuse IP if one job is deleted and another created within a single deployment' do
      # Until https://www.pivotaltracker.com/story/show/98057020 we cannot reuse the same IP
      # within single deployment

      cloud_config_hash = Bosh::Spec::NetworkingManifest.cloud_config(available_ips: 1)
      manifest_hash = Bosh::Spec::NetworkingManifest.deployment_manifest(name: 'my-deploy')
      manifest_hash['jobs'] = [Bosh::Spec::Deployments.simple_job(
        name: 'first-job',
        instances: 1,
        templates: [{'name' => 'foobar_without_packages'}]
      )]

      upload_cloud_config(cloud_config_hash: cloud_config_hash)

      deploy_simple_manifest(manifest_hash: manifest_hash)
      expect_running_vms_with_names_and_count('first-job' => 1)

      manifest_hash['jobs'] = [Bosh::Spec::Deployments.simple_job(name: 'second-job', instances: 1)]
      output = deploy_simple_manifest(manifest_hash: manifest_hash, failure_expected: true)
      expect(output).to include('no more available')
    end

    it 'keeps IPs of a job when that job fails to deploy its VMs' do
      cloud_config_hash = Bosh::Spec::NetworkingManifest.cloud_config(available_ips: 2)
      failing_deployment_manifest_hash = Bosh::Spec::NetworkingManifest.deployment_manifest(name: 'my-deploy', instances: 2)
      other_deployment_manifest_hash = Bosh::Spec::NetworkingManifest.deployment_manifest(name: 'my-other-deploy', instances: 1)
      upload_cloud_config(cloud_config_hash: cloud_config_hash)

      current_sandbox.cpi.commands.make_create_vm_always_fail
      _, exit_code = deploy_simple_manifest(manifest_hash: failing_deployment_manifest_hash, failure_expected: true, return_exit_code: true)
      expect(exit_code).not_to eq(0)

      current_sandbox.cpi.commands.allow_create_vm_to_succeed
      output, exit_code = deploy_simple_manifest(manifest_hash: other_deployment_manifest_hash, failure_expected: true, return_exit_code: true)

      # all IPs still reserved
      expect(exit_code).not_to eq(0)
      expect(output).to match(/Failed to reserve IP for 'foobar\/[a-z0-9\-]+ \(0\)' for manual network 'a': no more available/)
    end

    it 'redeploys VM on new IP address when reserved list includes current IP address of VM' do
      cloud_config_hash = Bosh::Spec::NetworkingManifest.cloud_config(available_ips: 2)
      manifest_hash = Bosh::Spec::NetworkingManifest.deployment_manifest(name: 'my-deploy', instances: 1)
      upload_cloud_config(cloud_config_hash: cloud_config_hash)

      deploy_simple_manifest(manifest_hash: manifest_hash)
      original_ips = director.vms('my-deploy').map(&:ips).flatten
      expect(original_ips).to eq(['192.168.1.2'])

      new_cloud_config_hash = Bosh::Spec::NetworkingManifest.cloud_config(available_ips: 2, shift_ip_range_by: 1)
      upload_cloud_config(cloud_config_hash: new_cloud_config_hash)

      deploy_simple_manifest(manifest_hash: manifest_hash)
      new_ips = director.vms('my-deploy').map(&:ips).flatten
      expect(new_ips).to eq(['192.168.1.3'])
    end

    it 'can use IP that is no longer in reserved section' do
      cloud_config_hash = Bosh::Spec::NetworkingManifest.cloud_config(available_ips: 2, shift_ip_range_by: 1)
      upload_cloud_config(cloud_config_hash: cloud_config_hash)

      manifest_hash = Bosh::Spec::NetworkingManifest.deployment_manifest(name: 'my-deploy', instances: 1)
      deploy_simple_manifest(manifest_hash: manifest_hash)
      new_ips = director.vms('my-deploy').map(&:ips).flatten
      expect(new_ips).to eq(['192.168.1.3'])

      new_cloud_config_hash = Bosh::Spec::NetworkingManifest.cloud_config(available_ips: 2)
      upload_cloud_config(cloud_config_hash: new_cloud_config_hash)

      manifest_hash = Bosh::Spec::NetworkingManifest.deployment_manifest(name: 'my-deploy', instances: 2)
      deploy_simple_manifest(manifest_hash: manifest_hash)
      new_ips = director.vms('my-deploy').map(&:ips).flatten
      expect(new_ips).to match_array(['192.168.1.2', '192.168.1.3'])
    end

    def deploy_with_range(deployment_name, range)
      cloud_config_hash = Bosh::Spec::NetworkingManifest.cloud_config(available_ips: 2, range: range) # 1 for compilation
      upload_cloud_config(cloud_config_hash: cloud_config_hash)

      first_manifest_hash = Bosh::Spec::NetworkingManifest.deployment_manifest(name: deployment_name, instances: 1)
      deploy_simple_manifest(manifest_hash: first_manifest_hash)
    end

    it 'releases IP when subnet range is changed to no longer include it' do
      deploy_with_range('my-deploy', '192.168.1.0/24')
      expect(director.vms('my-deploy').map(&:ips).flatten).to eq(['192.168.1.2'])

      deploy_with_range('my-deploy', '192.168.2.0/24')
      expect(director.vms('my-deploy').map(&:ips).flatten).to eq(['192.168.2.2'])

      deploy_with_range('other-deploy', '192.168.1.0/24')
      expect(director.vms('other-deploy').map(&:ips).flatten).to eq(['192.168.1.2'])
    end

    context 'when using two networks' do
      context 'when range does not include one of IPs' do
        def make_network_spec(first_subnet, second_subnet)
          [
            {
              'name' => 'first',
              'subnets' => [first_subnet]
            },
            {
              'name' => 'second',
              'subnets' => [second_subnet]
            }
          ]
        end

        let(:job_with_two_networks) do
          job_spec = Bosh::Spec::Deployments.simple_job(instances: 1)
          job_spec['networks'] = [
            { 'name' => 'first', 'default' => ['dns', 'gateway'] },
            { 'name' => 'second' }
          ]
          job_spec
        end

        it 'redeploys VM updating IP that does not belong to range and keeping another IP' do
          first_subnet = Bosh::Spec::NetworkingManifest.make_subnet(available_ips: 2, range: '192.168.1.0/24') # 1 for compilation
          second_subnet = Bosh::Spec::NetworkingManifest.make_subnet(available_ips: 1, range: '10.10.0.0/24')

          cloud_config_hash = Bosh::Spec::Deployments.simple_cloud_config
          cloud_config_hash['networks'] = make_network_spec(first_subnet, second_subnet)
          cloud_config_hash['compilation']['network'] = 'first'
          upload_cloud_config(cloud_config_hash: cloud_config_hash)

          manifest_hash = Bosh::Spec::Deployments.simple_manifest
          manifest_hash['jobs'] = [job_with_two_networks]
          deploy_simple_manifest(manifest_hash: manifest_hash)

          vms = director.vms
          expect(vms.size).to eq(1)
          expect(vms.map(&:ips).flatten).to match_array(['192.168.1.2', '10.10.0.2'])

          new_second_subnet = Bosh::Spec::NetworkingManifest.make_subnet(available_ips: 1, range: '10.10.0.0/24', shift_ip_range_by: 1)
          cloud_config_hash['networks'] = make_network_spec(first_subnet, new_second_subnet)
          upload_cloud_config(cloud_config_hash: cloud_config_hash)

          deploy_simple_manifest(manifest_hash: manifest_hash)

          vms = director.vms
          expect(vms.size).to eq(1)
          expect(vms.map(&:ips).flatten).to match_array(['192.168.1.2', '10.10.0.3'])
        end
      end
    end

    context 'using legacy network configuration (no cloud config)' do
      it 'gives the correct error message when there are not enough IPs for compilation' do
        manifest_hash = Bosh::Spec::NetworkingManifest.legacy_deployment_manifest(name: 'my-deploy', instances: 1, available_ips: 1)
        output = deploy_simple_manifest(manifest_hash: manifest_hash, failure_expected: true)
        expect(output).to match(/Failed to reserve IP for 'compilation-.*' for manual network 'a': no more available/)
      end

      it 'gives the correct error message when there are not enough IPs for instances' do
        # needs 1 extra IP for compilation
        new_manifest_hash = Bosh::Spec::NetworkingManifest.legacy_deployment_manifest(name: 'my-deploy', instances: 2, available_ips: 2)

        output, exit_code = deploy_simple_manifest(manifest_hash: new_manifest_hash, failure_expected: true, return_exit_code: true)

        expect(exit_code).not_to eq(0)
        expect(output).to match(/Failed to reserve IP for 'compilation-.*' for manual network 'a': no more available/)
      end

      it 'gives VMs the same IP on redeploy' do
        manifest_hash = Bosh::Spec::NetworkingManifest.legacy_deployment_manifest(name: 'my-deploy', instances: 2, available_ips: 5)

        deploy_simple_manifest(manifest_hash: manifest_hash)
        original_ips = director.vms('my-deploy').map(&:ips).flatten

        manifest_hash['jobs'].first['properties'].merge!('test_property' => 'new value') # force re-deploy
        output = deploy_simple_manifest(manifest_hash: manifest_hash)
        expect(output).to include('Started updating instance foobar') # actually re-deployed
        new_ips = director.vms('my-deploy').map(&:ips).flatten

        expect(new_ips).to eq(original_ips)
      end

      it 'gives VMs the same IP on `deploy --recreate`' do
        manifest_hash = Bosh::Spec::NetworkingManifest.legacy_deployment_manifest(name: 'my-deploy', instances: 2, available_ips: 5)

        deploy_simple_manifest(manifest_hash: manifest_hash)
        vms = director.vms('my-deploy')
        original_ips = vms.map(&:ips).flatten
        original_cids = vms.map(&:cid)

        deploy_simple_manifest(manifest_hash: manifest_hash, recreate: true)
        vms = director.vms('my-deploy')
        new_ips = vms.map(&:ips).flatten
        new_cids = vms.map(&:cid)

        expect(new_cids).to_not match_array(original_cids)
        expect(new_ips).to match_array(original_ips)
      end

      it 'redeploys VM on new IP address when reserved list includes current IP address of VM' do
        manifest_hash = Bosh::Spec::NetworkingManifest.legacy_deployment_manifest(name: 'my-deploy', instances: 1, available_ips: 2)

        deploy_simple_manifest(manifest_hash: manifest_hash)
        original_ips = director.vms('my-deploy').map(&:ips).flatten
        expect(original_ips).to eq(['192.168.1.2'])

        manifest_hash = Bosh::Spec::NetworkingManifest.legacy_deployment_manifest(
          name: 'my-deploy',
          instances: 1,
          available_ips: 2,
          shift_ip_range_by: 1
        )

        deploy_simple_manifest(manifest_hash: manifest_hash)
        new_ips = director.vms('my-deploy').map(&:ips).flatten
        expect(new_ips).to eq(['192.168.1.3'])
      end
    end

    it 'keeps IP when reservation is changed to static' do
      cloud_config_hash = Bosh::Spec::NetworkingManifest.cloud_config(available_ips: 2)
      upload_cloud_config(cloud_config_hash: cloud_config_hash)

      simple_manifest = Bosh::Spec::NetworkingManifest.deployment_manifest(instances: 1)
      deploy_simple_manifest(manifest_hash: simple_manifest)
      first_deploy_vms = director.vms
      expect(first_deploy_vms.size).to eq(1)
      expect(first_deploy_vms.first.ips).to eq('192.168.1.2')

      cloud_config_hash['networks'].first['subnets'].first['static'] = ['192.168.1.2']
      upload_cloud_config(cloud_config_hash: cloud_config_hash)

      deploy_with_ip(simple_manifest, '192.168.1.2')
      second_deploy_vms = director.vms
      expect(second_deploy_vms.size).to eq(1)

      expect(second_deploy_vms.first.ips).to eq(first_deploy_vms.first.ips)
      expect(second_deploy_vms.first.cid).to eq(first_deploy_vms.first.cid)
    end
  end
end
