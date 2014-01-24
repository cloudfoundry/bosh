require 'spec_helper'
require 'cloud/vsphere/client'

module VSphereCloud
  describe Client do
    describe '#find_by_inventory_path' do
      subject(:client) { Client.new('http://www.example.com') }

      let(:fake_search_index) { double }
      before do
        fake_service_content = double('service content')
        fake_instance = double('service instance', content: fake_service_content)
        VimSdk::Vim::ServiceInstance.stub(new: fake_instance)
        fake_service_content.stub(search_index: fake_search_index)
      end

      context 'given a string' do
        it 'passes the path to a SearchIndex object when path contains no slashes' do
          fake_search_index.should_receive(:find_by_inventory_path).with('foobar')
          client.find_by_inventory_path("foobar")
        end

        it 'does not escape slashes into %2f' +
           'because we want to allow users to specify nested objects' do
          fake_search_index.should_receive(:find_by_inventory_path).with('foo/bar')
          client.find_by_inventory_path("foo/bar")
        end
      end

      context 'given a flat array of strings' do
        it 'joins them with slashes' do
          fake_search_index.should_receive(:find_by_inventory_path).with('foo/bar')
          client.find_by_inventory_path(['foo', 'bar'])
        end

        it 'does not escape slashes into %2f' +
           'because we want to allow users to specify nested objects' do
          fake_search_index.should_receive(:find_by_inventory_path).with('foo/bar/baz')
          client.find_by_inventory_path(['foo', 'bar/baz'])
        end
      end

      context 'given a nested array of strings' do
        it 'joins them with slashes recursively' do
          fake_search_index.should_receive(:find_by_inventory_path).with('foo/bar/baz')
          client.find_by_inventory_path(['foo', ['bar', 'baz']])
        end

        it 'does not escape slashes into %2f' +
           'because we want to allow users to specify nested objects' do
          fake_search_index.should_receive(:find_by_inventory_path).with('foo/bar/baz/jaz')
          client.find_by_inventory_path(['foo', ['bar', 'baz/jaz']])
        end
      end

      describe '#soap_stub' do
        it 'returns the soap stub adapter' do
          expect(client.soap_stub).to be_a(VimSdk::Soap::StubAdapter)
        end
      end
    end
  end
end
