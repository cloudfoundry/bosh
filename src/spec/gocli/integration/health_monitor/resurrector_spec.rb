require_relative '../../spec_helper'

describe 'resurrector', type: :integration, hm: true do
  with_reset_sandbox_before_each

  before do
    current_sandbox.health_monitor_process.start

    create_and_upload_test_release
    upload_stemcell
  end

  after { current_sandbox.health_monitor_process.stop }

  let(:cloud_config_hash) do
    cloud_config_hash = Bosh::Spec::Deployments.simple_cloud_config

    cloud_config_hash['networks'].first['subnets'].first['static'] =  ['192.168.1.10', '192.168.1.11']
    cloud_config_hash
  end

  let(:simple_manifest) do
    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    manifest_hash['jobs'].first['instances'] = 1
    manifest_hash
  end

  context 'when we have legacy deployments deployed' do
    let(:legacy_manifest) do
      legacy_manifest = Bosh::Spec::Deployments.legacy_manifest
      legacy_manifest['jobs'].first['instances'] = 1
      legacy_manifest
    end

    it 'resurrects vms with old deployment ignoring cloud config' do
      deploy_simple_manifest(manifest_hash: legacy_manifest)
      instances = director.instances(deployment_name: 'simple')
      expect(instances.size).to eq(1)
      expect(instances.first.ips).to eq(['192.168.1.2'])

      cloud_config_hash['networks'].first['subnets'].first['reserved'] = ['192.168.1.2']
      upload_cloud_config(cloud_config_hash: cloud_config_hash)

      original_instance = director.instance('foobar', '0', deployment_name: 'simple')
      original_instance.kill_agent
      resurrected_instance = director.wait_for_vm('foobar', '0', 300, deployment_name: 'simple')
      expect(resurrected_instance.vm_cid).to_not eq(original_instance.vm_cid)
      instances = director.instances(deployment_name: 'simple')
      expect(instances.size).to eq(1)
      expect(instances.first.ips).to eq(['192.168.1.2'])

      output = bosh_runner.run('events', json: true)
      data = scrub_event_time(scrub_random_cids(scrub_random_ids(table(output))))

      expect(data).to include(
        {'ID' => /[0-9]{1,3}/, 'Time' => /xxx xxx xx xx:xx:xx UTC xxxx/, 'User' => 'hm', 'Action' => 'create', 'Object Type' => 'alert', 'Object ID' => 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'Task ID' => '', 'Deployment' => 'simple', 'Instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'Context' => /message: 'Alert @ .* severity 2: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx\n  has timed out'/, 'Error' => ''},
        {'ID' => /[0-9]{1,3}/, 'Time' => /xxx xxx xx xx:xx:xx UTC xxxx/, 'User' => 'hm', 'Action' => 'create', 'Object Type' => 'alert', 'Object ID' => 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'Task ID' => '', 'Deployment' => '', 'Instance' => '', 'Context' => /message: 'Alert @ .* severity 4: Finish update deployment for\n  ''simple'' against Director ''deadbeef'''/, 'Error' => ''}
      )
    end
  end
end
