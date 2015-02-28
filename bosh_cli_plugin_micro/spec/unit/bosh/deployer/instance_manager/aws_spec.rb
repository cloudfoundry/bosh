require 'spec_helper'
require 'aws-sdk'
require 'logger'
require 'bosh/deployer/instance_manager/aws'

module Bosh::Deployer
  describe InstanceManager::Aws do
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

    let(:logger) { instance_double('Logger', info: nil) }

    before { allow(Registry).to receive(:new).and_return(registry) }
    let(:registry) { instance_double('Bosh::Deployer::Registry') }

    before { allow(File).to receive(:exists?).with(/\/fake-private-key$/).and_return(true) }

    it { should respond_to(:check_dependencies) }

    describe '#remote_tunnel' do
      before { allow(RemoteTunnel).to receive(:new).and_return(remote_tunnel) }
      let(:remote_tunnel) { instance_double('Bosh::Deployer::RemoteTunnel') }

      it 'creates a new ssh tunnel to bosh vm and forwards bosh registry port' do
        allow(instance_manager).to receive(:client_services_ip).
          with(no_args).
          and_return('fake-client-services-ip')

        allow(registry).to receive(:port).and_return('fake-registry-port')

        allow(remote_tunnel).to receive(:create)

        aws.remote_tunnel

        expect(remote_tunnel).to have_received(:create).
          with('fake-client-services-ip', 'fake-registry-port')
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

    %w(client_services_ip agent_services_ip).each do |method|
      describe "##{method}" do
        before do
          allow(config).to receive(:client_services_ip).
            and_return('fake-client-services-ip')
        end

        context 'when there is a bosh VM' do
          let(:instance) { instance_double('AWS::EC2::Instance') }

          before do
            allow(instance_manager).to receive_message_chain(:state, :vm_cid)
                                           .and_return('fake-vm-cid')
            allow(instance_manager).to receive_message_chain(:cloud, :ec2, :instances, :[])
                                           .and_return(instance)
          end

          context 'when there is a bosh VM with a public ip' do
            before { allow(instance).to receive(:has_elastic_ip?).and_return(false) }

            context 'when public ip is set' do
              it 'returns the public ip' do
                allow(instance).to receive(:public_ip_address).and_return('fake-public-ip')
                expect(aws.send(method)).to eq('fake-public-ip')
              end
            end

            context 'when public ip is not set' do
              it 'return client_services_ip' do
                allow(instance).to receive(:public_ip_address).and_return(nil)
                expect(aws.send(method)).to eq('fake-client-services-ip')
              end
            end
          end

          context 'when there is a bosh VM with an elastic ip' do
            before { allow(instance).to receive(:has_elastic_ip?).and_return(true) }

            context 'when elastic public ip is set' do
              it 'returns the elastic public ip' do
                allow(instance).to receive_message_chain(:elastic_ip, :public_ip)
                                       .and_return('fake-elastic-ip')
                expect(aws.send(method)).to eq('fake-elastic-ip')
              end
            end

            context 'when elastic public ip is not set' do
              it 'raises RuntimeError error' do
                allow(instance).to receive_message_chain(:elastic_ip, :public_ip).and_return(nil)
                expect { aws.send(method) }.to raise_error(
                  RuntimeError, /Failed to discover elastic public ip address/)
              end
            end
          end
        end

        context 'when there is no bosh VM' do
          before { allow(instance_manager).to receive_message_chain(:state, :vm_cid)
                                                  .and_return(nil) }

          it 'returns client services ip according to the configuration' do
            expect(aws.send(method)).to eq('fake-client-services-ip')
          end
        end
      end
    end

    describe '#internal_services_ip' do
      before do
        allow(config).to receive(:internal_services_ip).
          and_return('fake-internal-services-ip')
      end

      it 'returns internal services ip according to the configuration' do
        expect(subject.internal_services_ip).to eq('fake-internal-services-ip')
      end
    end
  end
end
