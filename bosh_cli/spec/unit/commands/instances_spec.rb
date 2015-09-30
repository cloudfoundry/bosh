require 'spec_helper'
require 'cli'

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
    let(:options) { {details: false, dns: false, vitals: false} }

    context 'when the deployment has instances' do
      before { allow(director).to receive(:fetch_vm_state).with(deployment) { [vm_state] } }

      let(:vm_state) {
        {
          'job_name' => 'job1',
          'index' => 0,
          'ips' => %w{192.168.0.1 192.168.0.2},
          'dns' => %w{index.job.network.deployment.microbosh index.job.network2.deployment.microbosh},
          'vitals' => 'vitals',
          'job_state' => 'awesome',
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

      context 'default' do
        it 'show basic vms information' do
          expect(command).to receive(:say) do |s|
            expect(s.to_s).to include 'Instance'
            expect(s.to_s).to include 'State'
            expect(s.to_s).to include 'Resource Pool'
            expect(s.to_s).to include 'IPs'
            expect(s.to_s).to include 'job1/0'
            expect(s.to_s).to include 'awesome'
            expect(s.to_s).to include 'rp1'
            expect(s.to_s).to include '| 192.168.0.1'
            expect(s.to_s).to include '| 192.168.0.2'
          end
          expect(command).to receive(:say).with('Instances total: 1')
          perform
        end
      end

      context 'with details' do
        before { options[:details] = true }

        it 'shows vm details with active disk' do
          expect(command).to receive(:say) do |s|
            expect(s.to_s).to include 'Instance'
            expect(s.to_s).to include 'State'
            expect(s.to_s).to include 'Resource Pool'
            expect(s.to_s).to include 'IPs'
            expect(s.to_s).to include 'VM CID'
            expect(s.to_s).to include 'Disk CID'
            expect(s.to_s).to include 'Agent ID'
            expect(s.to_s).to include 'Resurrection'
            expect(s.to_s).to include 'job1/0'
            expect(s.to_s).to include 'awesome'
            expect(s.to_s).to include 'rp1'
            expect(s.to_s).to include '| 192.168.0.1'
            expect(s.to_s).to include '| 192.168.0.2'
            expect(s.to_s).to include 'vm-cid1'
            expect(s.to_s).to include 'disk-cid1'
            expect(s.to_s).to include 'agent1'
            expect(s.to_s).to include 'paused'
          end
          expect(command).to receive(:say).with('Instances total: 1')
          perform
        end

        it 'shows vm details without active disk' do
          vm_state['disk_cid'] = nil
          expect(command).to receive(:say) do |s|
            expect(s.to_s).to include 'n/a'
          end
          expect(command).to receive(:say).with('Instances total: 1')
          perform
        end

        it 'does not show disk cid when response does not contain disk cid info' do
          vm_state.delete('disk_cid')
          expect(command).to receive(:say) do |s|
            expect(s.to_s).to_not include 'Disk CID'
          end
          expect(command).to receive(:say).with('Instances total: 1')
          perform
        end
      end

      context 'with DNS A records' do
        before { options[:dns] = true }

        it 'shows DNS A records' do
          expect(command).to receive(:say) do |s|
            expect(s.to_s).to include 'Instance'
            expect(s.to_s).to include 'State'
            expect(s.to_s).to include 'Resource Pool'
            expect(s.to_s).to include 'IPs'
            expect(s.to_s).to include 'DNS A records'
            expect(s.to_s).to include 'job1/0'
            expect(s.to_s).to include 'awesome'
            expect(s.to_s).to include 'rp1'
            expect(s.to_s).to include '| 192.168.0.1'
            expect(s.to_s).to include '| 192.168.0.2'
            expect(s.to_s).to include '| index.job.network.deployment.microbosh'
            expect(s.to_s).to include '| index.job.network2.deployment.microbosh'
          end
          expect(command).to receive(:say).with('Instances total: 1')
          perform
        end
      end

      context 'with vitals' do
        before { options[:vitals] = true }

        it 'shows the instance vitals' do
          expect(command).to receive(:say) do |s|
            expect(s.to_s).to include 'Instance'
            expect(s.to_s).to include 'State'
            expect(s.to_s).to include 'Resource Pool'
            expect(s.to_s).to include 'IPs'
            expect(s.to_s).to include 'Load'
            expect(s.to_s).to include '(avg01, avg05, avg15)'
            expect(s.to_s).to include 'CPU'
            expect(s.to_s).to include 'Memory Usage'
            expect(s.to_s).to include 'Swap Usage'
            expect(s.to_s).to include 'job1/0'
            expect(s.to_s).to include 'awesome'
            expect(s.to_s).to include 'rp1'
            expect(s.to_s).to include '| 192.168.0.1'
            expect(s.to_s).to include '| 192.168.0.2'
            expect(s.to_s).to include '1, 2, 3'
            expect(s.to_s).to include '4%'
            expect(s.to_s).to include '5%'
            expect(s.to_s).to include '6%'
            expect(s.to_s).to include '7% (8.0K)'
            expect(s.to_s).to include '9% (10.0K)'
            expect(s.to_s).to include '11%'
            expect(s.to_s).to include '12%'
            expect(s.to_s).to include '13%'
          end
          expect(command).to receive(:say).with('Instances total: 1')
          perform
        end

        it 'shows the instance vitals with unavailable ephemeral and persistent disks' do
          new_vm_state = vm_state
          new_vm_state['vitals']['disk'].delete('ephemeral')
          new_vm_state['vitals']['disk'].delete('persistent')
          allow(director).to receive(:fetch_vm_state).with(deployment) { [new_vm_state] }

          expect(command).to receive(:say) do |s|
            expect(s.to_s).to_not include '12%'
            expect(s.to_s).to_not include '13%'
          end
          expect(command).to receive(:say).with('Instances total: 1')
          perform
        end
      end

      context 'with ps' do
        before { options[:ps] = true }

        it 'shows the details of each instance\'s processes' do
          expect(command).to receive(:say) do |s|
            expect(s.to_s).to include 'Instance'
            expect(s.to_s).to include 'State'
            expect(s.to_s).to include 'Resource Pool'
            expect(s.to_s).to include 'IPs'
            expect(s.to_s).to include 'process-1'
            expect(s.to_s).to include 'process-2'
            expect(s.to_s).to include 'running'
          end
          expect(command).to receive(:say).with('Instances total: 1')
          perform
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
