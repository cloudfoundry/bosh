require 'spec_helper'

module Bosh::Director
  module DeploymentPlan
    describe Link do
      subject do
        described_class.new(
          deployment_name,
          link_name,
          link_type,
          source_instance_group,
          mapped_properties,
          use_dns_addresses,
          use_short_dns_addresses,
          use_link_dns_names,
        )
      end

      let(:deployment_name) { 'smurf_deployment' }
      let(:link_name) { 'smurf_link' }
      let(:link_type) { 'smurf_type' }
      let(:source_instance_group_name) { 'my_source_instance_group_name' }
      let(:source_instance_group) do
        instance_double(Bosh::Director::DeploymentPlan::InstanceGroup,
                        default_network_name: network_name)
      end
      let(:network_name) { 'smurf_network' }
      let(:use_short_dns_addresses) { false }
      let(:use_dns_addresses) { false }
      let(:use_link_dns_names) { false }
      let(:instance_group_private_network) { instance_double(Bosh::Director::DeploymentPlan::JobNetwork) }
      let(:instance_group_public_network) { instance_double(Bosh::Director::DeploymentPlan::JobNetwork) }
      let(:smurf_link_info) do
        {
          'name' => 'smurf_link',
          'type' => 'whatever',
          'from' => 'ringo',
          'deployment' => 'something',
          'mapped_properties' => {
            'a' => 'b',
          },
        }
      end

      let(:mapped_properties) do
        {
          'a' => 'b',
        }
      end

      let(:needed_instance_plan) { instance_double(Bosh::Director::DeploymentPlan::InstancePlan) }
      let(:needed_instance) { instance_double(Bosh::Director::DeploymentPlan::Instance) }

      before do
        allow(instance_group_private_network).to receive(:name).and_return('private_network_name')
        allow(instance_group_public_network).to receive(:name).and_return(network_name)

        allow(source_instance_group).to receive(:name).and_return(source_instance_group_name)
        allow(source_instance_group).to receive(:networks)
          .and_return([instance_group_private_network, instance_group_public_network])
      end

      context '#spec' do
        context 'when there is an instance plan' do
          before do
            allow(source_instance_group).to receive(:needed_instance_plans).and_return([needed_instance_plan])

            allow(needed_instance_plan).to receive(:instance).and_return(needed_instance)
            expect(needed_instance_plan).to receive(:link_network_addresses)
              .with(subject, true)
              .and_return('network1' => 'my.address', 'network2' => 'my.other.address')
            expect(needed_instance_plan).to receive(:link_network_addresses)
              .with(subject, false)
              .and_return('network1' => '10.0.0.1', 'network2' => '10.0.0.2')

            allow(needed_instance).to receive(:index).and_return(0)
            allow(needed_instance).to receive(:uuid).and_return('instance-uuid')
            allow(needed_instance).to receive(:bootstrap?).and_return(true)
            allow(needed_instance).to receive_message_chain(:availability_zone, :name).and_return('my_az')
            expect(needed_instance_plan).to receive(:link_network_address).with(subject).and_return('my.address')
          end

          it 'returns correct spec structure, with network name' do
            result_spec = subject.spec

            expect(result_spec).to eq(
              'deployment_name' => 'smurf_deployment',
              'domain' => 'bosh',
              'default_network' => 'smurf_network',
              'networks' => %w[private_network_name smurf_network],
              'instance_group' => 'my_source_instance_group_name',
              'properties' => { 'a' => 'b' },
              'use_short_dns_addresses' => false,
              'use_dns_addresses' => false,
              'use_link_dns_names' => false,
              'instances' => [
                {
                  'name' => 'my_source_instance_group_name',
                  'id' => 'instance-uuid',
                  'index' => 0,
                  'bootstrap' => true,
                  'az' => 'my_az',
                  'address' => 'my.address',
                  'addresses' => { 'network1' => '10.0.0.1', 'network2' => '10.0.0.2' },
                  'dns_addresses' => {
                    'network1' => 'my.address',
                    'network2' => 'my.other.address',
                  },
                },
              ],
            )
          end
        end

        context 'when there is no instance plan' do
          before do
            allow(source_instance_group).to receive(:needed_instance_plans).and_return([])
          end

          it 'returns correct spec structure with network name' do
            result_spec = subject.spec

            expect(result_spec).to eq(
              'deployment_name' => 'smurf_deployment',
              'domain' => 'bosh',
              'default_network' => 'smurf_network',
              'networks' => %w[private_network_name smurf_network],
              'instance_group' => 'my_source_instance_group_name',
              'properties' => { 'a' => 'b' },
              'use_short_dns_addresses' => false,
              'use_dns_addresses' => false,
              'use_link_dns_names' => false,
              'instances' => [],
            )
          end
        end

        context 'when needed instance plans are empty' do
          before do
            allow(source_instance_group).to receive(:needed_instance_plans).and_return([])
          end

          context 'when use_short_dns_addresses is' do
            context 'true' do
              let(:use_short_dns_addresses) { true }

              it 'should be stored in the spec' do
                expect(subject.spec['use_short_dns_addresses']).to be_truthy
              end
            end

            context 'false' do
              let(:use_short_dns_addresses) { false }

              it 'should be stored in the spec' do
                expect(subject.spec['use_short_dns_addresses']).to be_falsey
              end
            end
          end

          context 'when use_dns_addresses is' do
            context 'true' do
              let(:use_dns_addresses) { true }

              it 'should be stored in the spec' do
                expect(subject.spec['use_dns_addresses']).to be_truthy
              end
            end

            context 'false' do
              let(:use_dns_addresses) { false }

              it 'should be stored in the spec' do
                expect(subject.spec['use_dns_addresses']).to be_falsey
              end
            end
          end

          context 'when use_link_dns_names is' do
            context 'true' do
              let(:use_link_dns_names) { true }

              it 'should be stored in the spec' do
                expect(subject.spec['use_link_dns_names']).to be_truthy
              end
            end

            context 'false' do
              let(:use_link_dns_names) { false }

              it 'should be stored in the spec' do
                expect(subject.spec['use_link_dns_names']).to be_falsey
              end
            end
          end
        end
      end
    end
  end
end
