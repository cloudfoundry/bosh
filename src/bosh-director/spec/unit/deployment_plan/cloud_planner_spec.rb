require 'spec_helper'

module Bosh::Director
  module DeploymentPlan
    describe CloudPlanner do
      subject { described_class.new({
        :networks => {},
        :global_network_resolver => [],
        :disk_types => [],
        :availability_zones_list => [],
        :compilation => {},
        :vm_extensions => vm_extensions,
        :ip_provider_factory => nil,
        :logger => nil,
      }) }

      context '#vm_extension' do
        let(:vm_extensions) do
          [
            VmExtension.new({
              'name' => 'test1',
              'cloud_properties' => {
                'fake-property' => 'fake-value',
              }
            })
          ]
        end

        it 'returns a defined vm_extension' do
          expect(subject.vm_extension('test1').cloud_properties['fake-property']).to eq('fake-value')
        end

        it 'raises for an undefined vm_extension' do
          expect { subject.vm_extension('non-existant') }.to raise_error("The vm_extension 'non-existant' has not been configured in cloud-config.")
        end
      end
    end
  end
end
