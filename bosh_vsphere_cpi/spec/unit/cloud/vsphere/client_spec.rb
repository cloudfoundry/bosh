require 'spec_helper'
require 'cloud/vsphere/client'

module VSphereCloud
  describe Client do
    subject(:client) { Client.new('http://www.example.com') }

    let(:fake_search_index) { double }
    let(:fake_service_content) { double('service content', root_folder: double('fake-root-folder')) }

    before do
      fake_instance = double('service instance', content: fake_service_content)
      VimSdk::Vim::ServiceInstance.stub(new: fake_instance)
      fake_service_content.stub(search_index: fake_search_index)
    end

    describe '#find_by_inventory_path' do
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
    end

    describe '#soap_stub' do
      it 'returns the soap stub adapter' do
        expect(client.soap_stub).to be_a(VimSdk::Soap::StubAdapter)
      end
    end

    describe '#create_folder' do
      it 'calls create folder on service content root folder' do
        expect(fake_service_content.root_folder).to receive(:create_folder).with('fake-folder-name')
        client.create_folder('fake-folder-name')
      end
    end

    describe '#move_into_folder' do
      let(:folder) { instance_double('VimSdk::Vim::Folder') }

      it 'calls move_into on folder and waits for task' do
        things_to_move = double('fake-things-to-move')
        task = double('fake-task')

        expect(folder).to receive(:move_into).with(things_to_move).and_return(task)
        expect(client).to receive(:wait_for_task).with(task)
        client.move_into_folder(folder, things_to_move)
      end
    end

    describe '#move_into_root_folder' do
      it 'moves into root folder and waits for task' do
        things_to_move = double('fake-things-to-move')
        task = double('fake-task')

        expect(fake_service_content.root_folder).to receive(:move_into).with(things_to_move).and_return(task)
        expect(client).to receive(:wait_for_task).with(task)
        client.move_into_root_folder(things_to_move)
      end
    end

    describe '#delete_folder' do
      let(:folder) { instance_double('VimSdk::Vim::Folder') }

      it 'calls destroy on folder and waits for task' do
        task = double('fake-task')

        expect(folder).to receive(:destroy).and_return(task)
        expect(client).to receive(:wait_for_task).with(task)
        client.delete_folder(folder)
      end
    end
  end
end
