require_relative '../spec_helper'

describe 'director upgrade from 265 with unresponsive agents', type: :upgrade do
  with_reset_sandbox_before_each(test_initial_state: 'bosh-v265.x-915942cf3b0d11ec93933f0e8e139442d8c6a270_with_unresponsive_agents', drop_database: true)

  describe 'bosh cck' do
    it 'recreates unresponsive VMs with waiting for processes to start' do
      output = bosh_runner.run('-d simple cck --auto --resolution=3')
      expect(output).to include('Succeeded')
      output = bosh_runner.run('vms', json: true, deployment_name: 'simple')
      expect(scrub_random_ids(table(output))).to contain_exactly(
        {
          'instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
          'process_state' => 'running',
          'active' => 'true',
          'az' => 'zone-1',
          'ips' => '192.168.1.2',
          'vm_cid' => String,
          'vm_type' => 'a',
        },
        {
          'instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
          'process_state' => 'running',
          'active' => 'true',
          'az' => 'zone-2',
          'ips' => '192.168.2.2',
          'vm_cid' => String,
          'vm_type' => 'a',
        },
        {
          'instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
          'process_state' => 'running',
          'active' => 'true',
          'az' => 'zone-3',
          'ips' => '192.168.3.2',
          'vm_cid' => String,
          'vm_type' => 'a',
        },
      )
    end
  end
end
