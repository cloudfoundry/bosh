require 'spec_helper'
# require 'cloud/vsphere/cloud_searcher'

describe VSphereCloud::CloudSearcher do
  subject(:cloud_searcher) { VSphereCloud::CloudSearcher.new(service_content, logger) }

  let(:service_content) { double('service content', root_folder: double('fake-root-folder')) }
  let(:logger) { instance_double('Logger') }

  let(:property_collector) { instance_double('VimSdk::Vmodl::Query::PropertyCollector') }

  describe 'get_managed_objects_with_attribute' do
    let(:object_1) { double(:object) }
    let(:object_2) { double(:object) }
    let(:object_3) { double(:object) }
    let(:object_spec_1) do
      property = double(:prop_set, val: [ double(:val, key: 102) ])
      double(:object_spec, obj: object_1, prop_set: [property])
    end

    let(:object_spec_2) do
      property = double(:prop_set, val: [ double(:val, key: 102) ])
      double(:object_spec, obj: object_2, prop_set: [property])
    end

    let(:object_spec_3) do
      property = double(:prop_set, val: [ double(:val, key: 201) ])
      double(:object_spec, obj: object_3, prop_set: [property])
    end

    before do
      allow(service_content).to receive(:property_collector).and_return(property_collector)
    end

    it 'returns objects that have the provided custom attribute' do
      expect(property_collector).to receive(:retrieve_properties_ex).
        and_return(double(:result, token: 'fake-token', objects: [object_spec_1, object_spec_2]))
      expect(property_collector).to receive(:continue_retrieve_properties_ex).
        and_return(nil)

      results = cloud_searcher.get_managed_objects_with_attribute(VimSdk::Vim::VirtualMachine, 102)
      expect(results).to eq(
        [
          object_1,
          object_2
        ]
      )
    end
  end

  describe 'has_managed_object_with_attribute?' do
    let(:object_1) { double(:object) }
    let(:object_2) { double(:object) }
    let(:object_spec_1) do
      property = double(:prop_set, val: [ double(:val, key: 102) ])
      double(:object_spec, obj: object_1, prop_set: [property])
    end

    let(:object_spec_2) do
      property = double(:prop_set, val: [ double(:val, key: 42) ])
      double(:object_spec, obj: object_2, prop_set: [property])
    end

    before do
      allow(service_content).to receive(:property_collector).and_return(property_collector)
      expect(property_collector).to receive(:retrieve_properties_ex).
        and_return(double(:result, token: 'fake-token', objects: [object_spec_1, object_spec_2]))
      expect(property_collector).to receive(:continue_retrieve_properties_ex).
        and_return(nil)
    end

    context 'when managed object with attribute exists' do
      it 'returns true' do
        expect(cloud_searcher.has_managed_object_with_attribute?(VimSdk::Vim::VirtualMachine, 42)).to be_truthy
      end
    end

    context 'when managed object with attribute does not exist' do
      it 'returns false' do
        expect(cloud_searcher.has_managed_object_with_attribute?(VimSdk::Vim::VirtualMachine, 999)).to be_falsy
      end
    end

  end
end
