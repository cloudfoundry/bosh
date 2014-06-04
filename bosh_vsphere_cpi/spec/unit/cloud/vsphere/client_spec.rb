require 'spec_helper'
require 'fakefs/spec_helpers'
require 'cloud/vsphere/client'

module VSphereCloud
  describe Client do
    include FakeFS::SpecHelpers

    subject(:client) { Client.new('http://www.example.com', options) }

    let(:options) { {} }
    let(:fake_search_index) { double }
    let(:fake_service_content) { double('service content', root_folder: double('fake-root-folder')) }

    let(:logger) { instance_double('Logger') }
    before { class_double('Bosh::Clouds::Config', logger: logger).as_stubbed_const }

    before do
      fake_instance = double('service instance', content: fake_service_content)
      VimSdk::Vim::ServiceInstance.stub(new: fake_instance)
      fake_service_content.stub(search_index: fake_search_index)
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
