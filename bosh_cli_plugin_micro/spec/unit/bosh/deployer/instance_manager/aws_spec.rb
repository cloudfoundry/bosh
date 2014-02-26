require 'spec_helper'
require 'fakefs/spec_helpers'

require 'aws-sdk'
require 'bosh/deployer/instance_manager/aws'
require 'logger'

module Bosh::Deployer
  describe InstanceManager::Aws do
    include FakeFS::SpecHelpers
    subject(:aws) { described_class.new(instance_manager, config, logger) }

    let(:instance_manager) { instance_double('Bosh::Deployer::InstanceManager') }
    let(:config) do
      instance_double(
        'Bosh::Deployer::Configuration',
        cloud_options: {
          'properties' => {
            'registry' => {
              'endpoint' => 'fake-registry-endpoint',
            },
            'aws' => {
              'ssh_user' => 'fake-ssh-user',
              'ec2_private_key' => 'fake-private-key',
            },
          },
        },
      )
    end
    let(:logger) { instance_double('Logger') }
    let(:registry) { instance_double('Bosh::Deployer::Registry') }
    let(:remote_tunnel) { instance_double('Bosh::Deployer::RemoteTunnel') }

    before do
      allow(Registry).to receive(:new).and_return(registry)
      allow(RemoteTunnel).to receive(:new).and_return(remote_tunnel)
      File.open('fake-private-key', 'w') { |f| f.write('') }
      allow(logger).to receive(:info)
    end

    its(:disk_model) { should be_nil }
    it { should respond_to(:check_dependencies) }

    describe '#remote_tunnel' do
      it 'creates a new ssh tunnel to bosh vm and forwards bosh registry port' do
        allow(instance_manager).to receive(:bosh_ip).and_return('fake-client-ip')
        allow(registry).to receive(:port).and_return('fake-registry-port')
        allow(remote_tunnel).to receive(:create)

        aws.remote_tunnel

        expect(remote_tunnel).to have_received(:create).with('fake-client-ip', 'fake-registry-port')
      end
    end

    describe '#start' do
      it 'starts the registry' do
        allow(registry).to receive(:start)
        aws.start
        expect(registry).to have_received(:start)
      end
    end

    describe '#stop' do
      before do
        allow(registry).to receive(:stop)
        allow(instance_manager).to receive(:save_state)
      end

      it 'stops the registry' do
        aws.stop
        expect(registry).to have_received(:stop)
      end

      it 'saves settings records from the registry database to bosh-deployments' do
        aws.stop
        expect(instance_manager).to have_received(:save_state)
      end
    end

    ip_address_methods = %w(internal_services_ip agent_services_ip client_services_ip)
    ip_address_methods.each do |method|
      describe "##{method}" do
        before do
          allow(instance_manager).to receive(:bosh_ip).and_return('fake-bosh-ip')
        end

        context 'when there is a bosh VM' do
          let(:instance) { instance_double('AWS::EC2::Instance') }

          before do
            instance_manager.stub_chain(:state, :vm_cid).and_return('fake-vm-cid')
            instance_manager.stub_chain(:cloud, :ec2, :instances, :[]).and_return(instance)
          end

          context 'when there is a bosh VM with a public ip' do
            before do
              allow(instance).to receive(:has_elastic_ip?).and_return(false)
              allow(instance).to receive(:public_ip_address).and_return('fake-public-ip')
            end

            it 'returns the public ip' do
              expect(aws.send(method)).to eq('fake-public-ip')
            end
          end

          context 'when there is a bosh VM with an elastic ip' do
            before do
              allow(instance).to receive(:has_elastic_ip?).and_return(true)
              instance.stub_chain(:elastic_ip, :public_ip).and_return('fake-elastic-ip')
            end

            it 'returns the elastic ip' do
              expect(aws.send(method)).to eq('fake-elastic-ip')
            end
          end
        end

        context 'when there is no bosh VM' do
          before do
            instance_manager.stub_chain(:state, :vm_cid).and_return(nil)
          end

          it 'returns instance managers idea of what bosh_ip should be' do
            expect(aws.send(method)).to eq('fake-bosh-ip')
          end
        end
      end
    end
  end
end
