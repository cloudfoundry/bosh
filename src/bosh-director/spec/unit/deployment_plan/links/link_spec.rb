require 'spec_helper'

module Bosh::Director
  module DeploymentPlan
    describe Link do
      let(:deployment_name) {'smurf_deployment'}
      let(:link_name) {'smurf_link'}
      let(:source_instance_group_name) {'my_source_instance_group_name'}
      let(:source_instance_group) {instance_double(Bosh::Director::DeploymentPlan::InstanceGroup)}
      let(:job) {instance_double(Bosh::Director::DeploymentPlan::Job)}
      let(:instance_group_network) {instance_double(Bosh::Director::DeploymentPlan::JobNetwork)}

      let(:smurf_link_info) do
        {
          'name' => 'smurf_link',
          'type' => 'whatever',
          'from' => 'ringo',
          'deployment' => 'something',
          'mapped_properties' => {
            'a' => 'b'
          }
        }
      end

      let(:needed_instance_plan) { instance_double(Bosh::Director::DeploymentPlan::InstancePlan) }
      let(:needed_instance) { instance_double(Bosh::Director::DeploymentPlan::Instance) }

      before do
        allow(instance_group_network).to receive(:name).and_return('instance_group_network_name')

        allow(source_instance_group).to receive(:name).and_return(source_instance_group_name)
        allow(source_instance_group).to receive(:networks).and_return([instance_group_private_network, instance_group_public_network])
        allow(source_instance_group).to receive(:default_network).and_return(default_networks)

        allow(needed_instance_plan).to receive(:instance).and_return(needed_instance)
        expect(needed_instance_plan).to receive(:network_addresses).with(true).and_return({'network1' => 'dns-address-1', 'network2' => 'dns-address-2'})
        expect(needed_instance_plan).to receive(:network_addresses).with(false).and_return({'network1' => '10.0.0.1', 'network2' => '10.0.0.2'})

        allow(needed_instance).to receive(:index).and_return(0)
        allow(needed_instance).to receive(:uuid).and_return('instance-uuid')
        allow(needed_instance).to receive(:bootstrap?).and_return(true)
        allow(needed_instance).to receive(:availability_zone).and_return('totototo')
        allow(needed_instance).to receive_message_chain(:availability_zone, :name).and_return('my_az')
        expect(job).to receive(:provides_link_info).with(source_instance_group_name, link_name).and_return(smurf_link_info)
      end

      context '#spec' do
        context 'when there is an instance plan' do
          before do
            allow(source_instance_group).to receive(:needed_instance_plans).and_return([needed_instance_plan])

            allow(needed_instance_plan).to receive(:instance).and_return(needed_instance)
            expect(needed_instance_plan).to receive(:network_addresses).with(true).and_return({'network1' => 'network-address-1', 'network2' => 'network-address-2'})
            expect(needed_instance_plan).to receive(:network_addresses).with(false).and_return({'network1' => '10.0.0.1', 'network2' => '10.0.0.2'})

            allow(needed_instance).to receive(:index).and_return(0)
            allow(needed_instance).to receive(:uuid).and_return('instance-uuid')
            allow(needed_instance).to receive(:bootstrap?).and_return(true)
            allow(needed_instance).to receive(:availability_zone).and_return('totototo')
            allow(needed_instance).to receive_message_chain(:availability_zone, :name).and_return('my_az')
            expect(needed_instance_plan).to receive(:network_address).and_return('10.0.0.1')
          end

          it 'returns correct spec structure, with network name' do
            allow(needed_instance_plan).to receive(:root_domain).and_return('smurf.tld')
            expect(job).to receive(:provides_link_info).with(source_instance_group_name, link_name).and_return(smurf_link_info)
            expect(source_instance_group).to receive(:default_network_name).and_return('network1')

            result_spec = Link.new(deployment_name, link_name, source_instance_group, job).spec

            expect(result_spec).to eq({
              'deployment_name' => 'smurf_deployment',
              'domain' => 'smurf.tld',
              'default_network' => 'network1',
              'networks' => ['instance_group_network_name'],
              'source_instance_group' => 'my_source_instance_group_name',
              'properties' => { 'a' => 'b' },
              'instances' => [
                {
                  'name'=> 'my_source_instance_group_name',
                  'index' => 0,
                  'bootstrap' => true,
                  'id' => 'instance-uuid',
                  'az' => 'my_az',
                  'address' => '10.0.0.1',
                  'addresses' => {'network1' => 'network-address-1', 'network2' => 'network-address-2'},
                  'ip_addresses' => {'network1' => '10.0.0.1', 'network2' => '10.0.0.2'}
                }
              ]
            })
          end
        end

        context 'when there is no instance plan' do
          before do
            allow(source_instance_group).to receive(:needed_instance_plans).and_return([])
          end

          it 'returns correct spec structure with network name' do
            result_spec = subject.spec

            expect(result_spec).to eq({
              'deployment_name' => 'smurf_deployment',
              'domain' => 'bosh',
              'default_network' => 'network1',
              'networks' => ['private_network_name', 'smurf_network'],
              'source_instance_group' => 'my_source_instance_group_name',
              'properties' => { 'a' => 'b' },
              'instances' => []
            })
          end
        end
      end
    end
  end
end
