require_relative '../../spec_helper'

describe 'resurrector', type: :integration, hm: true do
  with_reset_sandbox_before_each
  with_reset_hm_before_each

  before do
    create_and_upload_test_release
    upload_stemcell
  end

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
      director.kill_vm_and_wait_for_resurrection(original_instance)

      resurrected_instance = director.instance('foobar', '0', deployment_name: 'simple')
      expect(resurrected_instance.vm_cid).to_not eq(original_instance.vm_cid)
      instances = director.instances(deployment_name: 'simple')
      expect(instances.size).to eq(1)
      expect(instances.first.ips).to eq(['192.168.1.2'])

      output = bosh_runner.run('events', json: true)
      data = scrub_event_time(scrub_random_cids(scrub_random_ids(table(output))))
      expect(data).to include(
        {'id' => /[0-9]{1,3}/, 'time' => /xxx xxx xx xx:xx:xx UTC xxxx/, 'user' => 'hm', 'action' => 'create', 'object_type' => 'alert', 'object_id' => 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'task_id' => '', 'deployment' => 'simple', 'instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'context' => /message: 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx has timed out.(.*)\n  UTC, severity 2: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx has timed out'/, 'error' => ''},
        {'id' => /[0-9]{1,3}/, 'time' => /xxx xxx xx xx:xx:xx UTC xxxx/, 'user' => 'hm', 'action' => 'create', 'object_type' => 'alert', 'object_id' => 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'task_id' => '', 'deployment' => 'simple', 'instance' => '', 'context' => /message: 'director - finish update deployment.(.*)UTC, severity\n  4: Finish update deployment for ''simple'' against Director ''deadbeef'''/, 'error' => ''}
      )
    end
  end
end
