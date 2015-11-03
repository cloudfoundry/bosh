require 'spec_helper'

describe Bosh::Cli::Command::Instances do
  subject(:command) { described_class.new }

  before do
    allow(command).to receive_messages(director: director, logged_in?: true, nl: nil, say: nil)
    allow(command).to receive(:show_current_state)
    command.options[:config] = Tempfile.new('bosh-cli-instances-spec').path
  end
  let(:director) { double(Bosh::Cli::Client::Director) }

  after do
    FileUtils.rm_rf(command.options[:config])
  end

  describe 'list' do
    before { command.options[:target] = target }
    let(:target) { 'http://example.org' }

    context 'with no arguments' do
      def perform
        command.list
      end

      let(:manifest_file) do
        manifest = {
          'name' => 'dep2'
        }

        manifest_file = Tempfile.new('manifest')
        Psych.dump(manifest, manifest_file)
        manifest_file.close
        manifest_file
      end

      context 'when there is no deployment set' do

        it 'raises an error' do
          expect { perform }.to raise_error(Bosh::Cli::CliError, 'Please choose deployment first')
        end
      end
      context 'when deployment is set to dep2' do
        before { allow(command).to receive(:deployment) { manifest_file.path } }

        context 'when the deployment exists on the director' do
          before { allow(director).to receive(:list_deployments) { [{'name' => 'dep1'}, {'name' => 'dep2'}] } }

          it 'lists instances in deployment dep2 only' do
            expect(command).to receive(:show_deployment).with('dep2', kind_of(Hash))
            expect(command).to_not receive(:show_deployment).with('dep1', kind_of(Hash))
            perform
          end
        end

        context "when the deployment doesn't exist on the director" do
          before { allow(director).to receive(:list_deployments) { [] } }

          it 'raises an error' do
            expect { perform }.to raise_error(Bosh::Cli::CliError, "The deployment 'dep2' doesn't exist")
          end
        end

        context 'when there are no deployments on the director' do
          before { allow(director).to receive(:list_deployments) { [] } }

          it 'raises an error' do
            expect { perform }.to raise_error(Bosh::Cli::CliError, "The deployment 'dep2' doesn't exist")
          end
        end
      end
    end
  end

  describe 'show_deployment' do
    def perform
      command.show_deployment(deployment, options)
    end

    let(:deployment) { 'dep1' }
    let(:options) { {details: false, dns: false, vitals: false, failing: false} }

    context 'when the deployment has instances' do
      before { allow(director).to receive(:fetch_vm_state).with(deployment) { [vm1_state, vm2_state] } }

      let(:vm1_state) {
        {
          'job_name' => 'job1',
          'index' => 0,
          'ips' => %w{192.168.0.1 192.168.0.2},
          'dns' => %w{index.job1.network1.deployment.microbosh index.job1.network2.deployment.microbosh},
          'vitals' => 'vitals',
          'job_state' => 'running',
          'resource_pool' => 'rp1',
          'vm_cid' => 'vm-cid1',
          'disk_cid' => 'disk-cid1',
          'agent_id' => 'agent1',
          'vitals' => {
            'load' => [1, 2, 3],
            'cpu' => {
              'user' => 4,
              'sys' => 5,
              'wait' => 6,
            },
            'mem' => {
              'percent' => 7,
              'kb' => 8,
            },
            'swap' => {
              'percent' => 9,
              'kb' => 10,
            },
            'disk' => {
              'system' => {'percent' => 11},
              'ephemeral' => {'percent' => 12},
              'persistent' => {'percent' => 13},
            },
          },
          'processes' => [
            {
              'name' => 'process-1',
              'state' => 'running',
            },{
              'name' => 'process-2',
              'state' => 'running'
            },
          ],
          'resurrection_paused' => true,
        }
      }

      let(:vm2_state) {
        {
          'job_name' => 'job2',
          'index' => 0,
          'ips' => %w{192.168.0.3 192.168.0.4},
          'dns' => %w{index.job2.network1.deployment.microbosh index.job2.network2.deployment.microbosh},
          'vitals' => 'vitals',
          'job_state' => 'running',
          'resource_pool' => 'rp1',
          'vm_cid' => 'vm-cid2',
          'disk_cid' => 'disk-cid2',
          'agent_id' => 'agent2',
          'vitals' => {
            'load' => [1, 2, 3],
            'cpu' => {
              'user' => 4,
              'sys' => 5,
              'wait' => 6,
            },
            'mem' => {
              'percent' => 7,
              'kb' => 8,
            },
            'swap' => {
              'percent' => 9,
              'kb' => 10,
            },
            'disk' => {
              'system' => {'percent' => 11},
              'ephemeral' => {'percent' => 12},
              'persistent' => {'percent' => 13},
            },
          },
          'processes' => [
            {
              'name' => 'process-3',
              'state' => 'running',
            },{
              'name' => 'process-4',
              'state' => 'running'
            },
          ],
          'resurrection_paused' => true,
        }
      }

      context 'default' do
        it 'show basic vms information' do
          expect(command).to receive(:say) do |table|
            expect(table.to_s).to match_output %(
              +----------+---------+---------------+-------------+
              | Instance | State   | Resource Pool | IPs         |
              +----------+---------+---------------+-------------+
              | job1/0   | running | rp1           | 192.168.0.1 |
              |          |         |               | 192.168.0.2 |
              | job2/0   | running | rp1           | 192.168.0.3 |
              |          |         |               | 192.168.0.4 |
              +----------+---------+---------------+-------------+
            )
          end
          expect(command).to receive(:say).with('Instances total: 2')
          perform
        end

        it 'only show failing instances when --failing option is specified and some instance failing' do
          options[:failing] = true
          vm2_state['job_state'] = 'failing'

          expect(command).to receive(:say) do |table|
            expect(table.to_s).to match_output %(
              +----------+---------+---------------+-------------+
              | Instance | State   | Resource Pool | IPs         |
              +----------+---------+---------------+-------------+
              | job2/0   | failing | rp1           | 192.168.0.3 |
              |          |         |               | 192.168.0.4 |
              +----------+---------+---------------+-------------+
            )
          end
          expect(command).to receive(:say).with('Instances total: 1')
          perform
        end

        it 'show all instances when --failing option is specified and no instance failing' do
          options[:failing] = true
          vm2_state['processes'][0]['state'] = 'failing'

          expect(command).to receive(:say).with('No failing instances')
          perform
        end
      end

      context 'with details' do
        before { options[:details] = true }

        it 'shows vm details with active disk' do
          expect(command).to receive(:say) do |table|
            expect(table.to_s).to match_output %(
              +----------+---------+---------------+-------------+---------+-----------+----------+--------------+
              | Instance | State   | Resource Pool | IPs         | VM CID  | Disk CID  | Agent ID | Resurrection |
              +----------+---------+---------------+-------------+---------+-----------+----------+--------------+
              | job1/0   | running | rp1           | 192.168.0.1 | vm-cid1 | disk-cid1 | agent1   | paused       |
              |          |         |               | 192.168.0.2 |         |           |          |              |
              | job2/0   | running | rp1           | 192.168.0.3 | vm-cid2 | disk-cid2 | agent2   | paused       |
              |          |         |               | 192.168.0.4 |         |           |          |              |
              +----------+---------+---------------+-------------+---------+-----------+----------+--------------+
            )
          end
          expect(command).to receive(:say).with('Instances total: 2')
          perform
        end

        it 'shows vm details without active disk' do
          vm1_state['disk_cid'] = nil
          expect(command).to receive(:say) do |table|
            expect(table.to_s).to match_output %(
              +----------+---------+---------------+-------------+---------+-----------+----------+--------------+
              | Instance | State   | Resource Pool | IPs         | VM CID  | Disk CID  | Agent ID | Resurrection |
              +----------+---------+---------------+-------------+---------+-----------+----------+--------------+
              | job1/0   | running | rp1           | 192.168.0.1 | vm-cid1 | n/a       | agent1   | paused       |
              |          |         |               | 192.168.0.2 |         |           |          |              |
              | job2/0   | running | rp1           | 192.168.0.3 | vm-cid2 | disk-cid2 | agent2   | paused       |
              |          |         |               | 192.168.0.4 |         |           |          |              |
              +----------+---------+---------------+-------------+---------+-----------+----------+--------------+
            )
          end
          expect(command).to receive(:say).with('Instances total: 2')
          perform
        end

        it 'does not show disk cid when response does not contain disk cid info' do
          vm1_state.delete('disk_cid')
          expect(command).to receive(:say) do |table|
            expect(table.to_s).to match_output %(
              +----------+---------+---------------+-------------+---------+----------+--------------+
              | Instance | State   | Resource Pool | IPs         | VM CID  | Agent ID | Resurrection |
              +----------+---------+---------------+-------------+---------+----------+--------------+
              | job1/0   | running | rp1           | 192.168.0.1 | vm-cid1 | agent1   | paused       |
              |          |         |               | 192.168.0.2 |         |          |              |
              | job2/0   | running | rp1           | 192.168.0.3 | vm-cid2 | agent2   | paused       |
              |          |         |               | 192.168.0.4 |         |          |              |
              +----------+---------+---------------+-------------+---------+----------+--------------+
            )
          end
          expect(command).to receive(:say).with('Instances total: 2')
          perform
        end

        it 'only show failing instances detail when --failing option is specified' do
          options[:failing] = true
          vm2_state['job_state'] = 'failing'

          expect(command).to receive(:say) do |table|
            expect(table.to_s).to match_output %(
              +----------+---------+---------------+-------------+---------+-----------+----------+--------------+
              | Instance | State   | Resource Pool | IPs         | VM CID  | Disk CID  | Agent ID | Resurrection |
              +----------+---------+---------------+-------------+---------+-----------+----------+--------------+
              | job2/0   | failing | rp1           | 192.168.0.3 | vm-cid2 | disk-cid2 | agent2   | paused       |
              |          |         |               | 192.168.0.4 |         |           |          |              |
              +----------+---------+---------------+-------------+---------+-----------+----------+--------------+
            )
          end

          expect(command).to receive(:say).with('Instances total: 1')
          perform
        end
      end

      context 'with DNS A records' do
        before { options[:dns] = true }

        it 'shows DNS A records' do
          expect(command).to receive(:say) do |table|
            expect(table.to_s).to match_output %(
              +----------+---------+---------------+-------------+------------------------------------------+
              | Instance | State   | Resource Pool | IPs         | DNS A records                            |
              +----------+---------+---------------+-------------+------------------------------------------+
              | job1/0   | running | rp1           | 192.168.0.1 | index.job1.network1.deployment.microbosh |
              |          |         |               | 192.168.0.2 | index.job1.network2.deployment.microbosh |
              | job2/0   | running | rp1           | 192.168.0.3 | index.job2.network1.deployment.microbosh |
              |          |         |               | 192.168.0.4 | index.job2.network2.deployment.microbosh |
              +----------+---------+---------------+-------------+------------------------------------------+
            )
          end
          expect(command).to receive(:say).with('Instances total: 2')
          perform
        end
      end

      context 'with vitals' do
        before { options[:vitals] = true }

        it 'shows the instance vitals' do
          expect(command).to receive(:say) do |table|
            expect(table.to_s).to match_output %(
              +----------+---------+---------------+-------------+-----------------------+------+-----+------+--------------+------------+------------+------------+------------+
              | Instance | State   | Resource Pool | IPs         |         Load          | CPU  | CPU | CPU  | Memory Usage | Swap Usage | System     | Ephemeral  | Persistent |
              |          |         |               |             | (avg01, avg05, avg15) | User | Sys | Wait |              |            | Disk Usage | Disk Usage | Disk Usage |
              +----------+---------+---------------+-------------+-----------------------+------+-----+------+--------------+------------+------------+------------+------------+
              | job1/0   | running | rp1           | 192.168.0.1 | 1, 2, 3               | 4%   | 5%  | 6%   | 7% (8.0K)    | 9% (10.0K) | 11%        | 12%        | 13%        |
              |          |         |               | 192.168.0.2 |                       |      |     |      |              |            |            |            |            |
              | job2/0   | running | rp1           | 192.168.0.3 | 1, 2, 3               | 4%   | 5%  | 6%   | 7% (8.0K)    | 9% (10.0K) | 11%        | 12%        | 13%        |
              |          |         |               | 192.168.0.4 |                       |      |     |      |              |            |            |            |            |
              +----------+---------+---------------+-------------+-----------------------+------+-----+------+--------------+------------+------------+------------+------------+
            )
          end
          expect(command).to receive(:say).with('Instances total: 2')
          perform
        end

        it 'shows the instance vitals with unavailable ephemeral and persistent disks' do
          new_vm_state = vm1_state
          new_vm_state['vitals']['disk'].delete('ephemeral')
          new_vm_state['vitals']['disk'].delete('persistent')
          allow(director).to receive(:fetch_vm_state).with(deployment) { [new_vm_state] }

          expect(command).to receive(:say) do |table|
            expect(table.to_s).to match_output %(
              +----------+---------+---------------+-------------+-----------------------+------+-----+------+--------------+------------+------------+------------+------------+
              | Instance | State   | Resource Pool | IPs         |         Load          | CPU  | CPU | CPU  | Memory Usage | Swap Usage | System     | Ephemeral  | Persistent |
              |          |         |               |             | (avg01, avg05, avg15) | User | Sys | Wait |              |            | Disk Usage | Disk Usage | Disk Usage |
              +----------+---------+---------------+-------------+-----------------------+------+-----+------+--------------+------------+------------+------------+------------+
              | job1/0   | running | rp1           | 192.168.0.1 | 1, 2, 3               | 4%   | 5%  | 6%   | 7% (8.0K)    | 9% (10.0K) | 11%        | n/a        | n/a        |
              |          |         |               | 192.168.0.2 |                       |      |     |      |              |            |            |            |            |
              +----------+---------+---------------+-------------+-----------------------+------+-----+------+--------------+------------+------------+------------+------------+
            )
          end
          expect(command).to receive(:say).with('Instances total: 1')
          perform
        end
      end

      context 'with ps' do
        before { options[:ps] = true }

        it 'shows the details of each instance\'s processes' do
          expect(command).to receive(:say) do |table|
            expect(table.to_s).to match_output %(
              +-------------+---------+---------------+-------------+
              | Instance    | State   | Resource Pool | IPs         |
              +-------------+---------+---------------+-------------+
              | job1/0      | running | rp1           | 192.168.0.1 |
              |             |         |               | 192.168.0.2 |
              |   process-1 | running |               |             |
              |   process-2 | running |               |             |
              +-------------+---------+---------------+-------------+
              | job2/0      | running | rp1           | 192.168.0.3 |
              |             |         |               | 192.168.0.4 |
              |   process-3 | running |               |             |
              |   process-4 | running |               |             |
              +-------------+---------+---------------+-------------+
            )
          end
          expect(command).to receive(:say).with('Instances total: 2')
          perform
        end

        context 'with failing' do
          before { options[:failing] = true }

          it 'does not raise an error and says "No failing instances"' do
            expect(command).to receive(:say).with('No failing instances')
            expect { perform }.to_not raise_error
          end

          it 'only shows failing instances' do
            vm2_state['job_state'] = 'failing'

            expect(command).to receive(:say) do |table|
              expect(table.to_s).to match_output %(
                +----------+---------+---------------+-------------+
                | Instance | State   | Resource Pool | IPs         |
                +----------+---------+---------------+-------------+
                | job2/0   | failing | rp1           | 192.168.0.3 |
                |          |         |               | 192.168.0.4 |
                +----------+---------+---------------+-------------+
              )
            end
            expect(command).to receive(:say).with('Instances total: 1')
            perform
          end

          it 'considers any non-"running" job as failing' do
            vm2_state['job_state'] = 'vaporized'

            expect(command).to receive(:say) do |table|
              expect(table.to_s).to match_output %(
                +----------+-----------+---------------+-------------+
                | Instance | State     | Resource Pool | IPs         |
                +----------+-----------+---------------+-------------+
                | job2/0   | vaporized | rp1           | 192.168.0.3 |
                |          |           |               | 192.168.0.4 |
                +----------+-----------+---------------+-------------+
              )
            end
            expect(command).to receive(:say).with('Instances total: 1')
            perform
          end

          it 'shows instance and its processes when one of the processes is failing' do
            vm2_state['processes'][0]['state'] = 'failing'

            expect(command).to receive(:say) do |table|
              expect(table.to_s).to match_output %(
                +-------------+---------+---------------+-------------+
                | Instance    | State   | Resource Pool | IPs         |
                +-------------+---------+---------------+-------------+
                | job2/0      | running | rp1           | 192.168.0.3 |
                |             |         |               | 192.168.0.4 |
                |   process-3 | failing |               |             |
                +-------------+---------+---------------+-------------+
              )
            end
            expect(command).to receive(:say).with('Instances total: 1')
            perform
          end

          it 'shows instance and its processes when instance and one of the processes are failing' do
            vm2_state["job_state"] = 'failing'
            vm2_state['processes'][0]['state'] = 'failing'

            expect(command).to receive(:say) do |table|
              expect(table.to_s).to match_output %(
                +-------------+---------+---------------+-------------+
                | Instance    | State   | Resource Pool | IPs         |
                +-------------+---------+---------------+-------------+
                | job2/0      | failing | rp1           | 192.168.0.3 |
                |             |         |               | 192.168.0.4 |
                |   process-3 | failing |               |             |
                +-------------+---------+---------------+-------------+
              )
            end
            expect(command).to receive(:say).with('Instances total: 1')
            perform
          end

          it 'considers any non-"running" process as failing' do
            vm2_state['processes'][0]['state'] = 'exploded'

            expect(command).to receive(:say) do |table|
              expect(table.to_s).to match_output %(
                +-------------+----------+---------------+-------------+
                | Instance    | State    | Resource Pool | IPs         |
                +-------------+----------+---------------+-------------+
                | job2/0      | running  | rp1           | 192.168.0.3 |
                |             |          |               | 192.168.0.4 |
                |   process-3 | exploded |               |             |
                +-------------+----------+---------------+-------------+
              )
            end
            expect(command).to receive(:say).with('Instances total: 1')
            perform
          end
        end
      end
    end

    context 'when deployment has no instances' do
      before { allow(director).to receive(:fetch_vm_state).with(deployment) { [] } }

      it 'does not raise an error and says "No instances"' do
        expect(command).to receive(:say).with('No instances')
        expect { perform }.to_not raise_error
      end
    end
  end
end
