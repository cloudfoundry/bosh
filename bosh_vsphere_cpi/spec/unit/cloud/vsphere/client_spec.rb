require 'spec_helper'
require 'fakefs/spec_helpers'
require 'cloud/vsphere/client'

module VSphereCloud
  describe Client do
    include FakeFS::SpecHelpers

    subject(:client) { Client.new('http://www.example.com', options) }

    let(:options) { {} }
    let(:fake_search_index) { double(:search_index) }
    let(:fake_service_content) { double('service content', root_folder: double('fake-root-folder')) }

    let(:logger) { instance_double('Logger') }
    before { class_double('Bosh::Clouds::Config', logger: logger).as_stubbed_const }

    before do
      fake_instance = double('service instance', content: fake_service_content)
      allow(VimSdk::Vim::ServiceInstance).to receive(:new).and_return(fake_instance)
      allow(fake_service_content).to receive(:search_index).and_return(fake_search_index)
    end

    describe '#initialize' do
      let(:ssl_config) { double(:ssl_config, :verify_mode= => nil) }
      let(:http_client) do
        instance_double('HTTPClient',
          :debug_dev= => nil,
          :send_timeout= => nil,
          :receive_timeout= => nil,
          :connect_timeout= => nil,
          :ssl_config => ssl_config,
        )
      end
      before { allow(HTTPClient).to receive(:new).and_return(http_client) }

      let(:options) { { 'soap_log' => soap_log } }

      def self.it_configures_http_client
        it 'configures http client ' do
          expect(http_client).to receive(:send_timeout=).with(14400)
          expect(http_client).to receive(:receive_timeout=).with(14400)
          expect(http_client).to receive(:connect_timeout=).with(30)
          expect(ssl_config).to receive(:verify_mode=).with(OpenSSL::SSL::VERIFY_NONE)

          subject
        end
      end

      context 'when soap log is an IO' do
        let(:soap_log) { IO.new(0) }

        it 'uses given IO for http_client logging' do
          expect(http_client).to receive(:debug_dev=).with(soap_log)
          expect(VimSdk::Soap::StubAdapter).to receive(:new).with('http://www.example.com', 'vim.version.version6', http_client)

          subject
        end

        it_configures_http_client
      end

      context 'when soap log is a StringIO' do
        let(:soap_log) { StringIO.new }

        it 'uses given IO for http_client logging' do
          expect(http_client).to receive(:debug_dev=).with(soap_log)
          expect(VimSdk::Soap::StubAdapter).to receive(:new).with('http://www.example.com', 'vim.version.version6', http_client)

          subject
        end

        it_configures_http_client
      end

      context 'when soap log is a file path' do
        let(:soap_log) { '/fake-log-file' }
        before { FileUtils.touch('/fake-log-file') }

        it 'creates a file IO for http_client logging' do
          expect(http_client).to receive(:debug_dev=) do |log_file|
            expect(log_file).to be_instance_of(File)
            expect(log_file.path).to eq('/fake-log-file')
          end

          expect(VimSdk::Soap::StubAdapter).to receive(:new).with('http://www.example.com', 'vim.version.version6', http_client)

          subject
        end

        it_configures_http_client
      end
    end

    describe '#has_disk?' do
      let(:virtual_disk_manager) { double(:virtual_disk_manager) }
      let(:datacenter) { double(:datacenter) }
      before do
        allow(fake_service_content).to receive(:virtual_disk_manager).
          and_return(virtual_disk_manager)

        allow(fake_search_index).to receive(:find_by_inventory_path).with('fake-datacenter').
          and_return(datacenter)
      end

      it 'finds vmdk disk' do
        allow(virtual_disk_manager).to receive(:query_virtual_disk_uuid).
          with('fake-path.vmdk', datacenter).
          and_return('fake-uuid')

        expect(client.has_disk?('fake-path', 'fake-datacenter')).to be(true)
      end

      it 'finds -flat.vmdk disk' do
        allow(virtual_disk_manager).to receive(:query_virtual_disk_uuid).
          with('fake-path.vmdk', datacenter).
          and_raise(
            VimSdk::SoapError.new('File was not found', double(:error_object))
          )
        allow(virtual_disk_manager).to receive(:query_virtual_disk_uuid).
          with('fake-path-flat.vmdk', datacenter).
          and_return('fake-uuid')

        expect(client.has_disk?('fake-path', 'fake-datacenter')).to be(true)
      end

      it 'raises DiskNotFound if nor .vmdk nor -flat.vmdk disk exist' do
        allow(virtual_disk_manager).to receive(:query_virtual_disk_uuid).and_raise(
          VimSdk::SoapError.new('File was not found', double(:error_object))
        )

        expect(client.has_disk?('fake-path', 'fake-datacenter')).to be(false)
      end
    end

    describe '#find_by_inventory_path' do
      context 'given a string' do
        it 'passes the path to a SearchIndex object when path contains no slashes' do
          expect(fake_search_index).to receive(:find_by_inventory_path).with('foobar')
          client.find_by_inventory_path("foobar")
        end

        it 'does not escape slashes into %2f' +
           'because we want to allow users to specify nested objects' do
          expect(fake_search_index).to receive(:find_by_inventory_path).with('foo/bar')
          client.find_by_inventory_path("foo/bar")
        end
      end

      context 'given a flat array of strings' do
        it 'joins them with slashes' do
          expect(fake_search_index).to receive(:find_by_inventory_path).with('foo/bar')
          client.find_by_inventory_path(['foo', 'bar'])
        end

        it 'does not escape slashes into %2f' +
           'because we want to allow users to specify nested objects' do
          expect(fake_search_index).to receive(:find_by_inventory_path).with('foo/bar/baz')
          client.find_by_inventory_path(['foo', 'bar/baz'])
        end
      end

      context 'given a nested array of strings' do
        it 'joins them with slashes recursively' do
          expect(fake_search_index).to receive(:find_by_inventory_path).with('foo/bar/baz')
          client.find_by_inventory_path(['foo', ['bar', 'baz']])
        end

        it 'does not escape slashes into %2f' +
           'because we want to allow users to specify nested objects' do
          expect(fake_search_index).to receive(:find_by_inventory_path).with('foo/bar/baz/jaz')
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

    describe '#delete_path' do
      let(:datacenter) { instance_double('VimSdk::Vim::Datacenter') }
      let(:task) { instance_double('VimSdk::Vim::Task') }
      let(:file_manager) { instance_double('VimSdk::Vim::FileManager') }

      before do
        allow(fake_service_content).to receive(:file_manager).and_return(file_manager)
      end

      context 'when the path exits' do
        it 'calls delete_file on file manager' do
          expect(client).to receive(:wait_for_task).with(task)

          expect(file_manager).to receive(:delete_file).
            with('[some-datastore] some/path', datacenter).
            and_return(task)

          client.delete_path(datacenter, '[some-datastore] some/path')
        end
      end

      context 'when file manager raises "File not found" error' do
        it 'does not raise error' do
          expect(client).to receive(:wait_for_task).with(task).
            and_raise(RuntimeError.new('File [some-datastore] some/path was not found'))

          expect(file_manager).to receive(:delete_file).
            with('[some-datastore] some/path', datacenter).
            and_return(task)

          expect {
            client.delete_path(datacenter, '[some-datastore] some/path')
          }.to_not raise_error
        end
      end

      context 'when file manager raises other error' do
        it 'raises that error' do
          error = RuntimeError.new('Invalid datastore path some/path')
          expect(client).to receive(:wait_for_task).with(task).
            and_raise(error)
          expect(file_manager).to receive(:delete_file).
            with('some/path', datacenter).
            and_return(task)

          expect {
            client.delete_path(datacenter, 'some/path')
          }.to raise_error
        end
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

    describe 'get_managed_objects_with_attribute' do
      let(:property_collector) { instance_double('VimSdk::Vmodl::Query::PropertyCollector') }
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
        allow(fake_service_content).to receive(:property_collector).and_return(property_collector)
      end

      it 'returns objects that have the provided custom attribute' do
        expect(property_collector).to receive(:retrieve_properties_ex).
          and_return(double(:result, token: 'fake-token', objects: [object_spec_1, object_spec_2]))
        expect(property_collector).to receive(:continue_retrieve_properties_ex).
          and_return(nil)

        results = client.get_managed_objects_with_attribute(VimSdk::Vim::VirtualMachine, 102)
        expect(results).to eq(
          [
            object_1,
            object_2
          ]
        )
      end
    end
  end
end
