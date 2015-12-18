require 'spec_helper'

describe Bosh::Cli::Command::Vms do
  subject(:command) { described_class.new }

  before do
    allow(command).to receive_messages(director: director, logged_in?: true, nl: nil, say: nil)
    allow(command).to receive(:show_current_state)
  end
  let(:director) { double(Bosh::Cli::Client::Director) }

  describe 'list' do
    before { command.options[:target] = target }
    let(:target) { 'http://example.org' }

    context 'with no arguments' do
      def perform; command.list; end

      context 'when there are multiple deployments' do
        before { allow(director).to receive(:list_deployments) { [{ 'name' => 'dep1' }, { 'name' => 'dep2' }] } }

        it 'lists vms in all deployments' do
          expect(command).to receive(:show_deployment).with('dep1', target: target)
          expect(command).to receive(:show_deployment).with('dep2', target: target)
          perform
        end
      end

      context 'when there no deployments' do
        before { allow(director).to receive(:list_deployments) { [] } }

        it 'raises an error' do
          expect { perform }.to raise_error(Bosh::Cli::CliError, 'No deployments')
        end
      end
    end

    context 'with a deployment argument' do
      def perform
        command.list('dep1')
      end

      context 'when deployment with given name can be found' do
        it 'lists vms in the deployment' do
          expect(command).to receive(:show_deployment).with('dep1', target: target)
          command.list('dep1')
        end
      end
    end
  end

  describe 'show_deployment' do
    def perform
      command.show_deployment(deployment, options)
    end

    let(:deployment) { 'dep1' }
    let(:options)    { {details: false, dns: false, vitals: false} }

    let(:vm_state) {
      {
        'job_name' => 'job1',
        'index' => 0,
        'ips' => %w{192.168.0.1 192.168.0.2},
        'dns' => %w{index.job.network.deployment.microbosh index.job.network2.deployment.microbosh},
        'vitals' => 'vitals',
        'job_state' => 'awesome',
        'resource_pool' => 'rp1',
        'vm_cid' => 'cid1',
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
        'resurrection_paused' => true,
      }
    }

    context 'sorting multiple instances' do
      it 'sort by job name first' do
        vm_state.delete('az')

        vm_state2 = vm_state.clone
        vm_state2['job_name'] = 'job0'
        vm_state2['az'] = 'az2'

        allow(director).to receive(:fetch_vm_state).with(deployment) { [vm_state2, vm_state] }

        expect(command).to receive(:say) do |display_output|
          expect(display_output.to_s).to match_output '
              +--------+---------+-----+---------+-------------+
              | VM     | State   | AZ  | VM Type | IPs         |
              +--------+---------+-----+---------+-------------+
              | job0/0 | awesome | az2 | rp1     | 192.168.0.1 |
              |        |         |     |         | 192.168.0.2 |
              | job1/0 | awesome | n/a | rp1     | 192.168.0.1 |
              |        |         |     |         | 192.168.0.2 |
              +--------+---------+-----+---------+-------------+
              '
        end
        perform
      end

      it 'if name is the same, sort by AZ' do
        vm_state.delete('az')

        vm_state2 = vm_state.clone
        vm_state2['az'] = 'az1'

        vm_state3 = vm_state.clone
        vm_state3['az'] = 'az2'

        vm_state4 = vm_state.clone
        vm_state4['az'] = 'zone1'

        allow(director).to receive(:fetch_vm_state).with(deployment) { [vm_state3, vm_state4, vm_state2, vm_state] }

        expect(command).to receive(:say) do |display_output|
          expect(display_output.to_s).to match_output '
              +--------+---------+-------+---------+-------------+
              | VM     | State   | AZ    | VM Type | IPs         |
              +--------+---------+-------+---------+-------------+
              | job1/0 | awesome | n/a   | rp1     | 192.168.0.1 |
              |        |         |       |         | 192.168.0.2 |
              | job1/0 | awesome | az1   | rp1     | 192.168.0.1 |
              |        |         |       |         | 192.168.0.2 |
              | job1/0 | awesome | az2   | rp1     | 192.168.0.1 |
              |        |         |       |         | 192.168.0.2 |
              | job1/0 | awesome | zone1 | rp1     | 192.168.0.1 |
              |        |         |       |         | 192.168.0.2 |
              +--------+---------+-------+---------+-------------+
              '
        end
        perform
      end

      it 'if name and AZ are the same, sort by index' do
        vm_state['az'] = 'az1'

        vm_state2 = vm_state.clone
        vm_state2['index'] = 1

        vm_state3 = vm_state.clone
        vm_state3['index'] = 2

        vm_state4 = vm_state.clone
        vm_state4['index'] = 3

        allow(director).to receive(:fetch_vm_state).with(deployment) { [vm_state3, vm_state4, vm_state2, vm_state] }

        expect(command).to receive(:say) do |display_output|
          expect(display_output.to_s).to match_output '
              +--------+---------+-----+---------+-------------+
              | VM     | State   | AZ  | VM Type | IPs         |
              +--------+---------+-----+---------+-------------+
              | job1/0 | awesome | az1 | rp1     | 192.168.0.1 |
              |        |         |     |         | 192.168.0.2 |
              | job1/1 | awesome | az1 | rp1     | 192.168.0.1 |
              |        |         |     |         | 192.168.0.2 |
              | job1/2 | awesome | az1 | rp1     | 192.168.0.1 |
              |        |         |     |         | 192.168.0.2 |
              | job1/3 | awesome | az1 | rp1     | 192.168.0.1 |
              |        |         |     |         | 192.168.0.2 |
              +--------+---------+-----+---------+-------------+
              '
        end
        perform
      end
    end

    context 'when id is present' do
      before do
        vm_state['id'] = 'my_instance_id'
        allow(director).to receive(:fetch_vm_state).with(deployment) { [vm_state] }
      end

      it 'shows instance id' do
        expect(command).to receive(:say) do |output_display|
          expect(output_display.to_s).to include 'job1/0 (my_instance_id)'
        end
        perform
      end
    end

    context 'when deployment has vms' do
      before { allow(director).to receive(:fetch_vm_state).with(deployment) { [vm_state] } }

      context 'default' do
        it 'show basic vms information' do
          expect(command).to receive(:say) do |table|
            expect(table.to_s).to match_output '
              +--------+---------+---------+-------------+
              | VM     | State   | VM Type | IPs         |
              +--------+---------+---------+-------------+
              | job1/0 | awesome | rp1     | 192.168.0.1 |
              |        |         |         | 192.168.0.2 |
              +--------+---------+---------+-------------+
            '
          end
          expect(command).to receive(:say).with('VMs total: 1')
          perform
        end

        it 'show AZ information' do
          vm_state['az'] = 'az1'
          expect(command).to receive(:say) do |output_display|
            expect(output_display.to_s).to include 'AZ'
            expect(output_display.to_s).to include 'az1'
          end
          perform
        end

        it 'do not show AZ column when AZ is not defined' do
          expect(command).to receive(:say) do |output_display|
            expect(output_display.to_s).to_not include 'AZ'
          end
          perform
        end
      end

      context 'with details' do
        before { options[:details] = true }

        it 'shows vm details' do
          expect(command).to receive(:say) do |table|
            expect(table.to_s).to match_output '
              +--------+---------+---------+-------------+------+----------+--------------+
              | VM     | State   | VM Type | IPs         | CID  | Agent ID | Resurrection |
              +--------+---------+---------+-------------+------+----------+--------------+
              | job1/0 | awesome | rp1     | 192.168.0.1 | cid1 | agent1   | paused       |
              |        |         |         | 192.168.0.2 |      |          |              |
              +--------+---------+---------+-------------+------+----------+--------------+
            '
          end
          expect(command).to receive(:say).with('VMs total: 1')
          perform
        end
      end

      context 'with DNS A records' do
        before { options[:dns] = true }

        it 'shows DNS A records' do
          expect(command).to receive(:say) do |table|
            expect(table.to_s).to match_output '
              +--------+---------+---------+-------------+-----------------------------------------+
              | VM     | State   | VM Type | IPs         | DNS A records                           |
              +--------+---------+---------+-------------+-----------------------------------------+
              | job1/0 | awesome | rp1     | 192.168.0.1 | index.job.network.deployment.microbosh  |
              |        |         |         | 192.168.0.2 | index.job.network2.deployment.microbosh |
              +--------+---------+---------+-------------+-----------------------------------------+
            '
          end
          expect(command).to receive(:say).with('VMs total: 1')
          perform
        end
      end

      context 'with vitals' do
        before { options[:vitals] = true }

        it 'shows the vm vitals' do
          expect(command).to receive(:say) do |table|
            expect(table.to_s).to match_output '
              +--------+---------+---------+-------------+-----------------------+------+-----+------+--------------+------------+------------+------------+------------+
              | VM     | State   | VM Type | IPs         |         Load          | CPU  | CPU | CPU  | Memory Usage | Swap Usage | System     | Ephemeral  | Persistent |
              |        |         |         |             | (avg01, avg05, avg15) | User | Sys | Wait |              |            | Disk Usage | Disk Usage | Disk Usage |
              +--------+---------+---------+-------------+-----------------------+------+-----+------+--------------+------------+------------+------------+------------+
              | job1/0 | awesome | rp1     | 192.168.0.1 | 1, 2, 3               | 4%   | 5%  | 6%   | 7% (8.0K)    | 9% (10.0K) | 11%        | 12%        | 13%        |
              |        |         |         | 192.168.0.2 |                       |      |     |      |              |            |            |            |            |
              +--------+---------+---------+-------------+-----------------------+------+-----+------+--------------+------------+------------+------------+------------+
            '
          end
          expect(command).to receive(:say).with('VMs total: 1')
          perform
        end

        it 'shows the vm vitals with unavailable ephemeral and persistent disks' do
          new_vm_state = vm_state
          new_vm_state['vitals']['disk'].delete('ephemeral')
          new_vm_state['vitals']['disk'].delete('persistent')
          allow(director).to receive(:fetch_vm_state).with(deployment) { [new_vm_state] }

          expect(command).to receive(:say) do |table|
            expect(table.to_s).to match_output '
              +--------+---------+---------+-------------+-----------------------+------+-----+------+--------------+------------+------------+------------+------------+
              | VM     | State   | VM Type | IPs         |         Load          | CPU  | CPU | CPU  | Memory Usage | Swap Usage | System     | Ephemeral  | Persistent |
              |        |         |         |             | (avg01, avg05, avg15) | User | Sys | Wait |              |            | Disk Usage | Disk Usage | Disk Usage |
              +--------+---------+---------+-------------+-----------------------+------+-----+------+--------------+------------+------------+------------+------------+
              | job1/0 | awesome | rp1     | 192.168.0.1 | 1, 2, 3               | 4%   | 5%  | 6%   | 7% (8.0K)    | 9% (10.0K) | 11%        | n/a        | n/a        |
              |        |         |         | 192.168.0.2 |                       |      |     |      |              |            |            |            |            |
              +--------+---------+---------+-------------+-----------------------+------+-----+------+--------------+------------+------------+------------+------------+
            '
          end
          expect(command).to receive(:say).with('VMs total: 1')
          perform
        end
      end
    end

    context 'when deployment has no vms' do
      before { allow(director).to receive(:fetch_vm_state).with(deployment) { [] } }

      it 'does not raise an error and says "No VMs"' do
        expect(command).to receive(:say).with('No VMs')
        expect { perform }.to_not raise_error
      end
    end
  end
end
