# order is important here :(
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

        it 'escapes slashes into %2f' do
          fake_search_index.should_receive(:find_by_inventory_path).with('foo%2fbar')
          client.find_by_inventory_path("foo/bar")
        end
      end

      context 'given a flat array of strings' do
        it 'joins them with slashes' do
          fake_search_index.should_receive(:find_by_inventory_path).with('foo/bar')
          client.find_by_inventory_path(['foo', 'bar'])
        end

        it 'escapes slashes' do
          fake_search_index.should_receive(:find_by_inventory_path).with('foo/bar%2fbaz')
          client.find_by_inventory_path(['foo', 'bar/baz'])
        end
      end

      context 'given a nested array of strings' do
        it 'joins them with slashes recursively' do
          fake_search_index.should_receive(:find_by_inventory_path).with('foo/bar/baz')
          client.find_by_inventory_path(['foo', ['bar', 'baz']])
        end
        it 'escapes slashes' do
          fake_search_index.should_receive(:find_by_inventory_path).with('foo/bar/baz%2fjaz')
          client.find_by_inventory_path(['foo', ['bar', 'baz/jaz']])
        end
      end
    end
  end
end
